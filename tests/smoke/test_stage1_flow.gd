extends GutTest
## 스테이지 1 흐름을 화면까지 실제로 돌려 본다(사람 대신 버튼을 누른다). 그림·배치는 폰에서 사람이 본다.

var main: Main


func before_all() -> void:
	GameData.save_prefix = "user://smoke_"
	GameData.use_dev_save(false)
	GameData.save_store.erase()


func after_all() -> void:
	GameData.save_store.erase()
	GameData.use_dev_save(true)
	GameData.save_store.erase()
	GameData.save_prefix = "user://"
	GameData.use_dev_save(false)


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
				_press_first_button(c)
		await wait_physics_frames(2)
		if not any:
			return


func _press_first_button(n: Node) -> void:
	for c in n.find_children("*", "Button", true, false):
		(c as Button).pressed.emit()
		return


func _answer_all(right: bool) -> void:
	for k in 30:
		var q := main.current() as QuizScreen
		if q == null:
			return
		if q._i >= q._qs.size():
			await wait_physics_frames(2)
			continue
		var ans := q._qs[q._i].answer
		q._pick(ans if right else (ans + 1) % q._qs[q._i].options.size())
		await wait_seconds(float(GameData.learning["reveal_sec"]["right" if right else "wrong"]) + 0.3)


func test_stage1_loop() -> void:
	assert_true(main.current() is TitleScreen)
	main.flow.new_game()
	await wait_physics_frames(2)
	assert_true(main.current() is NameScreen)
	(main.current() as NameScreen)._edit.text = "테스트"
	(main.current() as NameScreen)._done()
	await _finish_overlays()
	assert_true(main.current() is FieldScreen, "이야기 뒤 필드로")
	assert_eq(GameData.state.hero_name, "테스트")
	await wait_physics_frames(5)

	# 조우: 모두 맞히면 싸우지 않고 잡는다
	var ids: Array[String] = [GameData.repo.first_tier(1, "field")[0].id]
	main.flow.encounter(ids)
	await wait_physics_frames(2)
	assert_true(main.current() is QuizScreen)
	await _answer_all(true)
	assert_true(main.current() is ResultScreen)
	assert_true(GameData.state.has_word(ids[0]))
	_press_first_button(main.current())
	await wait_physics_frames(3)
	await _finish_overlays()

	# 조우: 틀리면 전투 준비 → 전투 → 결과
	var ids2: Array[String] = [GameData.repo.first_tier(1, "field")[1].id]
	main.flow.encounter(ids2)
	await wait_physics_frames(2)
	await _answer_all(false)
	assert_true(main.current() is BattlePrepScreen, "틀리면 전투 준비")
	var prep := main.current() as BattlePrepScreen
	await wait_physics_frames(2)
	prep._start()
	await wait_physics_frames(2)
	assert_true(main.current() is BattleScreen)
	var bs := main.current() as BattleScreen
	bs.skip_all()
	await wait_seconds(1.0)
	assert_true(bs._end_btn.visible)
	var hist := "\n".join(bs.lines)
	assert_string_contains(hist, "1턴", "기록에 턴이 남는다")
	assert_string_contains(hist, "코인", "기록에 코인 결과가 남는다")
	assert_string_contains(hist, "체력", "기록에 체력 변화가 남는다")
	bs._end_btn.pressed.emit()
	await wait_physics_frames(3)
	for k in 12:  # 새 어근을 익힌 유닛이 기뻐하는 화면이 있으면 넘긴다
		if not main.current() is RootJoyScreen:
			break
		_press_first_button(main.current())
		await wait_physics_frames(3)
	if main.current() is ResultScreen:
		_press_first_button(main.current())
		await wait_physics_frames(3)
	await _finish_overlays()
	assert_true(main.current() is FieldScreen)

	# 진화: 재료를 주고 대장간에서 진화 퀴즈를 모두 맞힌다
	var evo := GameData.repo.evolutions_up_to(1, 2)[0]
	for m in evo.mats:
		GameData.rules.gain_word(GameData.state, m)
	main.flow.go_forge()
	await _finish_overlays()
	assert_true(main.current() is EvolveScreen)
	main.flow.evolve_quiz(evo.id)
	await wait_physics_frames(2)
	await _finish_overlays()
	await _answer_all(true)
	assert_true(GameData.state.has_word(evo.id), "진화 성공")
	_press_first_button(main.current())
	await wait_physics_frames(3)
	await _finish_overlays()

	# 다른 화면
	main.flow.go_dex()
	await wait_physics_frames(2)
	assert_true(main.current() is DexScreen)
	main.flow.go_party()
	await wait_physics_frames(2)
	assert_true(main.current() is PartyScreen)
	main.flow.go_options(main.flow.go_field)
	await wait_physics_frames(2)
	assert_true(main.current() is OptionsScreen)

	# 보스: 길이 열릴 만큼 단어를 주고 싸운다
	for w in GameData.repo.first_tier(1):
		GameData.rules.gain_word(GameData.state, w.id)
	main.flow.go_field()
	await wait_physics_frames(2)
	# 퀘스트를 마치기 전에는 보스와 싸우지 못한다
	main.flow.boss_gate()
	await _finish_overlays()
	assert_true(main.current() is FieldScreen, "퀘스트 전에는 보스에 못 간다")
	# 알림판: 처음엔 받고, 단어가 다 있으면 마친다. 다리(fac)·절벽(de-)은 길목에 닿으면 장면 뒤 열린다
	var noop := func() -> void: pass
	assert_ne(main.flow.quest_gate("s01_q_root", noop), "", "이야기 전에는 다리 퀘스트가 없다")
	GameData.state.flags["s01_skit_cheok"] = true  # 척척 합류 장면 끝에 알림판 퀘스트가 열린다
	main.flow.notice_board(noop)
	await _finish_overlays()
	main.flow.notice_board(noop)
	await _finish_overlays()
	assert_true(GameData.quests.done(GameData.state, "s01_q_word"))
	assert_eq(main.flow.quest_gate("s01_q_root", noop), "")
	await _finish_overlays()
	assert_eq(main.flow.quest_gate("s01_q_magic", noop), "")
	await _finish_overlays()
	assert_true(main.flow.open_gates().get("s01_q_magic", false), "절벽 길이 열린다")
	main.flow.boss_gate()
	await _finish_overlays()
	assert_true(main.current() is BattlePrepScreen)
	(main.current() as BattlePrepScreen)._start()
	await wait_physics_frames(2)
	var boss_screen := main.current() as BattleScreen
	assert_not_null(boss_screen)
	assert_true(boss_screen._ctx.enemies[-1].is_boss)
	boss_screen.skip_all()
	await wait_seconds(1.0)
	boss_screen._end_btn.pressed.emit()
	await wait_physics_frames(3)
	await _finish_overlays()
	assert_true(main.current() is FieldScreen)
	assert_true(GameData.save_store.exists(), "자동 저장")


