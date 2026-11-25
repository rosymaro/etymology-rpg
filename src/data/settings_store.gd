class_name SettingsStore
extends RefCounted
## 옵션(04-meta.md 2절): 진동·효과음·배경음악, 지도 효과(하나씩 끄기), FPS 표시. 저장 파일과 따로 둔다(user://settings.cfg).

var path := "user://settings.cfg"
var vibration := true
var sfx := true
var sfx_volume := 0.8
var bgm := true
var bgm_volume := 0.7
var touch_marker := false  ## 누른 자리에 표시(터치 위치 확인용)
## 지도 효과(사용자 의견: 폰에서 프레임이 떨어지면 하나씩 끈다)
var map_grass := true  ## 풀·꽃·바닥 장식
var map_sway := true  ## 바람에 풀·나무가 흔들림
var map_water := true  ## 물결·물가 거품·끓는 용암
var map_critters := true  ## 뛰어다니는 작은 동물
var map_particles := true  ## 바람에 날리는 것(꽃잎·눈·불씨 …)
var show_fps := false  ## 필드 구석에 초당 프레임 수

const MAP_KEYS := ["map_grass", "map_sway", "map_water", "map_critters", "map_particles", "show_fps"]


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
	touch_marker = cf.get_value("options", "touch_marker", false)
	for k in MAP_KEYS:
		set(k, cf.get_value("options", k, get(k)))


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("options", "vibration", vibration)
	cf.set_value("options", "sfx", sfx)
	cf.set_value("options", "sfx_volume", sfx_volume)
	cf.set_value("options", "bgm", bgm)
	cf.set_value("options", "bgm_volume", bgm_volume)
	cf.set_value("options", "touch_marker", touch_marker)
	for k in MAP_KEYS:
		cf.set_value("options", k, get(k))
	cf.save(path)
