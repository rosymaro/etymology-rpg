extends GutTest
## 스테이지 2(사냥꾼 초원) 흐름: 스테이지 1 보스 뒤 문이 열리고, 구역에 들어서면 첫 장면,
## 초원 단어 3개 → 덥석 합류(발자국 글자), 사냥꾼 공책 퀘스트, 보스 predator → ad-·ob-.

var main: Main


func before_all() -> void:
	GameData.save_prefix = "user://smoke2_"
	GameData.use_dev_save(false)
	GameData.save_store.erase()


func after_all() -> void:
	GameData.save_store.erase()
	GameData.save_prefix = "user://"


func before_each() -> void:
	main = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_physics_frames(2)


func _finish_overlays() -> void:
	for k in 20:
		var any := false
		for c in main._overlay.get_children():
			if c is DialogueOverlay and not c.is_queued_for_deletion():
				any = true
				c._i = c._lines.size()
				c._show()
			elif c is NoticeOverlay and not c.is_queued_for_deletion():
				any = true
				for b in c.find_children("*", "Button", true, false):
					(b as Button).pressed.emit()
					break
		await wait_physics_frames(2)
		if not any:
			return


func _cleared_stage1() -> GameState:
	GameData.new_game("하늘")
	var s := GameData.state
	s.flags["boss_s01"] = true
	s.stage = 2
	return s


func test_gate_to_stage2_opens_after_stage1_boss() -> void:
	var s := _cleared_stage1()
	assert_true(main.flow.open_gates().get(1, false), "1 → 2 문")
	s.flags.erase("boss_s01")
	assert_false(main.flow.open_gates().get(1, false))


func test_current_stage_follows_state() -> void:
	var s := _cleared_stage1()
	s.cur_stage = 2
	assert_eq(GameFlow.cur(), 2)
	assert_eq(GameFlow.sid(), "s02")
	assert_eq(GameData.repo.boss_word(GameFlow.cur()).id, "predator")
	s.cur_stage = 9
	assert_eq(GameFlow.cur(), GameFlow.MAX_STAGE, "만든 스테이지까지만")


func test_entering_stage2_plays_intro_once() -> void:
	var s := _cleared_stage1()
	s.cur_stage = 2
	assert_true(main.flow.enter_stage(2, func() -> void: pass), "처음엔 s02_ki")
	await _finish_overlays()
	assert_true(main.flow.seen("s02_ki"))
	assert_false(main.flow.enter_stage(2, func() -> void: pass), "두 번째는 없다")


func test_three_words_join_deopseok_and_open_board() -> void:
	var s := _cleared_stage1()
	s.cur_stage = 2
	main.flow.town_minigame()
	await _finish_overlays()
	assert_false(main.current() is MinigameScreen, "덥석 합류 전에는 발자국 글자가 닫혀 있다")
	for w in GameData.repo.first_tier(2, "field").slice(0, 3):
		GameData.rules.gain_word(s, w.id)
	main.flow._maybe_cheok()
	await _finish_overlays()
	assert_true(2 in s.joined, "덥석 합류")
	assert_true(main.flow.seen("s02_seung"))
	assert_true(main.flow.seen("s02_tut_attr"), "합류 뒤 속성 무늬 설명")
	var q := GameData.quests.get_quest("s02_q_word")
	assert_true(GameData.quests.visible(s, q), "사냥꾼 공책 퀘스트가 열린다")
	assert_eq(GameData.quests.boss_blockers(s, 2).size(), 1)


func test_stage2_boss_rewards() -> void:
	var s := _cleared_stage1()
	s.cur_stage = 2
	main.flow._boss_won()
	await _finish_overlays()
	assert_true(main.flow.seen("boss_s02"))
	assert_true("ad" in s.magics and "ob" in s.magics, "ad-·ob- 마법")
	assert_eq(s.stage, 3)
	assert_true(s.has_word("predator"))
