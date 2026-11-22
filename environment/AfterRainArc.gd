extends RefCounted
## One small original pixel arc serves both the visible sky and its reflection.
## Wet ground alone never triggers a rainbow.
const SIZE := Vector2i(218,86)
const COLORS := [
	Color("#f7a3a0"),Color("#ffc69a"),Color("#f2dfa0"),
	Color("#acd7ac"),Color("#9bcbd3"),Color("#b5b5d5"),
]
var opacity := 0.0
var left := 0
var image: Image
var texture: ImageTexture

func project(environment: Dictionary) -> void:
	opacity = 0
	var sky = environment.get("skyEvent")
	var sun: Dictionary = environment.get("solar",{})
	if not sky is Dictionary or sky.get("kind")!="after_rain_rainbow":
		return
	if sun.get("phase")=="night" or environment.get("observationStatus") in ["stale","unavailable"]:
		return
	var strength = sky.get("intensity")
	if typeof(strength) not in [TYPE_FLOAT,TYPE_INT] or strength<=0:
		return
	opacity = clampf(strength,0,1)
	var azimuth := clampf(sun.get("sunAzimuthSide",0),-1,1)
	left = roundi(240-azimuth*116-SIZE.x/2.0)
	if not image:
		build_pixels()

func build_pixels() -> void:
	image = Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8)
	var center := Vector2(SIZE.x*0.5,99.0)
	for y in SIZE.y:
		for x in SIZE.x:
			var distance := (Vector2(x+0.5,y+0.5)-center)/Vector2(105.0,81.0)
			var depth := (1.0-distance.length())*81.0
			if depth<=0 or depth>=9:
				continue
			var color: Color = COLORS[mini(COLORS.size()-1,floori(depth/1.5))]
			var edge := smoothstep(0.0,1.3,depth)*smoothstep(0.0,1.3,9-depth)
			var haze := 1.0-smoothstep(34.0,92.0,y)*0.48
			color.a = snappedf(edge*haze*0.79,1.0/32.0)
			image.set_pixel(x,y,color)
	texture = ImageTexture.create_from_image(image)

func draw_sky(canvas: CanvasItem) -> void:
	if opacity>0:
		canvas.draw_texture(texture,Vector2(left,0),Color(1,1,1,opacity))

func reflection_key() -> Vector2i:
	if opacity<=0:
		return Vector2i.ZERO
	# Bound rebuilds as a wet surface gradually dries or the sun moves.
	return Vector2i(roundi(left/4.0),ceili(opacity*24.0))

func reflect_into(sky: Image) -> void:
	if opacity<=0:
		return
	for y in sky.get_height():
		var sy := floori((y+0.5)*SIZE.y/sky.get_height())
		for x in sky.get_width():
			var sx := floori((x+0.5)*480.0/sky.get_width())-left
			if sx>=0 and sx<SIZE.x:
				var color := image.get_pixel(sx,sy)
				color.a *= opacity
				if color.a>0:
					sky.set_pixel(x,y,sky.get_pixel(x,y).blend(color))
