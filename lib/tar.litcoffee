WARNING: 
=========

I am not happy with how this file works. It took much more trial and error than
I like but it is doing what I want now. I also tried to go the BDD route and
write a test for this, but I don't know how to write a test for something this
involved.

Requirements
============

* Don't output until input is consumed.
 * Tar can't start until the complete file list has been generated. As a result
   this class must consume all of the input before generating the first output.
* Don't get too far ahead of post-processing.
 * These files are only one step, they will probably be encrypted and uploaded.


    cp = require 'child_process'
    stream = require 'stream'
    Q = require 'q'
    tmp = require 'tmp'
    fs = require 'fs'

    module.exports = class Tar extends stream.Duplex

        constructor: ->
            super
                objectMode: true

            @files = {}
            @tarQueue = []
            @canPush = false

Once all of the data has been collected, close the file so it can be read by
tar

            @on 'finish', =>
                @fileStream.end =>

                    @writeComplete = true

Here is where the `tar` command is really kicked off. It can start working
before `_read`.

                    @getTmpPath().done (baseName) =>
                        @tarStatus = @genTar(baseName)

It seems like `_read` is always called immediately. I don't know if it's
possible for `_write` to finish before `_read` is called for the first time.

                        if @readWaiting
                            @readWaiting = false
                            @_read()

        _write: (item, encoding, doneCallback) ->

The complete item will be needed later for being passed to the next step in the
chain.

            @files[item.path] = item

I don't know what could fail here, but Q will throw the error if it ever happens

            @getTmpPath().done (@baseName) =>
                @fileStream ?= fs.createWriteStream baseName+".txt"
                @fileStream.write item.path+"\n", ->
                    doneCallback()

            return

        _read: ->

It seems like `_read` is always called immediately. Since it can't run until
`_write` has completed, do nothing for now.

            unless @writeComplete
                @readWaiting = true
                return

`@tarStatus.next` is the real implementation of `_read`.
            
            @tarStatus.next (tarFile) =>
                @push tarFile

Not sure what else to call this, it sort of generate a tar handler. 

        genTar: (baseName) ->
            counter = 0
            tmpDestination = baseName+"-#{counter++}.tar"

            tarStatus =
                done: false
                isPaused: false

I don't want to generate too many files faster than they can be processed. If
you're backing up 500GB and the encryption process (I haven't written yet)
requires copying the files I don't want to generate 500GB of tars, when
encrypting might consume another 500GB. 5 is a guess at a decent number. What
matters here is that backing up a set of files to a remote location shouldn't
require a huge amount of tmp space.

                maxQueueSize: 5
                _queue: []
                _waitingCallbacks: []

                next: (callback) ->

If a file has been processed and is ready, return it now.

                    if @_queue.length > 0
                        callback @_queue.shift()
                        if @isPaused then @_startNextFile()
                    else
                        @_waitingCallbacks.push callback

                _startNextFile: ->
                    return if @done
                    @isPaused = false

When tar is ready for the next archive it waits. a `\n` would reuse the same
filename, but this will specify a new filename for the next archive.

                    tar.stdin.write "n #{tmpDestination}\n"

After a tar file has completed this will push it out to a waiting `_read`
request on onto the queue for the next `_read` request.

                pushTar: (tarFile) ->
                    if @_waitingCallbacks.length > 0
                        cb = @_waitingCallbacks.shift()
                        cb(tarFile)
                        
`pushTar` is ALWAYS called right after tar has been paused.

                        @_startNextFile()
                    else
                        @_queue.push tarFile
                        if @_queue.length <= @maxQueueSize
                            @_startNextFile()

            tar = @runTar(baseName+".txt", tmpDestination)

Collect which files are being included in the archive. the output is when a
file starts.
            tar.stdout.on 'data', (data) ->
                lastFile = data.toString().trim()
                files.push lastFile

            files = []
            tar.on 'close', (code) =>
                tarStatus.done = true

Don't forget the last archive.

                tarStatus.pushTar
                    tar: tmpDestination
                    fileData: (@files[f] for f in files)

            lastFile = undefined

When tar pauses for the next multivolume archive it uses stderr to prompt.

            tar.stderr.on 'data', (data) =>

This is looking for the following prompt: 
`Prepare volume #2 for <filename> and hit return:`

By watching for the filename this should find the correct prompt no matter what
language tar is using.

                match = data.toString().indexOf tmpDestination
                if match > -1
                    tarStatus.isPaused = true

The info needs to be collected first.

                    tarFile =
                        tar: tmpDestination
                        fileData: (@files[f] for f in files)

Then reset the state for the next archive to start.

                    files.length = 0
                    # In experimenting I found that tar shows a filename as
                    # it starts to get written. This assumes the last file
                    # in every volume passes into the next volume.
                    files.push lastFile if lastFile

                    tmpDestination = baseName+"-#{counter++}.tar"

It's important this run after the reset above. `pushTar` might start the
process again and `tmpDestination` and `files` need to be in the correct state.

                    tarStatus.pushTar tarFile

            return tarStatus

This was split into it's own file so it can be mocked in a test. I haven't
figured out how to make that work yet.

        runTar: (fileList, tmpDestination, chunkSize = 100) ->

`tar -cvf /tmp/fossil-xxxxxxx-0.tar -L 100 -T /tmp/fossil-xxxxxxx.txt`

            options = [
                # Create tar
                '-cvf', tmpDestination
                # Chunk it into pices
                '-L', chunkSize
                # Read the temporary file for which files to include
                '-T', fileList
            ]
            cp.spawn 'tar', options,
                cwd: process.cwd()

        getTmpPath: ->
            @_tmpPromise ?= Q.nfcall tmp.tmpName, {prefix: 'fossil-'}