func test_losing_wakes_up_in_hospital_and_rests_in_town() -> void:
	GameData.new_game("테스트")
	GameData.state.flags["s01_tut_battle"] = true
	var lost := BattleResult.new()
	lost.enemy_count = 2
	main.flow.battle_finished(lost, [] as Array[String], false)
	await wait_physics_frames(2)
	var scene_seen := false
	for c in main._overlay.get_children():
		if c is DialogueOverlay:
			scene_seen = true
	assert_true(scene_seen, "병원에서 깨어나는 장면")
	await _finish_overlays()
	var f := main.current() as FieldScreen
	assert_not_null(f)
	assert_lt(f._hero.distance_to(f.map.spot(1, "hospital")), 5.0, "병원 문 앞")
	assert_gt(main.flow.rest_left(), 170, "3분 쉬기")
	# 마을 밖으로 걸어 나가려 해도 막힌다
	var t: Array = f.map.region(1)["town"]
	var gate := Vector2i(-1, -1)  # 아래 울타리의 열린 문(바깥이 걸을 수 있는 곳)
	for x in range(int(t[0]), int(t[0]) + int(t[2])):
		var c := Vector2i(x, int(t[1]) + int(t[3]) - 1)
		if f.map.ch(c) == "s" and f.map.walkable(c + Vector2i(0, 1)) and f.map.walkable(c - Vector2i(0, 1)):
			gate = c
			break
	assert_ne(gate, Vector2i(-1, -1))
	f._hero = (Vector2(gate - Vector2i(0, 1)) + Vector2(0.5, 0.5)) * f.map.tile
	f._enemies.clear()  # 문 밖 몹과 부딪혀 퀴즈로 넘어가지 않게
	for k in 60:
		f._stick_on = true
		f._stick_vec = Vector2(0, 1)
		await wait_physics_frames(1)
	f._stick_on = false
	assert_true(f.map.is_town(f._hero), "쉬는 동안 마을 밖으로 못 나간다")
	GameData.state.rest_until = 0
