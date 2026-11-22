class_name Main
extends Control
## 화면 바꾸기와 대화 겹치기. 게임 흐름(어떤 화면 다음에 무엇)은 GameFlow가 정한다.

var _screen: Screen
var _overlay: Control
var flow: GameFlow


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 10
	add_child(_overlay)
	flow = GameFlow.new(self)
	flow.start()


func show_screen(screen: Screen, args: Dictionary = {}) -> void:
	if _screen:
		_screen.queue_free()
	_screen = screen
	screen.main = self
	add_child(screen)
	move_child(screen, 0)
	screen.open(args)


func current() -> Screen:
	return _screen


## 대화 장면을 겹쳐 틀고, 끝나면 done을 부른다.
func play_scene(scene_id: String, done: Callable) -> void:
	var d := DialogueOverlay.new()
	_overlay.add_child(d)
	d.play(scene_id, done)


## 짧은 알림 창. 확인을 누르면 닫힌다.
func notice(text: String, done: Callable = Callable()) -> void:
	var n := NoticeOverlay.new()
	_overlay.add_child(n)
	n.show_text(text, done)
