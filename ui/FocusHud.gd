extends MarginContainer

signal focus_pressed
signal duration_pressed
signal cancel_pressed
var title := Label.new()
var weather := Label.new()
var project := Label.new()
var moment := Label.new()
var timer := Button.new()
var duration := Button.new()
var cancel := Button.new()
var controls := HBoxContainer.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans SC","Noto Sans CJK SC","Microsoft YaHei","PingFang SC","Droid Sans Fallback"])
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	for side in ["top","bottom","left","right"]:
		add_theme_constant_override("margin_"+side,16)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	title.text = "鲸鲸小镇"
	title.add_theme_font_size_override("font_size",27)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(weather)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gap)
	column.add_child(moment)
	column.add_child(project)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(controls)
	controls.add_child(timer)
	controls.add_child(duration)
	controls.add_child(cancel)
	cancel.text = "结束本轮"
	cancel.pressed.connect(func():cancel_pressed.emit())
	timer.pressed.connect(func():focus_pressed.emit())
	duration.pressed.connect(func():duration_pressed.emit())
	for label in [title,weather,project,moment]:
		label.add_theme_constant_override("outline_size",4)
		label.add_theme_color_override("font_outline_color",Color("#30474b"))
		label.add_theme_color_override("font_color",Color("#fff3d8"))
	for button in [timer,duration,cancel]:
		button.custom_minimum_size = Vector2(0,38)

func update_home(frame: Dictionary, seconds: int, focus_status: String, minutes: int, message: String) -> void:
	var env: Dictionary = frame.environment
	var phases := {"night":"夜晚","day":"白天","dusk":"黄昏","dawn":"清晨"}
	var seasons := {"spring":"春","summer":"夏","autumn":"秋","winter":"冬"}
	var conditions := {"clear":"晴","cloudy":"多云","windy":"有风","light_rain":"小雨","light_snow":"小雪","misty":"起雾"}
	weather.text = "%s · %s · %s" % [seasons[env.solar.season],phases[env.solar.phase],conditions.get(env.weather.kind,"")]
	var building = frame.fact.get("active_project")
	project.text = "三座建筑已落成" if building == null or building.total_percent >= 100 else "%s   %d%%" % [building.name,building.total_percent]
	moment.text = message
	match focus_status:
		"running":
			timer.text = "暂停   %02d:%02d" % [seconds/60,seconds%60]
		"paused":
			timer.text = "继续专注   %02d:%02d" % [seconds/60,seconds%60]
		_:
			timer.text = "开始专注"
	duration.text = "%d 分钟" % minutes
	duration.visible = focus_status == "idle"
	cancel.visible = focus_status != "idle"
