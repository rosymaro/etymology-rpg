class_name Main
extends Control
## 화면 바꾸기와 대화 겹치기. 게임 흐름(어떤 화면 다음에 무엇)은 GameFlow가 정한다.

var _screen: Screen
var _overlay: Control
var flow: GameFlow
var simulate_kill := false  ## 테스트: 안드로이드가 앱을 갑자기 닫은 것처럼(이어 하기를 지우지 않는다)


## 화면 위아래 여백(세로 화면). 상태 표시줄·제스처 막대·둥근 모서리를 피하고, 아주 긴 폰에서는 가운데로 모은다.
const PAD_TOP := 44.0
const PAD_BOTTOM := 44.0
const MAX_H := 1440.0  ## 이보다 길면 남는 만큼 위아래에 나눠 비운다


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(UiKit.PAPER)  # 여백에 바탕이 없는 화면(필드)도 비어 보이지 않게
	_fit_frame()
	get_viewport().size_changed.connect(_fit_frame)
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
		if a.begins_with("--export-map="):
			_start_capture(a.trim_prefix("--export-map="), "res://tests/visual/export_map.gd")
		if a == "--perf-field":
			_start_capture("", "res://tests/visual/perf_field.gd")
		if a.begins_with("--capture-map="):
			_start_capture(a.trim_prefix("--capture-map="), "res://tests/visual/capture_map.gd")


## 안전 영역(노치·상태 표시줄·제스처 막대)을 뺀 곳에 여백을 더 두고 그 안에 화면을 놓는다.
## 화면의 바탕색(UiKit.fill_bg)은 여백까지 칠하므로 띠가 보이지 않는다.
func _fit_frame() -> void:
	var vh := get_viewport_rect().size.y
	var top := PAD_TOP
	var bottom := PAD_BOTTOM
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.y > 0 and safe.size.y > 0 and safe.size.y < win.y:
		var k := vh / float(win.y)  # 화면 픽셀 → 게임 좌표
		top += maxf(0.0, safe.position.y) * k
		bottom += maxf(0.0, win.y - safe.end.y) * k
	var extra := maxf(0.0, vh - top - bottom - MAX_H)
	offset_top = top + extra / 2.0
	offset_bottom = -(bottom + extra / 2.0)


## 개발용 화면 캡처(tests/visual). APK에는 tests가 없어 이 인자를 줘도 아무 일도 없다.
func _start_capture(dir: String, path := "res://tests/visual/capture_screens.gd") -> void:
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
