extends RefCounted

const FocusCalendar = preload("res://environment/FocusCalendar.gd")

var buildings := []

var save_path: String
const DURATIONS := [15, 25, 45]
# started anchors the current running segment; saved seconds remain frozen while paused.
var state := {"version":2, "started":0, "target_minutes":25, "built_minutes":0, "remaining_seconds":0}
var save_readable := true
var error := ""

func configure_buildings(declarations: Array) -> void:
	buildings.clear()
	for status in ["built","building","planned"]:
		for building in declarations:
			if building.initialState==status:
				buildings.append(building)

func _init(path := "user://coast-focus-v1.json") -> void:
	save_path = path
	if not FileAccess.file_exists(save_path):
		return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if saved is Dictionary and load_state(saved):
		return
	save_readable = false
	error = "存档无法读取，请保留原文件。"

func load_state(saved: Dictionary) -> bool:
	var normalized := {}
	var keys := ["version","started","target_minutes","built_minutes"]
	if saved.get("version") == 2:
		keys.append("remaining_seconds")
	for key in keys:
		var value = saved.get(key)
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or value < 0 or value > 9007199254740991 or float(int(value)) != value:
			return false
		normalized[key] = int(value)
	if normalized.version not in [1,2] or normalized.target_minutes not in DURATIONS:
		return false
	var total := int(normalized.target_minutes) * 60
	if normalized.version == 1:
		normalized.remaining_seconds = total if normalized.started > 0 else 0
		normalized.version = 2
	if normalized.remaining_seconds > total or (normalized.started > 0 and normalized.remaining_seconds == 0):
		return false
	state = normalized
	return true

func persist(next: Dictionary) -> bool:
	if not save_readable:
		return false
	error = "本机存档不可写，现有进度已保留。"
	var temp := FileAccess.open(save_path + ".new", FileAccess.WRITE)
	if temp == null:
		return false
	temp.store_string(JSON.stringify(next))
	temp.flush()
	var written := temp.get_error()
	temp.close()
	if written != OK or DirAccess.rename_absolute(save_path + ".new", save_path) != OK:
		return false
	state = next
	error = ""
	return true

func status() -> String:
	if state.started > 0:
		return "running"
	return "paused" if state.remaining_seconds > 0 else "idle"

func select_duration(minutes: int) -> bool:
	if status() != "idle" or minutes not in DURATIONS:
		return false
	var next := state.duplicate()
	next.target_minutes = minutes
	return persist(next)

func start(now: int, minutes: int) -> bool:
	if status() != "idle" or now <= 0 or minutes not in DURATIONS:
		return false
	var next := state.duplicate()
	next.started = now
	next.target_minutes = minutes
	next.remaining_seconds = minutes * 60
	return persist(next)

func pause(now: int) -> bool:
	if status() != "running":
		return false
	var left := remaining(now)
	if left == 0:
		return settle(now)
	var next := state.duplicate()
	next.started = 0
	next.remaining_seconds = left
	return persist(next)

func resume(now: int) -> bool:
	if status() != "paused" or now <= 0:
		return false
	var next := state.duplicate()
	next.started = now
	return persist(next)

func cancel(now: int) -> bool:
	if status() == "idle":
		return false
	if status() == "running" and remaining(now) == 0:
		return settle(now)
	var next := state.duplicate()
	next.started = 0
	next.remaining_seconds = 0
	return persist(next)

# Existing callers use toggle for starting or ending an individual session.
func toggle(now: int, minutes: int) -> bool:
	if status() == "idle":
		return start(now, minutes)
	return cancel(now)

func settle(now: int) -> bool:
	if status() != "running" or remaining(now) > 0:
		return false
	var next := state.duplicate()
	next.built_minutes += next.target_minutes
	next.started = 0
	next.remaining_seconds = 0
	return persist(next)

func remaining(now: int) -> int:
	if status() == "idle":
		return int(state.target_minutes) * 60
	if state.started == 0:
		return int(state.remaining_seconds)
	return maxi(0, int(state.remaining_seconds) - maxi(0, now - int(state.started)))

func frame(now: int) -> Dictionary:
	settle(now)
	var local_offset := int(Time.get_time_zone_from_system().bias) * 60
	var minutes: int = state.built_minutes
	var project: Dictionary = {}
	var completed := {}
	for building in buildings:
		var cost := int(building.get("pomodoroCostMinutes",0))
		if building.initialState=="built" or cost<=0:
			completed[building.id] = 100
			continue
		var progress := clampf(float(minutes)*100/cost,0,100)
		completed[building.id] = progress
		if project.is_empty() or project.total_percent>=100:
			project = {"id":building.id,"name":building.name,"total_percent":progress}
		minutes = maxi(0,minutes-cost)
	return {"environment":FocusCalendar.project(now+local_offset),
		"fact":{"generated_at_ms":now*1000,"active_project":project if not project.is_empty() else null,"building_progress":completed,"night_social":{"active":false,"phase":""},"online_actors":[]}, "moments":[]}
