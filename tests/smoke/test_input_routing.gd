extends GutTest
## 누른 자리와 실제 판정이 어긋나지 않게: 화면 입력 처리 규칙.

var main: Main


func before_each() -> void:
	main = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_physics_frames(2)


## Node._input은 화면 전체 좌표로 모든 입력을 받는다. 캔버스용 처리기 이름으로 쓰면 한 번 더(다른 좌표로) 불린다.
func test_screens_do_not_override_global_input() -> void:
	var dir := DirAccess.open("res://src/ui/minigames")
	var bad: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".gd"):
			var src := FileAccess.get_file_as_string("res://src/ui/minigames/" + f)
			if src.contains("\nfunc _input("):
				bad.append(f)
	assert_eq(bad, [] as Array[String], "미니게임 화면은 _input을 쓰지 않는다(gui_input 처리기는 다른 이름)")


func test_tap_on_dialogue_box_advances() -> void:
	var lines_before := -1
	main.play_scene("s01_intro", func() -> void: pass)
	await wait_physics_frames(2)
	var d: DialogueOverlay = main._overlay.get_child(main._overlay.get_child_count() - 1)
	lines_before = d._i
	# 대화 상자 한가운데(상자 위)를 누른다
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	var box: Control = d.find_children("*", "PanelContainer", false, false)[0]
	ev.position = box.get_global_rect().get_center()
	ev.global_position = ev.position
	get_viewport().push_input(ev, true)
	var up := ev.duplicate()
	up.pressed = false
	get_viewport().push_input(up, true)
	await wait_physics_frames(2)
	assert_eq(d._i, lines_before + 1, "상자 위를 눌러도 다음 줄로 넘어간다")


func test_copy_drag_puts_letter_in_slot_through_real_input() -> void:
	main.flow.play_minigame("copy", "free")
	await wait_physics_frames(3)
	var v := main.current() as CopyView
	var g := v.game as AnagramGame
	while g.ice[0] > 0:
		g.hit(0)
	var from := v._canvas.get_global_transform_with_canvas() * v._tray_rect(0).get_center()
	var to := v._canvas.get_global_transform_with_canvas() * v._slot_rect(0).get_center()
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = from
	e.global_position = from
	get_viewport().push_input(e, true)
	var m := InputEventMouseMotion.new()
	m.position = to
	m.global_position = to
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(m, true)
	var r := e.duplicate()
	r.pressed = false
	r.position = to
	r.global_position = to
	get_viewport().push_input(r, true)
	await wait_physics_frames(2)
	assert_eq(g.slots[0], 0, "끌어서 칸에 놓으면 올라간다")
