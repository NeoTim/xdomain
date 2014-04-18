
slaves = null
addSlaves = (s) ->
  if slaves is null
    slaves = {}
    initMaster()
  for origin, path of s
    log "adding slave: #{origin}"
    slaves[origin] = path
  return

frames = {}
getFrame = (origin, proxyPath) ->
  #cache origin
  if frames[origin]
    return frames[origin]
  frame = document.createElement "iframe"
  frame.id = frame.name = guid()
  log "creating iframe #{frame.id}"
  frame.src = "#{origin}#{proxyPath}"
  frame.setAttribute 'style', 'display:none;'
  document.body.appendChild frame
  return frames[origin] = frame.contentWindow

initMaster = ->

  #hook XHR  calls
  xhook.before (request, callback) ->
    
    #allow unless we have a slave domain
    p = parseUrl request.url

    if not p or p.origin is currentOrigin
      return callback()

    unless slaves[p.origin]
      log "no slave matching: '#{p.origin}'" if p
      return callback()
    
    log "proxying request to slave: '#{p.origin}'"

    if request.async is false
      warn "sync not supported"
      return callback()

    #get or insert frame
    frame = getFrame p.origin, slaves[p.origin]

    socket = connect frame

    socket.on "response", (resp) ->
      callback resp
      socket.close()

    #user wants to abort
    request.xhr.addEventListener 'abort', ->
      socket.emit "abort"

    socket.on "xhr-event", ->
      request.xhr.dispatchEvent.apply null, arguments
    socket.on "xhr-upload-event", ->
      request.xhr.upload.dispatchEvent.apply null, arguments

    obj = strip request
    obj.headers = request.headers

    ready = ->
      socket.emit "request", obj


    if request.withCredentials
      obj.credentials = document.cookie

    #prepare the xhr body for postMessaging
    if instOf(request.body, 'Uint8Array')
      obj.body = request.body
    else if instOf(request.body, 'FormData')
      #this FormData is actually XHooks custom FormData,
      #which exposes all entries added, where each entry
      #is the arguments object

      entries = request.body.entries
      obj.body = ["XD_FD", entries]

      # convert = (args, i) ->

      # for args, i in entries
      #   if instOf(args, 'File')



      # if POSTMESSAGE_FILE
      #   ready()
      #   return

    ready()
    
    return


