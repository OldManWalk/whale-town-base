extends Node2D

const BUDGETS := {"Full":[140,40,4],"Standard":[70,22,2],"Low":[32,12,1],"ToyWindow":[10,4,0]}
var quality := "Standard"
var look := {}
var elapsed := 0.0
var flash := 0.0

static func precipitation_counts(rain: float, snow: float, budget: int) -> Vector2i:
	var scale := float(budget)/maxf(1.0,rain+snow)
	var drops := roundi(scale*rain)
	return Vector2i(drops,mini(budget-drops,roundi(scale*snow)))

func _draw() -> void:
	if look.is_empty():
		return
	var budget: Array = BUDGETS[quality]
	var shower_band := 0.83+0.17*cos(elapsed*0.32) if look.showers else 1.0
	var count := precipitation_counts(look.rain*shower_band,look.snow,budget[0])
	var wind: Vector2 = look.wind*(4.0+look.gust*19.0)
	if look.rain>0:
		draw_rect(Rect2(0,0,480,270),Color(0.24,0.36,0.45,look.rain*0.16))
	for i in count.x:
		var p := Vector2(fposmod(i*47+elapsed*wind.x,480),fposmod(i*71+elapsed*(85+wind.y*0.5),265)).round()
		if not (p.x>386 and p.y>189):
			draw_line(p,p+Vector2(wind.x*0.13,6+look.gust*2),Color(0.88,0.95,0.94,0.73))
	for i in count.y:
		var p := Vector2(fposmod(i*73+elapsed*wind.x+sin(i+elapsed*0.6)*3,480),fposmod(i*19+elapsed*(14+wind.y*0.16),265)).round()
		if not (p.x>386 and p.y>189):
			draw_rect(Rect2(p,Vector2(1+i%2,2)),Color("#e2e9dc"))
	for i in roundi(look.leaves*budget[1]):
		var p := Vector2(fposmod(i*59+elapsed*wind.x,460),109+fposmod(i*31+elapsed*(4+wind.y*0.1),91)).round()
		draw_rect(Rect2(p,Vector2(3,1)),Color("#d6a966"))
	if flash>0:
		draw_rect(Rect2(0,0,480,270),Color(0.82,0.89,1.0,flash*0.18))
