extends GutTest
## 처음 화면 세 갈래, 개발자 모드, 미니게임 메뉴와 10개 화면, 마을 미니게임 → 단어 시험.

var main: Main


func before_all() -> void:
	GameData.save_prefix = "user://smoke2_"
	GameData.use_dev_save(false)


func after_all() -> void:
	for dev in [false, true]:
		GameData.use_dev_save(dev)
		GameData.save_store.erase()
	GameData.save_prefix = "user://"
	GameData.use_dev_save(false)


func before_each() -> void:
	main = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_physics_frames(2)


func _press_notice_buttons() -> void:
	for c in main._overlay.get_children():
		for b in c.find_children("*", "Button", true, false):
			(b as Button).pressed.emit()
			break


func test_dev_mode_has_everything_and_separate_save() -> void:
	main.flow.dev_game()
	await wait_physics_frames(3)
	assert_true(main.current() is FieldScreen)
	var s := GameData.state
	assert_true(s.dev_mode)
	assert_eq(s.dex_count(), GameData.repo.size())
	assert_eq(s.joined.size(), 12)
	assert_eq(GameData.rules.level(s, 1), 60)
	assert_eq(GameData.repo.get_word(s.eq(1).get_in("weapon")).tier, 4, "부위마다 가장 높은 차수")
	assert_true(GameData.rules.boss_gate(s, 1)["open"])
	assert_string_ends_with(GameData.save_store.path, "dev_save.json")
	main.flow.go_battle_prep([] as Array[String], true)
	await wait_physics_frames(2)
	assert_eq((main.current() as BattlePrepScreen)._party.size(), 4)


func test_hub_lists_ten_and_each_game_opens_and_ends() -> void:
	main.flow.go_minigames()
	await wait_physics_frames(2)
	assert_true(main.current() is MinigameHubScreen)
	for g in MinigameRegistry.games():
		main.flow.play_minigame(g["id"], "free")
		await wait_physics_frames(3)
		var scr := main.current() as MinigameScreen
		assert_not_null(scr, g["id"])
		assert_gt(scr.game.words.size(), 0)
		scr._quit()
		await wait_seconds(0.8)
		if main.current() is SearchView:
			assert_true((main.current() as SearchView)._review, "못 찾은 답을 판에 보여 준다")
			(main.current() as MinigameScreen)._proceed()
			await wait_physics_frames(2)
		if main.current() is PatternView:
			assert_true((main.current() as PatternView)._review, "끝나고 정답 어원을 보여 준다")
			(main.current() as MinigameScreen)._proceed()
			await wait_physics_frames(2)
		assert_true(main.current() is MinigameResultScreen, "보상 없는 결과 화면: " + g["id"])


func test_order_view_play_and_story_reward_goes_through_quiz() -> void:
	main.flow.dev_game()
	await wait_physics_frames(2)
	GameData.state.dex.clear()
	GameData.state.roots_cache.clear()
	main.flow.town_minigame()
	await wait_physics_frames(3)
	var scr := main.current() as OrderView
	assert_not_null(scr)
	var g := scr.game as OrderGame
	var w: int = g.shelf[0]
	var first := g.words[w].id
	for p in g.pieces(w):
		for it in g.items:
			if it["w"] == w and it["piece"] == p:
				it["d"] = 0.3
				g.pick(it["uid"])
				break
		g.action = {"kind": "furnace"}
		g.act()
	g.action = {"kind": "hammer"}
	g.act()
	g.place(0)
	scr.changed()
	scr._quit()
	await wait_seconds(0.9)
	var q := main.current() as QuizScreen
	assert_not_null(q, "얻은 단어 시험")
	q._pick(q._qs[0].answer)
	await wait_seconds(1.5)
	assert_true(main.current() is ResultScreen)
	assert_true(GameData.state.has_word(first))
