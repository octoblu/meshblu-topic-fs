fuse4js = require 'fuse4js'
fs      = require 'fs'
_       = require 'lodash'

FILE_MODES =
  directory: 0o40777
  file:      0o100666

class FileSystem
  constructor: (meshblu, options={}) ->
    @meshblu     = meshblu
    @debug       = options.debug || false
    @mount_point = options.mount_point
    @delimiter   = options.delimiter ? '\n'
    @input_buffers     = {}
    @output_buffers     = {}
    @subscribe   = _.debounce @subscribe, 5000, true
    @unsubscribe = _.debounce @unsubscribe, 5000
    @handlers =
      getattr:  @getattr
      readdir:  @readdir
      open:     @open
      read:     @read
      write:    @write
      release:  @release
      flush:    => @unimplimented('flush')
      create:   => @unimplimented('create')
      unlink:   => @unimplimented('unlink')
      rename:   => @unimplimented('rename')
      mkdir:    => @unimplimented('mkdir')
      rmdir:    => @unimplimented('rmdir')
      init:     @init
      destroy:  => @unimplimented('destroy')
      setxattr: => @unimplimented('setxattr')
      statfs:   @statfs

  getattr: (path, callback) =>
    console.log 'getattr', path
    if path == '/' || path == '/._.'
      return callback 0, size: 4096, mode: FILE_MODES.directory

    uuid = path.replace '/', ''
    return callback 0, size: 0, mode: FILE_MODES.file if /[g-zA-Z.]+/.test uuid

    callback 0, size: _.size(@input_buffers[uuid]), mode: FILE_MODES.file, mtime: new Date()

  init: (callback=->) =>
    callback()

  open: (path, flags, callback=->) =>
    uuid = path.replace '/', ''
    return callback -2 if /[g-zA-Z.]+/.test uuid

    @input_buffers[uuid] ?= ''
    @subscribe uuid
    callback 0

  read: (path, offset, len, buffer, fh, callback=->) =>
    err  = 0
    uuid = path.replace '/', ''
    device_buffer = @input_buffers[uuid]

    if offset < device_buffer.length
      max_bytes = device_buffer.length - offset
      if len > max_bytes
        len = max_bytes

      data = device_buffer.substring offset, len
      buffer.write data, 0, len, 'ascii'
      err = len

    callback err

  readdir: (path, callback=->) =>
    return callback 0, [] unless @meshblu.ready
    @meshblu.mydevices {}, (response) =>
      devices = _.where response.devices, online: true
      callback 0, _.pluck(devices, 'uuid')

  release: (path, fh, callback=->) =>
    uuid = path.replace '/', ''
    return callback 0 if /[g-zA-Z.]+/.test uuid

    @unsubscribe uuid
    callback 0

  statfs: (callback=->) =>
    callback 0,
      bsize:   1000000
      frsize:  1000000
      blocks:  1000000
      bfree:   1000000
      bavail:  1000000
      files:   1000000
      ffree:   1000000
      favail:  1000000
      fsid:    1000000
      flag:    1000000
      namemax: 1000000

  start: (options={}) =>
    @meshblu.on 'message', (message) =>
      @input_buffers[message.fromUuid] ?= ''
      @input_buffers[message.fromUuid] += "#{JSON.stringify message}\n"

    fuse4js.start @mount_point, @handlers, @debug, []

  write: (path, offset, len, buffer, fh, callback=->) =>
    uuid = path.replace '/', ''
    return callback 0 if /[g-zA-Z.]+/.test uuid

    message_string = buffer.toString()
    @output_buffers[uuid] ?= ''
    @output_buffers[uuid] += message_string

    if _.contains @output_buffers[uuid], @delimiter
      messages = @output_buffers[uuid].split @delimiter

      if _.size messages > 1
        complete_messages = _.initial messages
        @output_buffers[uuid] = _.last messages
      else
        complete_messages = messages
        @output_buffers[uuid] = ''

      _.each complete_messages, (message) =>
        @meshblu.message JSON.parse message

    callback _.size message_string

  unimplimented: (method_name) =>
    console.error "unimplemented: #{method_name}"
    throw new Error(method_name);

  subscribe: (uuid) =>
    # debounced by constructor
    console.error 'subscribe: ', uuid
    @meshblu.subscribe uuid: uuid, ->

  unsubscribe: (uuid) =>
    # debounced by constructor
    console.error 'unsubscribe: ', uuid
    @meshblu.unsubscribe uuid: uuid, =>
      @input_buffers[uuid] = ''

module.exports = FileSystem
