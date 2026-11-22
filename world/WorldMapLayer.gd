extends Node2D

const HIGH_CLOUD_SLOTS := 7

var rainbow: RefCounted
var shore := preload("res://art/world/shore.png")
var environment: Dictionary
var look := {}
var elapsed := 0.0
var seasonal_palette := false
var source_pixels: Image

# Each bank fades in over its own fraction of the host's smoothed coverage.
static func high_cloud_alpha(slot: int, cover: float, low_cloud: float, rain: float) -> float:
	var filled := clampf(cover*HIGH_CLOUD_SLOTS-slot,0,1)
	var transmission := 1.0-0.90*maxf(low_cloud,rain)
	return filled*lerpf(0.38,0.78,cover)*transmission

func _draw() -> void:
	if look.is_empty():
		return
	var phase: String = environment.get("solar",{}).get("phase","day")
	var night := phase=="night"
	var colors := preload("res://environment/CoastAtmosphere.gd").sky_colors(phase,environment.weather.kind)
	var top := colors[0].lerp(Color("#607685"),look.lowCloud*(0.22 if night else 0.55))
	var horizon := colors[1].lerp(Color("#a4b0ad"),look.lowCloud*0.48)
	var tint := preload("res://environment/WeatherAppearance.gd").daylight(look)
	for band in 28:
		draw_rect(Rect2(-40,band*4-16,560,4),top.lerp(horizon,band/27.0))
	if night:
		for i in 35:
			draw_rect(Rect2((i*71)%475,7+(i*37)%61,1+(i%2),1),Color(0.90,0.83,0.68,1.0-look.lowCloud))
	var sun := Color("#f9dfac")
	sun.a = clampf(1.0-maxf(look.fog,look.rain)*1.4-look.lowCloud*0.7,0,1)
	if sun.a>0.03:
		var solar: Dictionary = environment.solar
		var center := Vector2(240+float(solar.get("sunAzimuthSide",0.75))*150,25+(1.0-float(solar.get("daylight",0.75)))*28)
		draw_circle(center,10,sun)
		if night:
			draw_circle(center-Vector2(5,4),9,top.lerp(horizon,0.44))
	if rainbow:
		rainbow.draw_sky(self)
	var drift: float = look.wind.x*(0.6+look.gust*4.0)
	for slot in HIGH_CLOUD_SLOTS:
		var alpha := high_cloud_alpha(slot,look.cloudCover,look.lowCloud,look.rain)
		if alpha<=0:
			break
		var i := (2+slot*3)%HIGH_CLOUD_SLOTS
		var x := fposmod(i*83+elapsed*drift,530)-26
		var y := 21+(i*29)%35
		var high_cloud := Color(horizon.lightened(0.12),alpha)
		draw_rect(Rect2(x,y,26,2),high_cloud)
		draw_rect(Rect2(x+8,y-2,13,2),high_cloud)
	for i in 11:
		var cx := fposmod(i*47+elapsed*drift*1.6,552)-30
		var cy: float = 15+(i*11)%37+look.lowCloud*9
		var cloud := Color("#3e5263") if look.thunderstorm or night else Color("#667f8e")
		cloud.a = look.lowCloud*0.8
		var mass := float(look.lowCloud)
		draw_rect(Rect2(cx+3,cy,40+mass*12,3+mass*4),cloud)
		draw_rect(Rect2(cx+10,cy-3,24+mass*12,4),cloud.lightened(0.08))
		draw_rect(Rect2(cx+16,cy-6,12+mass*8,3),cloud.lightened(0.14))
		draw_rect(Rect2(cx+30,cy-2,14,2),cloud.lightened(0.12))
	var ridge := PackedVector2Array([Vector2(-40,100),Vector2(-40,77)])
	for x in range(-40,530,8):
		ridge.append(Vector2(x,78+round(8*sin(x*0.028)+4*cos(x*0.063))))
	ridge.append(Vector2(528,101))
	draw_colored_polygon(ridge,(Color("#566c79") if night else Color("#91ad96"))*tint)
	draw_rect(Rect2(-40,86,560,210),(Color("#365b70") if night else Color("#64acaa"))*tint)
	for i in 82:
		var x := fposmod(i*83+elapsed*drift*(0.5+i%3),504)-12
		draw_rect(Rect2(x,87+(i*41)%200,3+i%13,1),(Color("#658397") if night else Color("#b2dad0"))*tint)
	var soil_tint := Color("#7b879b") if night else Color.WHITE
	if seasonal_palette:
		var season: String = environment.solar.get("season","summer")
		var colors_by_season := {"spring":Color("#eef6d7"),"summer":Color.WHITE,
			"autumn":Color("#f4daa9"),"winter":Color("#d6e4ee")}
		soil_tint *= colors_by_season.get(season,Color.WHITE)
	draw_texture(shore,Vector2.ZERO,soil_tint*tint)
	if seasonal_palette:
		_draw_seasonal_details(night)

func _draw_seasonal_details(night: bool) -> void:
	var season: String = environment.solar.get("season","summer")
	var color: Color = {"spring":Color("#efaeae"),"summer":Color("#a4c786"),
		"autumn":Color("#db994e"),"winter":Color("#e2e9e9")}.get(season,Color.WHITE)
	if source_pixels == null:
		source_pixels = shore.get_image()
	var grass := source_pixels
	if grass == null:
		return
	for i in range(56):
		var point := Vector2i(12+i*37%458,107+i*29%110)
		if not Rect2i(Vector2i.ZERO,grass.get_size()).has_point(point):
			continue
		var pixel := grass.get_pixelv(point)
		if pixel.a<.9 or pixel.g<=pixel.r or pixel.r<=pixel.b:
			continue
		var spot := Vector2(point)
		draw_rect(Rect2(spot,Vector2(2,1 if season=="winter" else 2)),color.darkened(.28 if night else 0.0))
