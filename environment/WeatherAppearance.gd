extends RefCounted
## Read-only presentation of the environment contract. Older recordings may
## omit atmosphere/surface fields, but preserve measured rain and snowfall.
static func project(environment: Dictionary) -> Dictionary:
	var weather: Dictionary = environment.get("weather",{})
	var surface: Dictionary = environment.get("surface",{})
	var atmosphere: Dictionary = environment.get("atmosphere",{})
	var rain := clampf(weather.get("rain",0.0),0,1)
	var snow := clampf(weather.get("snowfall",0.0),0,1)
	var fog := clampf(weather.get("mist",0.0),0,1)
	var wind := clampf(weather.get("windStrength",0.0),0,1)
	var legacy_cover := maxf(rain,snow)
	if weather.get("kind")=="cloudy":
		legacy_cover = maxf(legacy_cover,0.65)
	var clouds := clampf(weather.get("cloudCover",legacy_cover),0,1)
	var wet := clampf(surface.get("wetness",rain),0,1)
	var night: bool = environment.get("solar",{}).get("phase")=="night"
	var look := {"lowCloud":clouds*0.75,"cloudShadow":clouds*0.65,"shadowContrast":1.0-clouds*0.7,
		"saturation":1.0-fog*0.3-clouds*0.12,"coolTint":clouds*0.4+snow*0.23,
		"eaveDrip":rain*0.8,"waveEnergy":wind*0.8,"lampHalo":(0.50 if night else 0.0)+fog*0.35,
		"ambientRain":rain,"ambientWind":wind,"live2dCool":clouds*0.4,"live2dDim":clouds*0.3}
	for key in look:
		look[key] = clampf(float(atmosphere.get(key,look[key])),0,1)
	look.puddles = clampf(surface.get("puddles",wet*0.8),0,1)
	look.reflection = clampf(surface.get("reflection",wet*0.68+0.18),0,1)
	look.gust = clampf(weather.get("gustStrength",wind),0,1)
	look.leaves = clampf(weather.get("leafGustIntensity",0.0),0,1)
	look.snowCover = clampf(surface.get("snowCover",0.0),0,1)
	look.cloudCover = clouds
	look.rain = rain
	look.snow = snow
	look.fog = fog
	var direction: Array = weather.get("windDirection",[1,0])
	look.wind = Vector2(float(direction[0]),float(direction[1])).limit_length(1)
	look.showers = weather.get("showers",false)==true
	look.thunderstorm = weather.get("thunderstorm",false)==true and environment.get("observationStatus")=="fresh" and environment.get("source")=="kaifeng_live_weather"
	return look

static func daylight(look: Dictionary) -> Color:
	var tint := Color.WHITE.lerp(Color("#adbecb"),float(look.coolTint)*0.45)
	return tint.darkened(float(look.cloudShadow)*0.13)

static func live2d(look: Dictionary) -> Dictionary:
	return {"live2dCool":look.live2dCool,"live2dDim":look.live2dDim,"lampHalo":look.lampHalo}
