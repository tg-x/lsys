class InputHandler
  snapshot: null # lsystem params as they were was when joystick activated
  constructor: (@keystate, @joystick) ->
  update: (system) =>
    return if not @joystick.active
    if (@keystate.alt)
      system.params.size.value = Util.round(@snapshot.params.size.value + (@joystick.dy(system.sensitivities.size.value)), 2)
      system.params.size.growth = Util.round(@snapshot.params.size.growth + @joystick.dx(system.sensitivities.size.growth),6)
    else if (@keystate.meta or @keystate.ctrl)
      system.offsets.x = @snapshot.offsets.x + @joystick.dx()
      system.offsets.y = @snapshot.offsets.y + @joystick.dy()
    else
      system.params.angle.value = Util.round(system.params.angle.value + @joystick.dx(system.sensitivities.angle.value), 4)
      system.params.angle.growth = Util.round(system.params.angle.growth + @joystick.dy(system.sensitivities.angle.growth),9)

class AnimationHandler
  snapshot: null # lsystem params as they were was when joystick activated
  constructor: (@animation) ->

  sensitivity: (value) ->
    if (value) then Math.pow(10,value-10) else 1

  update: (system) =>
    return if not @animation.active
    d = @animation.state()
    if (typeof d.angle == 'number' && Number.isFinite d.angle)
      system.params.angle.value = Util.round(system.params.angle.value + d.angle * @sensitivity(system.sensitivities.angle.value), 4)
    if (typeof d.angleG == 'number' && Number.isFinite d.angleG)
      system.params.angle.growth = Util.round(system.params.angle.growth + d.angleG * @sensitivity(system.sensitivities.angle.growth), 9)
    if (typeof d.size == 'number' && Number.isFinite d.size)
      system.params.size.value = Util.round(@snapshot.params.size.value + d.size * @sensitivity(system.sensitivities.size.value), 2)
    if (typeof d.sizeG == 'number' && Number.isFinite d.sizeG)
      system.params.size.growth = Util.round(@snapshot.params.size.growth + d.sizeG * @sensitivity(system.sensitivities.size.growth), 6)
    if (typeof d.offsetX == 'number' && Number.isFinite d.offsetX)
      system.offsets.x = @snapshot.offsets.x + d.offsetX
    if (typeof d.offsetY == 'number' && Number.isFinite d.offsetY)
      system.offsets.y = @snapshot.offsets.y + d.offsetY
    if (typeof d.rotation == 'number' && Number.isFinite d.rotation)
      system.offsets.rot = @snapshot.offsets.rot + d.rotation

