class Util
  @log:(x) -> console.log(x)
  @control:(name) -> document.getElementById(name)
  @value: (name) => parseFloat(Util.stringvalue(name))
  @stringvalue: (name) -> Util.control(name).value
  @clone:(x) -> JSON.parse(JSON.stringify(x))
  @toObj:(kvPairs) ->
    obj = {}
    obj[k] = v for [k,v] in kvPairs
    return obj
  @map: (obj, fn) ->
    result = {}
    for key of obj then do ->
      result[key] = fn(obj[key], key)
    return result
  @merge: (a,b,c) -> $.extend(true, a,b,c)
  @round: (n,d) ->
    pow = Math.pow(10,d)
    Math.round(n*pow) / pow
  @time: (n,f) ->
    f = n if n instanceof Function
    s = new Date; f(); (new Date - s)
  @openDataUrl: (data, filename) ->
    a = document.createElement("a")
    a.href = data
    a.download=filename
    evt = document.createEvent("MouseEvents")
    evt.initMouseEvent("click", true, true,window,0,0,0,0,0,true,false,false,false,0,null)
    a.dispatchEvent(evt)

  # thanks Brian Nickel http://stackoverflow.com/questions/11163344/update-non-retina-canvas-app-to-retina-display
  @enhanceCanvas = (canvas, container) ->
    context = canvas.getContext('2d')
    ratio = window.devicePixelRatio || 1
    width = canvas.width = container.clientWidth
    height = canvas.height = container.clientHeight

    if (ratio > 1)
      canvas.width = width * ratio
      canvas.height = height * ratio
      canvas.style.width = width + "px"
      canvas.style.height = height + "px"
      context.scale(ratio,ratio)
