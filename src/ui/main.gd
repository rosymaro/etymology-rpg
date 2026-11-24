class_name Main
extends Control
## 화면 바꾸기와 대화 겹치기. 게임 흐름(어떤 화면 다음에 무엇)은 GameFlow가 정한다.

var _screen: Screen
var _overlay: Control
var flow: GameFlow
var simulate_kill := false  ## 테스트: 안드로이드가 앱을 갑자기 닫은 것처럼(이어 하기를 지우지 않는다)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 10
	add_child(_overlay)
	var marker := TouchMarker.new()
	add_child(marker)
	flow = GameFlow.new(self)
	flow.start()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			_start_capture(a.trim_prefix("--capture="))


## 개발용 화면 캡처(tests/visual). APK에는 tests가 없어 이 인자를 줘도 아무 일도 없다.
func _start_capture(dir: String) -> void:
	var path := "res://tests/visual/capture_screens.gd"
	if not ResourceLoader.exists(path):
		return
	var cap: Node = load(path).new()
	add_child(cap)
	cap.start(self, dir)


## 다른 앱으로 넘어갈 때(앱이 멈출 때) 지금까지를 저장한다. 안드로이드가 앱을 닫아도 다시 켜면 이어 한다.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		if _screen and _screen.has_method("_remember"):
			_screen.call("_remember")
		GameData.save()


## 앱을 제대로 끝냈을 때(뒤로 가기로 끄기, 최근 앱에서 지우기 등 안드로이드가 끝을 알려 줄 때)는 다음에 처음부터 시작한다.
## 다른 앱을 보는 사이 안드로이드가 몰래 닫은 경우는 여기가 불리지 않아서 이어 하기가 남는다.
func _exit_tree() -> void:
	if not simulate_kill:
		GameData.save()
		GameData.set_resume("")


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
