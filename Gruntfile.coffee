spawn = require('child_process').spawn

module.exports = (grunt) ->

    sourceFiles = [
        '*.coffee'
        'lib/*'
        'spec/*'
    ]
    grunt.initConfig
        watch:
            spawn:
                options:
                    interrupt: true
                files: sourceFiles
                # This will get defined in the repeat task
                # tasks: [ ]

            vows:
                files: sourceFiles
                tasks: [ 'vows' ]
            options:
                atBegin: true

        vows:
            all:
                options:
                    reporter: "spec"
                    coverage: "html"


    grunt.loadNpmTasks 'grunt-contrib-watch'
    grunt.loadNpmTasks 'grunt-vows'


    grunt.registerTask 'spawn', (command, args...) ->
        done = this.async()

        console.log 'spawn', command, args
        child = spawn(command, args)
        child.stdout.pipe(process.stdout)
        child.stderr.pipe(process.stderr)
        child.on 'close', (exitCode) ->
            console.log 'exit code:', exitCode
            done()

        setTimeout (->
            child.kill() unless child.disconnected
        ), 30000

    grunt.registerTask 'repeat', (params...) ->
        watchTask = "spawn:"+params.join(":")
        grunt.config.set('watch.spawn.tasks', [ watchTask ])
        grunt.task.run [ 'watch:spawn' ]

