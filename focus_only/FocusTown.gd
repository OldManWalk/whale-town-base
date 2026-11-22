extends Control

const Focus = preload("res://adapters/StandaloneEngineBridge.gd")
const Appearance = preload("res://environment/WeatherAppearance.gd")
const Content = preload("res://adapters/ContentPack.gd")
const Villagers = preload("res://focus_only/VirtualTownsfolk.gd")

var clock = Focus.new("user://focus-town.json")
var board := Node2D.new()
var map = preload("res://world/WorldMapLayer.gd").new()
var coast = preload("res://environment/CoastAtmosphere.gd").new()
var buildings = preload("res://world/BuildingStageLayer.gd").new()
var rain = preload("res://environment/WeatherLayer.gd").new()
var audio = preload("res://environment/WeatherAudioDirector.gd").new()
var rainbow = preload("res://environment/AfterRainArc.gd").new()
var villagers := Villagers.new()
var hud = preload("res://ui/FocusHud.gd").new()
var elapsed := 0.0
var last_second := -1
var previous_minutes := 0
var message := ""
var view_center := Vector2(240,156)
var dragging_mouse := false
var dragging_touch := -1

func _ready() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var town := Content.read_data("res://focus_only/town.json")
    var manifest := Content.read_data("res://art/asset-license.json")
    var art := {}
    for item in manifest.assets:
        var tile := Content.artwork("res://art",item)
        if tile:
            art[item.assetId] = tile
    clock.configure_buildings(town.buildings)
    previous_minutes = int(clock.state.built_minutes)
    buildings.setup(town,{"buildings":town.footprints},art)
    villagers.setup(town.commons,town.workRoutes)
    map.rainbow = rainbow
    map.seasonal_palette = true
    coast.rainbow = rainbow
    add_child(board)
    for layer in [map,coast,buildings,villagers,rain]:
        board.add_child(layer)
    add_child(audio)
    add_child(hud)
    hud.focus_pressed.connect(change_focus)
    hud.cancel_pressed.connect(func():
        if clock.cancel(current_time()):
            message = "已结束本轮"
        refresh())
    hud.duration_pressed.connect(func():
        var slot := Focus.DURATIONS.find(clock.state.target_minutes)
        clock.select_duration(Focus.DURATIONS[(slot+1)%Focus.DURATIONS.size()])
        refresh())
    resized.connect(layout_board)
    layout_board()
    refresh()

func current_time() -> int:
    return int(Time.get_unix_time_from_system())

func layout_board() -> void:
    var factor := maxf(size.x/480.0,size.y/270.0)*1.20
    if factor<=0.0:
        return
    board.scale = Vector2.ONE*factor
    var half_view := size/(2.0*factor)
    view_center = view_center.clamp(half_view,Vector2(480,270)-half_view)
    board.position = size*0.5-view_center*factor

func pan_by(relative: Vector2) -> void:
    view_center -= relative/board.scale.x
    layout_board()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and dragging_touch<0:
            dragging_touch = event.index
        elif not event.pressed and event.index==dragging_touch:
            dragging_touch = -1
    elif event is InputEventScreenDrag and event.index==dragging_touch:
        pan_by(event.relative)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.device!=InputEvent.DEVICE_ID_EMULATION:
        dragging_mouse = event.pressed
    elif event is InputEventMouseMotion and dragging_mouse and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
        pan_by(event.relative)
        get_viewport().set_input_as_handled()

func change_focus() -> void:
    var now := current_time()
    match clock.status():
        "idle":
            if clock.start(now,int(clock.state.target_minutes)):
                message = ""
        "running":
            clock.pause(now)
        "paused":
            clock.resume(now)
    refresh()

func refresh() -> void:
    var now := current_time()
    last_second = now
    var frame: Dictionary = clock.frame(now)
    var env: Dictionary = frame.environment
    var fact: Dictionary = frame.fact
    var look := Appearance.project(env)
    map.environment = env
    map.look = look
    buildings.fact = fact
    buildings.environment = env
    buildings.look = look
    coast.environment = env
    coast.look = look
    rain.look = look
    rainbow.project(env)
    audio.apply(env.weather,false,look)
    var current: Variant = fact.get("active_project")
    var site := ""
    # After the last build, the crew continues upkeep at the stage.
    if current is Dictionary and clock.status()=="running":
        site = str(current.id)
    villagers.aim_for(site,clock.status()=="running")
    villagers.modulate = Color("#b0b5ce") if env.solar.phase=="night" else Appearance.daylight(look)
    var minutes := int(clock.state.built_minutes)
    if minutes > previous_minutes:
        message = "本轮完成 · 专注了 %d 分钟" % (minutes-previous_minutes)
    previous_minutes = minutes
    var status_text: String = clock.error if not clock.error.is_empty() else message
    hud.update_home(frame, clock.remaining(now), clock.status(), int(clock.state.target_minutes), status_text)

func _process(delta: float) -> void:
    if current_time() != last_second:
        refresh()
    elapsed += delta
    villagers.advance(delta)
    for layer in [map,buildings,rain]:
        layer.elapsed = elapsed
        layer.queue_redraw()
