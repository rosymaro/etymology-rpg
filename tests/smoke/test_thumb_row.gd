extends GutTest
## 자주 누르는 버튼은 엄지 자리(UiKit.THUMB_ROW)에: 조우 퀴즈 4번째 보기와 같은 높이.

var main: Main


func before_each() -> void:
	main = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_physics_frames(2)
	main.flow.dev_game()
	await wait_physics_frames(2)


func after_each() -> void:
	GameData.save_store.erase()
	GameData.use_dev_save(false)


func _cy(c: Control) -> float:
	return c.get_global_rect().get_center().y


func test_quiz_fourth_option_battle_buttons_and_result_ok_share_one_row() -> void:
	var ids: Array[String] = [GameData.repo.first_tier(1, "field")[0].id]
	main.flow.encounter(ids)
	await wait_physics_frames(4)
	var q := main.current() as QuizScreen
	var fourth: Control = q._opts.get_child(3)
	var row := _cy(fourth)
	main.flow.go_battle_prep(ids, false)
	await wait_physics_frames(3)
	var prep := main.current() as BattlePrepScreen
	assert_almost_eq(_cy(prep._nav), row, 2.0, "전투 준비 다음 버튼")
	prep._start()
	await wait_physics_frames(3)
	var bs := main.current() as BattleScreen
	assert_almost_eq(_cy(bs._next_btn), row, 2.0, "전투 다음")
	assert_almost_eq(_cy(bs._end_btn), row, 2.0, "결과 보기")
	main.show_screen(ResultScreen.new(), {"events": [], "title": "ui.result.won", "history": [], "done": func() -> void: pass})
	await wait_physics_frames(3)
	var ok: Button = null
	for b in main.current().find_children("*", "Button", true, false):
		ok = b
	assert_almost_eq(_cy(ok), row, 2.0, "결과 확인")
