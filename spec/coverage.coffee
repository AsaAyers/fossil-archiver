require('coffee-coverage').register({
    path: 'relative',
    basePath: __dirname+"/../lib",
    initAll: true
})

process.on 'uncaughtException', (err) ->
    console.log('Caught exception: ' + err)
    console.log('stack: ' + err.stack)
