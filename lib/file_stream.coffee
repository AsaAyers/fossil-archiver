stream = require 'stream'
path = require 'path'
fs = require 'fs'
Q = require 'q'

module.exports = class FileStream extends stream.Readable
    constructor: (@rootPath) ->
        super
            objectMode: true
        @_buffer = []
        @_waiting = 0

    fetchData: ->
        @readDirectory(@rootPath)

    # Allow some filter function to abort walking any further down a directory.
    filter: (results) ->
        return true

    readDir: Q.nbind(fs.readdir, fs)

    statSync: fs.statSync

    readDirectory: (dir) ->
        @readDir(dir).then (results) =>
            return unless @filter(results)
            promises = []
            for r in results
                currentPath = path.join dir, r
                stat = @statSync currentPath
                if stat.isFile()
                    @_buffer.push
                        path: currentPath
                        stat: stat
                    @fulfill()
                if stat.isDirectory()
                    promises.push @readDirectory(currentPath)
            Q.all(promises)

    _read: ->
        @_waiting++
        unless @_started
            @_started = true
            @fetchData().done =>
                @_done = true
                @fulfill()
        @fulfill()

    fulfill: ->
        while @_waiting > 0 and @_buffer.length > 0
            @_waiting--
            entry = @_buffer.shift()
            @push entry
        if @_done
            @push()

