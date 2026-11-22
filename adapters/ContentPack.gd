extends RefCounted

static func read_data(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func artwork(base: String, entry: Dictionary) -> Texture2D:
	var relative: String = entry.relativePath
	if entry.licenseTier != "open_redistributable" or relative.is_absolute_path() or ".." in relative.split("/"):
		return null
	var path := base.path_join(relative)
	if path.begins_with("res://"):
		return load(path)
	var image := Image.load_from_file(path)
	if image and not image.is_empty():
		return ImageTexture.create_from_image(image)
	return null
