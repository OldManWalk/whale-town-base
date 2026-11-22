extends Node2D

enum Phase { SURVEY, PREPARATION, FOUNDATION, FRAME, FINISHING, COMPLETE }
const FOOT := Vector2(37,60)
const SIZE := Vector2(74,68)
const SHADE := Color("#715845")
const TIMBER := Color("#a67d55")
const EDGE := Color("#d2ae78")
const STONE := Color("#a19a85")

var elapsed := 0.0
var look := {}
var fact: Dictionary
var environment: Dictionary
var pack: Dictionary
var textures := {}
var lamps := {}
var placements: Dictionary
var build_order := []
var tint := Color.WHITE

func setup(content: Dictionary, layout: Dictionary, assets: Dictionary) -> void:
	pack = content
	placements = layout.buildings
	build_order.clear()
	for status in ["building","planned"]:
		for building in pack.buildings:
			if building.initialState==status:
				build_order.append(building.id)
	for building in pack.buildings:
		var texture: Texture2D = assets[building.assetId]
		textures[building.id] = texture
		lamps[building.id] = window_lights(texture)

func anchor(id: String) -> Vector2:
	var box: Array = placements[id]
	return Vector2(183+(box[0]+box[2]*0.5)*7.0,141+(box[1]+box[3]*0.5)*2.15).round()

func phase_of(building: Dictionary, project: Variant, progress: Dictionary) -> int:
	var percent: float = progress.get(building.id,100.0 if building.initialState=="built" else 0.0)
	var state: String = building.initialState
	if project is Dictionary:
		var id: String = project.get("id","")
		var current: bool = id==str(building.id) or project.get("kind")==str(building.id).trim_suffix("_plan")
		if current:
			percent = project.get("total_percent",percent)
			state = project.get("status",state)
		elif build_order.has(building.id) and build_order.find(building.id)<build_order.find(id):
			return Phase.COMPLETE
	if state in ["built","completed"] or percent>=100.0:
		return Phase.COMPLETE
	if state=="planned" and percent<=0.0:
		return Phase.SURVEY
	return Phase.PREPARATION+clampi(floori(percent/25.0),0,3)

func _draw() -> void:
	if look.is_empty():
		return
	var solar: Dictionary = environment.solar
	var night: bool = solar.phase=="night"
	tint = (Color("#a4a6ae") if night else Color.WHITE)*preload("res://environment/WeatherAppearance.gd").daylight(look)
	for building in pack.get("buildings",[]):
		var phase := phase_of(building,fact.get("active_project"),fact.get("building_progress",{}))
		var texture: Texture2D = textures[building.id]
		draw_set_transform(anchor(building.id)-FOOT)
		if phase==Phase.SURVEY:
			var box: Array = placements[building.id]
			survey(clampf(box[2]*3.3,14,27),clampf(box[3]*0.9,3,6))
		elif phase==Phase.COMPLETE:
			draw_texture_rect(texture,Rect2(Vector2.ZERO,SIZE),false,tint)
			var mask: Texture2D = lamps[building.id]
			var daylight := float(solar.get("daylight",0.0 if night else 1.0))
			var glow := clampf((0.42-daylight)*2.4+float(look.lampHalo)*0.33,0,1)
			if mask and glow>0:
				draw_texture(mask,Vector2.ZERO,Color(1,1,1,glow))
		else:
			worksite(phase,texture)
		if phase>=Phase.FINISHING:
			roof_weather()

func board(x: float, y: float, width: float, height: float, pigment: Color) -> void:
	draw_rect(Rect2(x,y,width,height),pigment*tint)

func survey(half_width: float, depth: float) -> void:
	var back_left := FOOT+Vector2(-half_width+4,-depth)
	var back_right := FOOT+Vector2(half_width,-depth)
	var front_left := FOOT+Vector2(-half_width,depth)
	var front_right := FOOT+Vector2(half_width-3,depth)
	for side in [[back_left,back_right],[back_left,front_left],[back_right,front_right],[front_left,front_right]]:
		var a: Vector2 = side[0]-Vector2(0,4)
		var b: Vector2 = side[1]-Vector2(0,4)
		var sag := ((a+b)/2+Vector2(0,1)).round()
		draw_line(a+Vector2.DOWN,sag+Vector2.DOWN,Color("#8f795c")*tint)
		draw_line(sag+Vector2.DOWN,b+Vector2.DOWN,Color("#8f795c")*tint)
		draw_line(a,sag,Color("#ddd1a1")*tint)
		draw_line(sag,b,Color("#ddd1a1")*tint)
	for peg in [back_left,back_right,front_left,front_right]:
		board(peg.x-1,peg.y-6,3,7,SHADE)
		board(peg.x-1,peg.y-6,2,2,EDGE)
		board(peg.x-1,peg.y-3,3,1,Color("#eeddb3"))
	board(back_right.x+1,back_right.y-5,4,2,Color("#cb8a6b"))
	board(back_right.x+4,back_right.y-4,2,1,Color("#ae7758"))

