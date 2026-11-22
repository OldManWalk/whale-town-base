extends Sprite2D

const SHORE := preload("res://art/world/shore.png")
const MistWater := preload("res://environment/CoastAtmosphere.gdshader")
var rainbow: RefCounted
var elapsed := 0.0
var environment := {}
var quality := "Standard"
var look := {}
var fog := -1.0
var palette_key := ""

func _ready() -> void:
	centered = false
	texture = SHORE
	material = ShaderMaterial.new()
	material.shader = MistWater
	material.set_shader_parameter("coast_mask",ImageTexture.create_from_image(shore_mask(SHORE.get_image())))

# Red is exposed water, green is connected sandy path, blue is grass for snow.
# Road samples on either side of hedges allow the path to pass behind the foliage.
static func shore_mask(source: Image) -> Image:
	var size := source.get_size()
	var bounds := Rect2i(Vector2i.ZERO,size)
	var mask := Image.create_empty(size.x,size.y,false,Image.FORMAT_RGB8)
	var sand := BitMap.new()
	sand.create(size)
	for y in size.y:
		for x in size.x:
			var pixel := source.get_pixel(x,y)
			var water := pixel.a<0.5 and y>=size.y/2
			var grass := pixel.a>0.5 and pixel.g>pixel.r and pixel.r>pixel.b
			mask.set_pixel(x,y,Color(float(water),0,float(grass)))
			if pixel.a>0.5 and pixel.r8>=217 and pixel.r8<=235 and pixel.g8>=178 and pixel.g8<=204 and pixel.b8>=118 and pixel.b8<=151:
				sand.set_bit(x,y,true)
	var frontier: Array[Vector2i] = [Vector2i(178,168),Vector2i(75,177),Vector2i(460,153)]
	while not frontier.is_empty():
		var point: Vector2i = frontier.pop_back()
		if not bounds.has_point(point) or not sand.get_bitv(point):
			continue
		sand.set_bitv(point,false)
		mask.set_pixelv(point,Color.GREEN)
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			frontier.append(point+offset)
	return mask

func _process(delta: float) -> void:
	if environment.is_empty() or look.is_empty():
		return
	var weather: Dictionary = environment.weather
	var solar: Dictionary = environment.solar
	var surface: Dictionary = environment.get("surface",{})
	var key := str(solar.phase)+"/"+str(weather.kind)
	if rainbow:
		key += str(rainbow.reflection_key())
	if key != palette_key:
		palette_key = key
		cache_sky(solar.phase,weather.kind)
	var target := clampf(float(weather.get("mist",0)),0,1)
	fog = target if fog<0.0 else lerpf(fog,target,1-exp(-delta/5.0))
	material.set_shader_parameter("elapsed",elapsed)
	material.set_shader_parameter("mist",fog)
	material.set_shader_parameter("rain",weather.get("rain",0.0))
	material.set_shader_parameter("tide",surface.get("waterLevel",0.35))
	material.set_shader_parameter("wetness",surface.get("wetness",weather.get("rain",0.0)))
	material.set_shader_parameter("snow_cover",surface.get("snowCover",0.0))
	material.set_shader_parameter("night",float(solar.phase=="night"))
	material.set_shader_parameter("drift",float(weather.get("windDirection",[1,0])[0]))
	material.set_shader_parameter("gust",look.gust)
	for field in ["puddles","reflection","waveEnergy","lampHalo","cloudShadow","shadowContrast","saturation","coolTint"]:
		material.set_shader_parameter("wx_"+field,look[field])
	material.set_shader_parameter("budget",{"Full":1.0,"Standard":0.7,"Low":0.25,"ToyWindow":0.0}[quality])

func cache_sky(phase: String, kind: String) -> void:
	var colors := sky_colors(phase,kind)
	var sky := Image.create(96,24,false,Image.FORMAT_RGB8)
	for y in 24:
		sky.fill_rect(Rect2i(0,y,96,1),colors[0].lerp(colors[1],y/23.0))
	if rainbow:
		rainbow.reflect_into(sky)
	material.set_shader_parameter("sky_cache",ImageTexture.create_from_image(sky))

static func sky_colors(phase: String, kind: String) -> Array[Color]:
	if phase=="night":
		return [Color("#172942"),Color("#7a879d")]
	if kind in ["rain","light_rain","storm","misty","snow","light_snow"]:
		return [Color("#6d8592"),Color("#c9d1bf")]
	if phase in ["dawn","dusk"]:
		return [Color("#8a879f"),Color("#f1bd90")]
	return [Color("#4a879b"),Color("#f4dcaa")]
