stream = require 'stream'
vows = require 'vows'
assert = require 'assert'

FileStream = require '../lib/file_stream.coffee'
FileMocks = require './file_mocks.coffee'

fakeFilesystem =
    root:
        fileA: "file"
        dirB:
            fileC: "file"
        a:
            b:
                c:
                    d: "file"

contains = (expected) ->
    context =
        topic: (filesystem) ->
            mock = new FileMocks(filesystem)
            mock.readDir(this.context.name)
                .fail((reason) => this.callback(reason))
                .done((result) => this.callback(null, result))
            undefined

    context["contains: #{expected.join(', ')}"] = (actual) ->
        assert.lengthOf actual, expected.length
        for e in expected
            assert.isTrue e in actual

    return context

checkStat = (method) ->
    context =
        topic: (filesystem) ->
            mock = new FileMocks(filesystem)
            mock.statSync(this.context.name)
    context[method] = (stat) ->
        assert.isTrue stat[method]()

    return context

isDirectory = checkStat.bind(null, 'isDirectory')
isFile = checkStat.bind(null, 'isFile')

# Eventually I'll need a way to filter out specific paths. Tht will be passed
# into options.
streamFiles = (path, options = {}) ->
    return ->
        fStream = new FileStream path
        mock = new FileMocks(fakeFilesystem)
        fStream.readDir = mock.readDir
        fStream.statSync = mock.statSync

        topic = []
        fStream.on 'data', (item) ->
            topic.push item.path
            fStream.read()

        fStream.on 'end', @callback.bind(null, null, topic)
        fStream.read()
        return undefined


vows.describe('FileStream').addBatch({
    'mock:':
        topic:
            home:
                asa:
                    '.vimrc': 'file'
                    '.vim':
                        bundle: {}

        'mockReadDir':
            "home/asa": contains [ '.vimrc', '.vim' ]
            'home/asa/.vim': contains [ 'bundle' ]

        'statSync':
            'home': isDirectory()
            'home/asa': isDirectory()
            'home/asa/.vimrc': isFile()

    'Walks a directory recursively':
        topic: streamFiles 'root'
        'contains all files by default': (topic) ->
            expected = [ 'root/fileA', 'root/dirB/fileC', 'root/a/b/c/d' ]
            assert.deepEqual topic, expected

}).export(module)
