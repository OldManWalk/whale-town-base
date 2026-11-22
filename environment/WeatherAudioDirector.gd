extends AudioStreamPlayer

const RATE := 22050
const BUS := "TownCoast"
const SILENT_DB := -100.0
@onready var rain_player := AudioStreamPlayer.new()
@onready var drip_player := AudioStreamPlayer.new()
@onready var thunder_player := AudioStreamPlayer.new()
var rain_gain_db := SILENT_DB
var drip_gain_db := SILENT_DB
var lowpass := AudioEffectLowPassFilter.new()
var coast_bus := ""

func _init() -> void:
	volume_db = -31

func _ready() -> void:
	for player in [rain_player,drip_player,thunder_player]:
		add_child(player)
	if AudioServer.get_driver_name()=="Dummy" and Engine.get_write_movie_path().is_empty():
		return
	start_playback()

func start_playback() -> void:
	if not coast_bus.is_empty():
		return
	# Give each scene its own filter. Voice and unrelated players stay on their original buses.
	coast_bus = BUS if AudioServer.get_bus_index(BUS)<0 else "%s_%s" % [BUS,get_instance_id()]
	AudioServer.add_bus()
	var index := AudioServer.bus_count-1
	AudioServer.set_bus_name(index,coast_bus)
	AudioServer.add_bus_effect(index,lowpass)
	for player in [self,rain_player,drip_player,thunder_player]:
		player.bus = coast_bus
	stream = shoreline_loop()
	rain_player.stream = weather_sound(false)
	drip_player.stream = eave_drips()
	thunder_player.stream = weather_sound(true)
	rain_player.volume_db = rain_gain_db
	drip_player.volume_db = drip_gain_db
	thunder_player.volume_db = -17
	play()
	rain_player.play()
	drip_player.play()

func finish_playback() -> void:
	for player in [rain_player,drip_player,thunder_player]:
		player.stop()
		player.stream = null
	stop()
	stream = null

func _exit_tree() -> void:
	finish_playback()
	var index := AudioServer.get_bus_index(coast_bus)
	if index>0:
		AudioServer.remove_bus(index)

static func pcm(data: PackedByteArray, samples: int, looped: bool, stereo: bool = false) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = RATE
	wave.stereo = stereo
	wave.data = data
	if looped:
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_end = samples
	return wave

static func shoreline_loop() -> AudioStreamWAV:
	var samples := RATE*8
	var data := PackedByteArray()
	data.resize(samples*2)
	var random := RandomNumberGenerator.new()
	random.seed = 840127
	var bass := 0.0
	var foam := 0.0
	for i in samples:
		var phase := float(i)/samples
		var noise := random.randf_range(-1.0,1.0)
		bass = lerpf(bass,noise,0.022)
		foam = lerpf(foam,noise,0.16)
		# Two uneven crests rise and recede. The quieter trough separates surf from steady rain.
		var crest := pow(0.5-0.5*cos(phase*TAU*2+sin(phase*TAU)*0.55),2.0)
		var envelope := clampf(float(mini(i,samples-1-i))/(RATE*0.04),0,1)
		var amplitude := (bass*(0.29+1.65*crest)+foam*(0.035+0.50*crest))*envelope
		data.encode_s16(i*2,clampi(roundi(amplitude*27000),-32767,32767))
	return pcm(data,samples,true)

static func eave_drips() -> AudioStreamWAV:
	var samples := RATE*9
	var data := PackedByteArray()
	data.resize(samples*4)
	var random := RandomNumberGenerator.new()
	random.seed = 18427
	# Separated impacts along the eave, with an occasional softer second drop.
	for onset in [0.32,0.96,1.15,2.37,3.53,3.74,4.91,6.18,7.56,8.34]:
		var start := roundi(float(onset)*RATE)
		var pan := random.randf_range(-0.48,0.48)
		var pitch := random.randf_range(840.0,1350.0)
		var strength := random.randf_range(0.6,0.95)
		var length := roundi(0.17*RATE)
		for i in length:
			var t := float(i)/RATE
			var attack := minf(1.0,t/0.002)
			var release := minf(1.0,float(length-1-i)/(RATE*0.012))
			var impact := random.randf_range(-0.22,0.22)*exp(-t/0.006)
			var phase := TAU*pitch*(t-0.008*(1.0-exp(-t/0.022)))
			var drop := 0.67*sin(phase)*exp(-t/0.032)+0.13*sin(phase*1.47)*exp(-t/0.048)
			var sample := (drop+impact)*attack*release*strength*32000.0
			data.encode_s16((start+i)*4,roundi(sample*sqrt(0.5*(1.0-pan))))
			data.encode_s16((start+i)*4+2,roundi(sample*sqrt(0.5*(1.0+pan))))
	return pcm(data,samples,true,true)

static func weather_sound(thunder: bool) -> AudioStreamWAV:
	var samples := RATE*(4 if thunder else 3)
	var data := PackedByteArray()
	data.resize(samples*2)
	var random := RandomNumberGenerator.new()
	random.seed = 30091 if thunder else 712983
	var bass := 0.0
	var last := 0.0
	for i in samples:
		var t := float(i)/RATE
		var noise := random.randf_range(-1,1)
		bass = lerpf(bass,noise,0.009)
		var amplitude := noise*0.34-last*0.14
		last = noise
		if thunder:
			amplitude = (bass*2.8+0.16*sin(t*TAU*47.0+sin(t*11.0)))*exp(-t*0.78)*(0.68+0.32*cos(t*6.5))
		var envelope := clampf(float(mini(i,samples-1-i))/(RATE*0.025),0,1)
		data.encode_s16(i*2,clampi(roundi(amplitude*28000*envelope),-32767,32767))
	return pcm(data,samples,not thunder)

func rumble() -> void:
	if thunder_player.stream:
		thunder_player.play()

func apply(weather: Dictionary, indoors: bool = false, atmosphere: Dictionary = {}) -> void:
	var fog := clampf(float(weather.get("mist",0)),0,1)
	var wind := clampf(float(atmosphere.get("ambientWind",weather.get("windStrength",0))),0,1)
	var waves := clampf(float(atmosphere.get("waveEnergy",wind)),0,1)
	var rain := clampf(float(weather.get("rain",0)),0,1)
	# ambientRain also includes wet ground in the contract. Rainfall alone opens the steady bed.
	var falling := minf(rain,clampf(float(atmosphere.get("ambientRain",rain)),0,1))
	var eave := clampf(float(atmosphere.get("eaveDrip",rain*0.8)),0,1)
	var shelter := 8.0 if indoors else 0.0
	lowpass.cutoff_hz = 850.0 if indoors else lerpf(10500.0,1550.0,fog)
	volume_db = -31.0+15.0*sqrt(waves)+2.0*wind-3.0*fog-shelter
	pitch_scale = lerpf(0.92,1.08,waves)
	rain_gain_db = maxf(SILENT_DB,linear_to_db(falling*0.36))-shelter
	drip_gain_db = maxf(SILENT_DB,linear_to_db(sqrt(eave)*0.75))-shelter
	if rain_player:
		rain_player.volume_db = rain_gain_db
	if drip_player:
		drip_player.volume_db = drip_gain_db
		drip_player.pitch_scale = lerpf(0.85,1.15,eave)
