extends GutTest
## 튜토리얼(08-tutorial.md): 처음에만, 바깥은 반투명 회색, 눌러야 하는 단계는 그 자리를 눌러야 넘어간다, 건너뛰기.

var main: Main


func before_each() -> void:
	GameData.save_prefix = "user://tut_"
	GameData.use_dev_save(false)
	GameData.tutorials_enabled = true
	main = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_physics_frames(2)
	GameData.new_game("테스트")


func after_each() -> void:
	GameData.tutorials_enabled = false
	GameData.save_store.erase()
	GameData.save_prefix = "user://"
	GameData.use_dev_save(false)


func _overlay(n: Node) -> TutorialOverlay:
	for c in n.find_children("*", "TutorialOverlay", true, false):
		if not c.is_queued_for_deletion():
			return c
	return null


func _click(o: TutorialOverlay, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	for d in o._dims:
		if Rect2(d.global_position, d.size).has_point(at):
			d.gui_input.emit(ev)


func test_book_marks_seen_and_reset() -> void:
	var s := GameState.new()
	assert_true(TutorialBook.should(s, "field", true))
	assert_false(TutorialBook.should(s, "field", false), "꺼져 있으면 안 보인다")
	TutorialBook.mark(s, "field")
	assert_false(TutorialBook.should(s, "field", true), "본 것은 다시 안 나온다")
	TutorialBook.reset_all(s)
	assert_true(TutorialBook.should(s, "field", true))


func test_field_tutorial_dims_outside_and_waits_for_tap_on_quest_button() -> void:
	main.flow.go_field()
	var o: TutorialOverlay = null
	for k in 30:
		await wait_physics_frames(1)
		o = _overlay(main.current())
		if o:
			break
	assert_not_null(o, "처음 필드에 오면 튜토리얼")
	assert_eq(o._dims[0].color, TutorialOverlay.DIM, "바깥은 반투명한 밝은 회색")
	assert_lt(o._dims[0].color.a, 0.7)
	assert_eq(o._text.get_theme_color("font_color"), Color.WHITE, "말풍선 글씨는 밝게")
	# 읽기 단계: 바깥을 누르면 넘어간다
	var last := o.steps.size() - 1
	while o.i < last:
		await wait_seconds(0.3)
		_click(o, Vector2(5, 1270))
		await wait_physics_frames(2)
	assert_eq(o.steps[o.i]["mode"], "tap")
	await wait_seconds(0.3)
	_click(o, Vector2(5, 1270))
	await wait_physics_frames(2)
	assert_eq(o.i, last, "눌러야 하는 단계는 바깥을 눌러도 안 넘어간다")
	(o.steps[o.i]["target"] as Button).pressed.emit()
	await wait_physics_frames(2)
	assert_null(_overlay(main.current()), "그 자리를 누르면 끝")
	assert_true(TutorialBook.seen(GameData.state, "field"))
	main.flow.go_field()
	await wait_physics_frames(5)
	assert_null(_overlay(main.current()), "두 번째에는 안 나온다")


func test_skip_ends_and_marks() -> void:
	main.flow.go_party()
	var o: TutorialOverlay = null
	for k in 10:
		await wait_physics_frames(1)
		o = _overlay(main.current())
		if o:
			break
	assert_not_null(o, "처음 유닛 창")
	o._finish()
	await wait_physics_frames(2)
	assert_true(TutorialBook.seen(GameData.state, "party"))
