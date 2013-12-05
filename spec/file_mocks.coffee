Q = require 'q'

module.exports = class FileMocks
    constructor: (@fakeFilesystem) ->

    statSync: (path) =>
        current = @fakeFilesystem
        current = current[d] for d in path.split('/')
        return {
            _self: -> current
            isFile: ->
                typeof current is 'string'
            isDirectory: ->
                not @isFile()
        }

    readDir: (path) =>
        current = @statSync(path)
        return Q(key for key of current._self())
