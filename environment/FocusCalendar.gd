extends RefCounted
## Deterministic offline weather. The same local instant projects the same
## scene after a restart, including water left by a shower.
const SLOT_SECONDS := 6 * 60 * 60
const CHANGE_SECONDS := 12 * 60.0
const DRY_SECONDS := 42 * 60.0
const WEATHER := ["clear","clear","clear","cloudy","cloudy","misty","windy","light_rain","light_rain"]
const SEASONS := ["winter","spring","summer","autumn"]
const DAY_START := {"winter":7.5,"spring":7.0,"summer":6.25,"autumn":7.0}
const DUSK_START := {"winter":16.75,"spring":18.0,"summer":19.0,"autumn":17.0}
const CLOUDS := {"clear":.10,"cloudy":.74,"misty":.40,"windy":.28,"light_rain":.84,"light_snow":.76}

static func season(month: int) -> String:
	return SEASONS[(month%12)/3]

static func condition(clock: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%04d-%02d-%02d/%d" % [clock.year,clock.month,clock.day,int(clock.hour)/6])
	var picked: String = WEATHER[rng.randi_range(0,WEATHER.size()-1)]
	return "light_snow" if picked=="light_rain" and season(int(clock.month))=="winter" else picked

static func sun(hour: float, current_season: String) -> Dictionary:
	var day_start: float = DAY_START[current_season]
	var dusk_start: float = DUSK_START[current_season]
	var dawn_start := day_start - 1.5
	var night_start := dusk_start + 2.0
	var phase := "night"
	if hour >= dawn_start and hour < night_start:
		phase = "dawn" if hour < day_start else ("dusk" if hour >= dusk_start else "day")
	var daylight := smoothstep(dawn_start,day_start,hour) * (1.0-smoothstep(dusk_start,night_start,hour))
	var azimuth := clampf(2.0*(hour-day_start)/(dusk_start-day_start)-1.0, -1, 1)
	return {"hour":hour,"phase":phase,"season":current_season,"daylight":daylight,"sunAzimuthSide":azimuth}

static func project(local_now: int) -> Dictionary:
	var clock := Time.get_datetime_dict_from_unix_time(local_now)
	var seconds := int(clock.hour)*3600+int(clock.minute)*60+int(clock.second)
	var hour := float(seconds)/3600.0
	var solar := sun(hour,season(int(clock.month)))
	var into_slot := posmod(seconds,SLOT_SECONDS)
	var previous := condition(Time.get_datetime_dict_from_unix_time(local_now-into_slot-1))
	var current := condition(clock)
	var ease := smoothstep(0,CHANGE_SECONDS,into_slot)
	var rain := .32*lerpf(float(previous=="light_rain"),float(current=="light_rain"),ease)
	var snow := .32*lerpf(float(previous=="light_snow"),float(current=="light_snow"),ease)
	var residue := 1.0-smoothstep(0,DRY_SECONDS,into_slot)
	var wet := .52*lerpf(float(previous=="light_rain"),float(current=="light_rain"),ease if current=="light_rain" else 1.0-residue)
	var snow_cover := .32*lerpf(float(previous=="light_snow"),float(current=="light_snow"),
		ease if current=="light_snow" else smoothstep(0,2.0*DRY_SECONDS,into_slot))
	var dawn_mist := .15*(1.0-smoothstep(0,1.5,absf(hour-float(DAY_START[solar.season])+.5)))
	var mist := .06+dawn_mist+.55*lerpf(float(previous=="misty"),float(current=="misty"),ease)
	var angle := hour*TAU/24
	var wind := .25+.20*sin(angle)
	var kind := current
	if rain>.005:
		kind = "light_rain"
	elif snow>.005:
		kind = "light_snow"
	elif current in ["light_rain","light_snow"]:
		kind = previous
	var weather := {"kind":kind,"windStrength":wind,"windDirection":[cos(angle),sin(angle)],"leafGustIntensity":wind,
		"rain":rain,"snowfall":snow,"mist":mist,"cloudCover":lerpf(CLOUDS[previous],CLOUDS[current],ease)}
	var surface := {"wetness":wet,"waterLevel":.36+.18*cos(2.0*angle),"snowCover":snow_cover}
	var frame := {"solar":solar,"weather":weather,"surface":surface}
	if previous=="light_rain" and current=="clear" and rain==0.0 and solar.daylight>.3:
		var age := float(into_slot)-CHANGE_SECONDS
		var glow := smoothstep(0,2.0*60,age)*(1.0-smoothstep(5.0*60,16.0*60,age))
		if glow>0:
			frame.skyEvent = {"kind":"after_rain_rainbow","intensity":.72*glow*float(solar.daylight)}
	return frame
