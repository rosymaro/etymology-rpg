class_name Screen
extends Control
## 모든 화면의 바탕. Main이 만들고 open()으로 값을 넘긴다. 화면끼리는 Main(진행)을 통해서만 넘어간다.

var main: Main


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open(_args: Dictionary) -> void:
	pass


func t(key: String) -> String:
	return TranslationServer.translate(key)
