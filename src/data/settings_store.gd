class_name SettingsStore
extends RefCounted
## 옵션(04-meta.md 2절): 진동·효과음·배경음악. 저장 파일과 따로 둔다(user://settings.cfg).

var path := "user://settings.cfg"
var vibration := true
var sfx := true
var sfx_volume := 0.8
var bgm := true
var bgm_volume := 0.7


func _init(file_path: String = "user://settings.cfg") -> void:
	path = file_path


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	vibration = cf.get_value("options", "vibration", true)
	sfx = cf.get_value("options", "sfx", true)
	sfx_volume = cf.get_value("options", "sfx_volume", 0.8)
	bgm = cf.get_value("options", "bgm", true)
	bgm_volume = cf.get_value("options", "bgm_volume", 0.7)


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("options", "vibration", vibration)
	cf.set_value("options", "sfx", sfx)
	cf.set_value("options", "sfx_volume", sfx_volume)
	cf.set_value("options", "bgm", bgm)
	cf.set_value("options", "bgm_volume", bgm_volume)
	cf.save(path)
