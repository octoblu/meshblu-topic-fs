program    = require 'commander'
Meshblu    = require 'skynet'
url        = require 'url'
FileSystem = require './file_system'
pjson      = require '../package.json'

class Command
  constructor: ->
    program
      .version pjson.version
      .option '-d, --debug',              'Enable Debug'
      .option '--delimiter',              'Input message delimiter, defaults to \\n'
      .option '--meshblu-uri [uri]',      'URI for meshblu, defaults to ws://meshblu.octoblu.com'
      .option '-m, --mount-point [path]', 'Where to mount meshblu-topic-fs'
      .option '-u, --uuid [uuid]',        'User UUID'
      .option '-t, --token [token]',      'User Token'
      .parse(process.argv);

    {debug, meshbluUri, mountPoint, uuid, token, delimiter} = program
    meshbluUri = meshbluUri ? 'ws://meshblu.octoblu.com'

    program.help() unless mountPoint && uuid && token

    @options =
      debug:       debug
      delimiter:   delimiter
      meshblu_uri: meshbluUri
      mount_point: mountPoint
      token:       token
      uuid:        uuid

  run: =>
    {protocol, hostname, port} = url.parse @options.meshblu_uri
    meshblu = Meshblu.createConnection
      protocol: protocol
      server: hostname
      port: port ? 80
      uuid: @options.uuid
      token: @options.token

    meshblu.on 'notReady', (error) =>
      console.error 'not ready', error

    meshblu.on 'ready', =>
      meshblu.ready = true
      console.error 'ready'

    file_system = new FileSystem meshblu, @options
    file_system.start()

command = new Command
command.run()