func sawhorse(x: int, y: int) -> void:
	for foot in [x+2,x+13]:
		draw_line(Vector2(foot,y-5),Vector2(foot-3,y+1),SHADE*tint,2)
		draw_line(Vector2(foot,y-5),Vector2(foot+3,y+1),TIMBER*tint,2)
	board(x,y-7,16,3,SHADE)
	board(x,y-7,16,1,EDGE)

func stacked_boards(x: int, y: int) -> void:
	board(x+2,y,14,2,SHADE)
	board(x,y-2,19,2,TIMBER)
	board(x+2,y-4,17,2,EDGE)
	board(x+14,y-4,1,4,Color("#736a52"))

func scaffolding(top: int) -> void:
	const BASE := 60
	for x in [8,24]:
		board(x,top,2,BASE-top,SHADE)
		board(x,top,1,BASE-top,EDGE)
	draw_line(Vector2(9,BASE-2),Vector2(24,top+5),TIMBER*tint,2)
	board(5,top+4,24,3,TIMBER)
	board(5,top+4,24,1,EDGE)
	for y in range(top+9,BASE-1,5):
		board(19,y,7,1,EDGE)
	board(19,top+7,1,BASE-top-7,SHADE)
	board(25,top+7,1,BASE-top-7,SHADE)

func worksite(phase: int, texture: Texture2D) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(6,60),Vector2(13,54),Vector2(60,53),Vector2(69,59),Vector2(62,64),Vector2(12,65)]),Color("#aa9276")*tint)
	if phase==Phase.PREPARATION:
		sawhorse(15,59)
		stacked_boards(42,61)
		return
	var top_y := 55 if phase==Phase.FOUNDATION else (35 if phase==Phase.FRAME else 19)
	var dest := Rect2(0,top_y,SIZE.x,SIZE.y-top_y)
	draw_texture_rect_region(texture,dest,Rect2(dest.position*texture.get_size()/SIZE,dest.size*texture.get_size()/SIZE),tint)
	if phase==Phase.FOUNDATION:
		for i in 6:
			board(13+i*8,54-(i%2),7,3,STONE)
		sawhorse(48,64)
	elif phase==Phase.FRAME:
		draw_line(Vector2(16,36),Vector2(34,21),SHADE*tint,2)
		draw_line(Vector2(34,21),Vector2(56,36),EDGE*tint,2)
		draw_line(Vector2(34,22),Vector2(34,36),TIMBER*tint,2)
		scaffolding(31)
	else:
		scaffolding(23)

func window_lights(texture: Texture2D) -> ImageTexture:
	# These two colors mark the original lit glass and stage bulbs in the open
	# sprite palette. Unmarked buildings retain the entrance in their artwork.
	var source := texture.get_image()
	if not source or source.is_empty():
		return null
	if source.get_size()!=Vector2i(SIZE):
		source.resize(int(SIZE.x),int(SIZE.y),Image.INTERPOLATE_NEAREST)
	var mask := Image.create(int(SIZE.x),int(SIZE.y),false,Image.FORMAT_RGBA8)
	var found := false
	for y in range(24,54):
		for x in range(4,70):
			var pixel := source.get_pixel(x,y)
			if pixel.a<0.5 or pixel.to_html(false) not in ["f5d68a","f6d992"]:
				continue
			found = true
			for dy in range(-2,3):
				for dx in range(-2,3):
					var weight := 0.16/(1+dx*dx+dy*dy)
					if dx==0 and dy==0:
						weight = 0.9
					if mask.get_pixel(x+dx,y+dy).a<weight:
						mask.set_pixel(x+dx,y+dy,Color(1,0.82,0.44,weight))
	return ImageTexture.create_from_image(mask) if found else null

func roof_weather() -> void:
	if look.eaveDrip<=0.0 and look.snowCover<=0.0:
		return
	for i in 6:
		var edge := Vector2(12+i*9,31+absi(2-i))
		if look.snowCover>0:
			draw_rect(Rect2(edge,Vector2(2+look.snowCover*5,1+look.snowCover*2)),Color(0.88,0.91,0.91,look.snowCover))
		if look.eaveDrip>0:
			var fall := fposmod(elapsed*(11+look.eaveDrip*14)+i*7,28)
			if fall<17:
				draw_line(edge+Vector2(0,fall),edge+Vector2(0,fall+2),Color(0.72,0.84,0.91,look.eaveDrip*0.75))