class AppManager
  joystick:null
  animation:null
  keystate: null
  inputHandler: null
  renderer:null
  systemManager: null

  constructor: (@container, @controls, @animation) ->
    @joystick = new Joystick(@container)
    @keystate = new KeyState
    @inputHandler = new InputHandler(@keystate, @joystick)
    @animationHandler = new AnimationHandler(@animation)

    @joystick.onRelease = => @syncLocationQuiet()
    @joystick.onActivate = => @inputHandler.snapshot = @systemManager.activeSystem.clone()

    @animation.onRelease = => @syncLocationQuiet()
    @animation.onActivate = => @animationHandler.snapshot = @systemManager.activeSystem.clone()

    @renderer = new Renderer(@container)

    @systemManager = new SystemManager

    @initControls()
    @joystick.disable()

  initControls: ->
    @createBindings()
    @createControls()

  syncLocation: -> location.hash = @systemManager.activeSystem.toUrl()
  syncLocationQuiet: -> location.quietSync = true; @syncLocation()

  beforeRecalculate: ->
  afterRecalculate: ->
  onRecalculateFail: ->
  onRecalculateProgress: ->

  prepareContainer: -> @renderer.prepare(@systemManager.activeSystem)

  isRecalculating: -> not @recalculationPromise or @recalculationPromise?.state() == 'pending'
  recalculate: (system = @lsystemFromControls()) ->
    @beforeRecalculate()
    @recalculationPromise = @systemManager.activate(system).progress(@onRecalculateProgress)
    @recalculationPromise.done( =>
      @joystick.enable()
      @animation.setF(system.animation, @controls.animation)
      @animation.toggle(system.play)
      @renderer.prepare(system)
      @syncAll();
      @draw()
      @afterRecalculate()
    )
    @recalculationPromise.fail(@onRecalculateFail)
    @recalculationPromise

  lsystemFromControls: ->
    play = $(@controls.play).hasClass('play')
    animation = $(@controls.animation).val()
    Defaults.play = play
    Defaults.animation = animation
    return new LSystem(
      @paramControls.toJson(),
      @offsetControls.toJson(),
      @sensitivityControls.toJson(),
      $(@controls.rules).val(),
      parseInt($(@controls.iterations).val()),
      parseFloat($(@controls.lineWidth).val()),
      Util.mapArray(@controls.colors, (el) -> el.value),
      play,
      animation,
      $(@controls.name).val()
    )

  exportToPng: (system = @systemManager.activeSystem) ->
    [x,y] = [(@container.clientWidth / 2) + system.offsets.x, (@container.clientHeight / 2) + system.offsets.y]

    b = @renderer.context.bounding
    frameWidth = b.width()+30
    frameHeight = b.height()+30
    container = $('<div></div>').css({
      "width" : frameWidth,
      "height": frameHeight
    })[0];

    r = new Renderer(container)
    r.prepare(system)

    r.reset = (system) ->
      r.context.reset(system)
      r.context.state.x = (x-b.x1+15)
      r.context.state.y = (y-b.y1+15)

    @draw(r)
    filename = "lsys_"+system.name.replace(/[\ \/]/g,"_")+".png"
    rootCanvas = container.children[0]
    rootContext = rootCanvas.getContext('2d')
    [].slice.call(container.children, 1).forEach( (c) ->
      rootContext.drawImage(c,0,0,frameWidth,frameHeight)
    )
    Util.openDataUrl( rootCanvas.toDataURL("image/png"), filename )

  start: ->
    startingSystem = LSystem.fromUrl() or DefaultSystem
    @recalculate(startingSystem)
      .fail( => @syncAll(startingSystem) )
      .pipe( => @draw())
      .always(@run)

  run: =>
    if @joystick.active and not @renderer.isDrawing
      @joystick.draw()
      @inputHandler.update(@systemManager.activeSystem)
      @syncControls()
      @draw()
    if @animation.active and not @renderer.isDrawing
      @animation.draw()
      @animationHandler.update(@systemManager.activeSystem)
      @syncControls()
      @draw()
    requestAnimationFrame(@run, @container)

  draw: (renderer = @renderer) =>
      elems = @systemManager.getInstructions()
      renderer.render(elems, @systemManager.activeSystem) if elems

  createControls: ->
    @paramControls = new Controls(Defaults.params(), ParamControl)
    @offsetControls = new OffsetControl(Defaults.offsets())
    @sensitivityControls = new Controls(Defaults.sensitivities(), SensitivityControl)

    @paramControls.create(@controls.params)
    @offsetControls.create(@controls.offsets)
    @sensitivityControls.create(@controls.sensitivities)

  syncAll: (system = @systemManager.activeSystem) ->
    $(@controls.name).val(system.name)
    @syncControls(system)
    @syncRulesAndIterations(system)
    @syncLineStyle(system)

  syncRulesAndIterations: (system = @systemManager.activeSystem) ->
    $(@controls.iterations).val(system.iterations)
    $(@controls.rules).val(system.rules)
    $(@controls.animation).val(system.animation)
    if (system.play)
      $(@controls.play).addClass('play')
    else
      $(@controls.play).removeClass('play')

  syncFloat: (input, value) ->
    if (parseFloat(input.val()) != value and not isNaN(parseFloat(value))) then input.val(value)

  syncColor: (input, value) ->
    $(input).val(value)
    input.style.backgroundColor = value

  syncLineStyle: (system = @systemManager.activeSystem) ->
    @syncFloat($(@controls.lineWidth), system.lineWidth)
    @syncColor(@controls.colors[i], col) for col, i in system.colors
    @container.style.backgroundColor = @controls.colors[0].value

  syncControls: (system = @systemManager.activeSystem) ->
    @paramControls.sync(system.params)
    @offsetControls.sync(system.offsets)
    @sensitivityControls.sync(system.sensitivities)

  createBindings: ->
    setClassIf = (onOff, className) =>
      method = if (onOff) then 'add' else 'remove'
      $(@container)["#{method}Class"](className)

    updateCursorType = (ev) =>
      setClassIf(ev.ctrlKey or ev.metaKey, "moving")
      setClassIf(ev.altKey, "resizing")

    document.addEventListener("keydown", (ev) =>
      updateCursorType(ev)
      if ev.keyCode == Key.enter and ev.ctrlKey
        @recalculate()
        @syncLocation()
        return false
      if ev.keyCode == Key.enter and ev.shiftKey
        @exportToPng()
    )

    document.addEventListener("keyup", updateCursorType)
    document.addEventListener("mousedown", updateCursorType)

    window.onhashchange = =>
      quiet = location.quietSync
      location.quietSync = false
      if location.hash != "" && !quiet
        @recalculate(LSystem.fromUrl())


#===========================================
