extends RefCounted

const PATH := "user://preferences.cfg"
const AUDIO_FIELDS := ["master_volume", "effects_volume", "alert_volume", "ambience_volume"]

var master_volume := 1.0
var effects_volume := 1.0
var alert_volume := 1.0
var ambience_volume := 1.0
var hunter_count := 1

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for field in AUDIO_FIELDS:
		set(field, valid_volume(config.get_value("audio", field, 1.0)))
	var count: Variant = config.get_value("gameplay", "hunter_count", 1)
	hunter_count = int(count) if (count is int or count is float) and count in [1, 2, 3] else 1

func save_settings() -> Error:
	var config := ConfigFile.new()
	for field in AUDIO_FIELDS:
		set(field, valid_volume(get(field)))
		config.set_value("audio", field, get(field))
	hunter_count = hunter_count if hunter_count in [1, 2, 3] else 1
	config.set_value("gameplay", "hunter_count", hunter_count)
	return config.save(PATH)

func valid_volume(value: Variant) -> float:
	if not (value is float or value is int) or not is_finite(float(value)):
		return 1.0
	return clampf(float(value), 0.0, 1.0)
