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


func _push_drag(from: Vector2, to: Vector2) -> void:
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


## 화면 좌표(세계 좌표 - 지금 보이는 영역)
func _screen(v: FactoryView, world: Vector2) -> Vector2:
	return v._canvas.get_global_transform_with_canvas() * (world - Vector2(v._cam, 0))


func test_factory_shelf_drag_through_real_input() -> void:
	main.flow.play_minigame("f03", "free")
	await wait_physics_frames(3)
	var v := main.current() as FactoryView
	var g := v.g
	var i: int = g.slots[0]
	var n := g.stack.find(i)
	_push_drag(_screen(v, v._card_rect(n).get_center()), _screen(v, v._slot_rect(0).get_center()))
	await wait_physics_frames(2)
	assert_true(g.board[i]["id"] in g.earned, "끌어서 맞는 뜻 칸에 놓으면 확보")


func test_factory_tap_belt_root_goes_into_furnace() -> void:
	main.flow.play_minigame("f01", "free")
	await wait_physics_frames(3)
	var v := main.current() as FactoryView
	var g := v.g
	for k in 200:
		g.update(0.05)
	await wait_physics_frames(2)  # 화면이 제 폭(영역 너비)을 잡은 뒤
	var it: Dictionary = g.belt[0]
	it["t"] = 0.25  # 벨트 왼쪽 변(GUT 실행 창이 덮는 가운데를 피한다)
	var at := _screen(v, v.belt_pos(it["t"]))
	_push_drag(at, at)
	await wait_physics_frames(2)
	assert_eq(g.furnace.size(), 1, "벨트의 어원을 누르면 용광로에 들어간다")
