extends Node
## 화면을 차례로 띄워 PNG로 저장한다(그림이 그려지는 빌드에서만). Main이 --capture=<폴더> 인자를 보면 이 노드를 붙인다.
## 사용: godot --path . --resolution 1280x720 -- --capture=/절대/경로

var out_dir := "user://shots"
var main: Main
var root: Window


func start(m: Main, dir: String) -> void:
	main = m
	out_dir = dir
	root = get_tree().root
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " ", Time.get_ticks_msec())


func _run() -> void:
	var gd: Node = root.get_node("GameData")
	gd.save_prefix = "user://shots_"
	gd.use_dev_save(false)
	gd.save_store.erase()
	await _shot("01_title")
	main.flow.new_game()
	await _shot("02_name")
	gd.new_game("하늘", "f")
	main.play_scene("s01_intro", func() -> void: pass, true)
	await _shot("03_dialogue")
	var dl: DialogueOverlay = main._overlay.get_child(main._overlay.get_child_count() - 1)
	dl._i = 4  # 낭독 다음: 대장간으로 장면이 바뀐다
	dl._show()
	await get_tree().create_timer(0.8).timeout
	await _shot("03_dialogue_forge")
	gd.state.hero_look = "m"
	for c in main._overlay.get_children():
		c.queue_free()
	var s: GameState = gd.state
	s.joined = [1, 4] as Array[int]
	var field: Array[WordData] = gd.repo.first_tier(1, "field")
	for i in 40:
		gd.rules.gain_word(s, field[i].id)
	var wm := WorldMap.load_default()
	gd.tutorials_enabled = true  # 튜토리얼 모습(08-tutorial.md)
	s.pos = wm.start(1)
	main.flow.go_field()
	await get_tree().create_timer(0.6).timeout
	await _shot("00_tut_field")
	for o in main.current().find_children("*", "TutorialOverlay", true, false):
		o._next()
	await get_tree().create_timer(0.3).timeout
	await _shot("00_tut_field_2")
	for o in main.current().find_children("*", "TutorialOverlay", true, false):
		o._finish()
	gd.tutorials_enabled = false
	s.pos = wm.start(1) + Vector2(260, 200)
	main.flow.go_field()
	await _shot("04_field_gate")
	var fs := main.current() as FieldScreen
	fs._hero = wm.random_field_spot(1, RandomNumberGenerator.new(), wm.start(1), 1200, 1600, 30)
	fs._in_town_now = false
	s.joined = [1, 5, 10] as Array[int]  # 동행 셋: 뚝딱(망치) · 조잘(외침) · 빙글(팽이)
	s.loadout["units"] = [1, 5, 10]
	fs._set_pals()
	fs._run.pick_coins(7)
	for e in fs._enemies:
		e.pos = fs._hero + Vector2.from_angle(randf() * TAU) * randf_range(150, 420)
		e.stun = 99.0  # 찍는 동안 부딪혀 퀴즈로 넘어가지 않게
	await get_tree().create_timer(1.4).timeout
	await _shot("04_field_hunt")
	main.flow.encounter_popup([gd.repo.first_tier(1, "field")[0].id, gd.repo.first_tier(1, "field")[1].id] as Array[String], {}, func() -> void: pass)
	await get_tree().create_timer(0.9).timeout
	await _shot("04_field_quiz_popup")  # 필드 위 반 화면 퀴즈(몹 자리 그대로)
	for c in main._overlay.get_children():
		c.queue_free()
	await get_tree().process_frame
	s.joined = [1, 4] as Array[int]
	s.loadout.erase("units")
	fs._spawn_eater()
	fs._open_level_up()
	await _shot("04_field_levelup")
	fs._choosing.queue_free()
	fs._choosing = null
	(main.current() as FieldScreen)._open_full()
	await _shot("04_field_world_map")
	(main.current() as FieldScreen)._close_full()
	s.pos = wm.spot(1, "forge") + Vector2(60, 110)
	main.flow.go_field()
	await _shot("05_town_forge")
	s.pos = wm.start(1)
	main.flow.go_field()
	await _shot("05_town_plaza")
	s.pos = wm.spot(1, "hospital")
	s.rest_until = int(Time.get_unix_time_from_system()) + 151
	main.flow.go_field()
	await _shot("05_town_hospital_rest")
	s.rest_until = 0
	s.pos = wm.spot(1, "boss") + Vector2(0, 100)
	main.flow.go_field()
	await _shot("05_field_boss")
	var br: Array = wm.quest_gate("s01_q_root")["spot"]
	s.pos = Vector2(float(br[0]), float(br[1])) + Vector2(-200, 0)
	main.flow.go_field()
	await _shot("05_field_bridge")
	(main.current() as FieldScreen)._open_quests()
	await _shot("05_field_quests")
	(main.current() as FieldScreen)._close_quests()
	s.flags["s01_q_root"] = true
	main.flow.go_field()
	await _shot("05_field_bridge_fixed")
	var cl: Array = wm.quest_gate("s01_q_magic")["spot"]
	s.pos = Vector2(float(cl[0]), float(cl[1]))
	main.flow.go_field()
	await _shot("05_field_cliff")
	for kind in ["water", "plates", "lock"]:  # 돌 밀기 퍼즐
		var pq: Dictionary = wm.puzzles.filter(func(x: Dictionary) -> bool: return x["kind"] == kind)[0]
		s.pos = (Vector2(int(pq["entry"][0]), int(pq["entry"][1])) + Vector2(0.5, 0.5)) * wm.tile  # 입구(설 수 있는 칸)
		main.flow.go_field()
		(main.current() as FieldScreen)._enemies.clear()
		await _shot("05_puzzle_" + kind)
	var qc: Dictionary = wm.caves.filter(func(x: Dictionary) -> bool: return x["kind"] == "quest")[0]
	s.pos = wm.cave_out(qc["id"], 0)
	main.flow.go_field()
	(main.current() as FieldScreen)._enemies.clear()
	await _shot("05_cave_mouth")  # 큰 지도의 동굴 입구 앞
	var cm := WorldMap.load_cave(qc["id"])
	var qitem: Dictionary = cm.items[0]
	s.cave = qc["id"]
	s.pos = (Vector2(int(qitem["cell"][0]), int(qitem["cell"][1])) + Vector2(-1.5, 0.5)) * cm.tile
	main.flow.go_field()
	(main.current() as FieldScreen)._enemies.clear()
	await _shot("05_cave_dark")  # 따로 된 동굴 지도
	s.cave = ""
	s.pos = wm.cave_out(qc["id"], 0)
	main.flow.go_field()
	s.notes = ["in-", "forma"]
	var lq: Dictionary = wm.puzzles.filter(func(x: Dictionary) -> bool: return x["kind"] == "lock")[0]
	(main.current() as FieldScreen)._open_lock(gd.puzzles[lq["id"]])
	await _shot("05_puzzle_lock_open")
	(main.current() as FieldScreen)._close_lock()
	s.notes = []
	s.flags.erase("s01_q_root")
	var ids: Array[String] = [field[50].id, field[51].id]
	main.flow.encounter(["information", "format"] as Array[String])
	await _shot("06_quiz_infer")  # 단계 A: 조각을 나눠 뜻까지 보여 준다
	var qz := main.current() as QuizScreen
	qz._pick(qz._qs[0].answer)
	await get_tree().create_timer(0.4).timeout
	await _shot("06_quiz_reveal")  # 풀이
	await get_tree().create_timer(1.6).timeout
	main.flow.encounter(ids)
	await _shot("06_quiz")
	s.stage = 2  # 스테이지 2부터 전투 마법(종류마다 하나씩)이 생긴다
	main.flow.go_battle_prep(ids, false)
	await _shot("07_prep_magic")
	(main.current() as BattlePrepScreen)._start()
	await get_tree().create_timer(0.05).timeout
	await _shot("09_battle_enter")  # 옆 목록에서 커지며 나오는 중
	await get_tree().create_timer(0.55).timeout
	await _shot("09_battle_coins")  # 둘이 함께 코인을 돌린다
	for i in 60:
		await get_tree().process_frame
	var bs := main.current() as BattleScreen
	for k in 900:  # 첫 턴이 끝나고 '다음 턴'을 기다릴 때까지
		await get_tree().process_frame
		if bs and bs._deciding:
			break
	await _shot("09_battle")
	if bs and bs._b_box.combatant:
		bs._show_popup(bs._info(bs._b_box.combatant, bs._b_box.base_lines()), bs._b_box.card_center(), bs._b_box.combatant)
		await _shot("09_battle_enemy_info")
		bs._show_popup(bs._info(bs._a_box.combatant, bs._a_box.base_lines()), bs._a_box.card_center(), bs._a_box.combatant)
		await _shot("09_battle_ally_info")
		bs._show_popup([] as Array[String], Vector2.ZERO)
		var q := ComboQuiz.make(gd.repo, "sub-", ["fac", "form"], RandomNumberGenerator.new())
		if q:
			var ov := ComboQuizOverlay.new()
			bs.add_child(ov)
			ov.open(q, "sub")
			await _shot("09_battle_combo_quiz")
			ov.queue_free()
		for mid in bs._ctx.offer:  # 턴 앞: 공격·효과·순서 마법을 하나 쓴다
			if gd.bal.magic_def(mid)["kind"] != "defense":
				bs.pick_magic(mid)
				await get_tree().create_timer(0.75).timeout
				await _shot("09_battle_magic")
				break
		for mid in ["de", "com", "in"]:  # 마법 카드: 공격(적 위) / 방어(아군 위) / 효과(가운데)
			bs._magic_card(mid)
			await get_tree().create_timer(0.62).timeout
			await _shot("09_magic_" + mid)
			await get_tree().create_timer(0.9).timeout
		for tap in 6:  # 턴이 나올 때까지 '다음'을 누르고, 부딪히는 순간을 찍는다
			bs._tapped = true
			await get_tree().process_frame
			await get_tree().process_frame
			if bs._turn.text != "":
				await get_tree().create_timer(0.95).timeout
				await _shot("09_battle_clash")
				break
			for f in 600:
				await get_tree().process_frame
				if bs._next_btn.visible:
					break
	var hist: Array[Dictionary] = []
	if bs:
		bs.skip_all()
		await get_tree().create_timer(1.0).timeout
		await _shot("09_battle_end")
		bs._show_popup(bs._a_box.base_lines(), bs._a_box.card_center())
		await _shot("09_battle_hold")
		bs._show_popup([] as Array[String], Vector2.ZERO)
		hist = bs.entries
		bs._skip = false  # 쓰러지는 연출만 다시 보기
		bs._b_box.modulate = Color.WHITE
		bs._b_box.rotation_degrees = 0.0
		bs._b_box.scale = Vector2.ONE
		bs._fall_fx(bs._b_box, Combatant.ENEMY)
		await get_tree().create_timer(0.45).timeout
		await _shot("09_battle_fall")
	var r: Array = []
	for i in 3:
		r.append(gd.rules.gain_word(s, field[60 + i].id))
	main.show_screen(ResultScreen.new(), {"events": r, "title": "ui.result.won", "history": hist, "done": func() -> void: pass})
	await _shot("10_result")
	var jr: Array[String] = []
	for rt in gd.bal.skill_roots.keys():
		if gd.bal.root_family(String(rt)) == 1 and jr.size() < 2:
			jr.append(String(rt))
	main.show_screen(RootJoyScreen.new(), {"unit": 1, "roots": jr, "done": func() -> void: pass})
	await get_tree().create_timer(0.3).timeout
	await _shot("10_root_joy")
	var evo: WordData = gd.repo.evolutions_up_to(1, 2)[0]
	for m in evo.mats:
		gd.rules.gain_word(s, m)
	main.show_screen(EvolveScreen.new())
	await _shot("11_evolve")
	main.flow.go_dex()
	await _shot("12_dex")
	(main.current() as DexScreen)._show(gd.repo.get_word(field[0].id))
	await _shot("13_dex_detail")
	main.flow.go_party()
	await _shot("14_party")
	s.wallet = 1200
	main.flow.go_gacha()
	await _shot("17_gacha")
	(main.current() as GachaScreen).pull(10)
	await get_tree().create_timer(2.4).timeout
	await _shot("17_gacha_10")
	main.flow.go_options(main.flow.go_field)
	await _shot("15_options")
	main.notice(TranslationServer.translate("ui.boss.gate").format({"need": 77, "have": 40}))
	await _shot("16_notice")
	for c in main._overlay.get_children():
		c.queue_free()
	main.flow.go_minigames()
	await _shot("17_minigame_hub")
	var n := 18
	for g in MinigameRegistry.games():
		main.flow.play_minigame(g["id"], "free")
		var fv := main.current() as FactoryView
		if fv._intro:  # 10번 안내
			await _shot("%d_mini_%s_intro" % [n, g["id"]])
			fv._intro.queue_free()
			fv._intro = null
		var fg := fv.g
		# 조금 돌려서 벨트를 채운다
		for k in 200:
			fg.update(0.05)
		if fg.has(FactoryGame.ANAGRAM) and not fg.puzzle.is_empty():
			fv._answer = [0] as Array[int]
		if fg.has(FactoryGame.COMBINE) and fg.absorb_n() == 0 and not fg.belt.is_empty():
			for it in fg.belt:
				if fg.section(it) == FactoryGame.COMBINE:
					fg.put(it["uid"])
					break
		if fg.has(FactoryGame.SHELF) and fg.stack.is_empty() and fg.board.size() > 1:
			fg._to_stack(0)
			fg._to_stack(1)
		await _shot("%d_mini_%s" % [n, g["id"]])
		for k in range(fg.areas().size()):
			if k == fv._area:
				continue
			fv._go(k)
			await get_tree().create_timer(0.5).timeout
			await _shot("%d_mini_%s_%s" % [n, g["id"], fg.areas()[k]])
		if fg.absorb_n() > 0:
			for i in fg.absorb_shown().y:
				fg.board[i]["state"] = FactoryGame.SEARCH
				fg.batch.append(i)
			fg.hot = true
			fv._go(fg.areas().find(FactoryGame.COMBINE))
			await get_tree().create_timer(0.5).timeout
			await _shot("%d_mini_%s_hot" % [n, g["id"]])
			fv._open_search()
			var first: String = fg.search.ids()[0]
			var cells := fg.search.cells_of(first)
			fv._search_sel = {"a": cells[0], "b": cells[-1]}
			fv._on_search_input(_release_at())
			await _shot("%d_mini_%s_search" % [n, g["id"]])
		n += 1
	main.flow.go_title()
	await _shot("30_title_modes")
	await _card_gallery(gd)
	gd.save_store.erase()
	get_tree().quit()


## 단어 카드 견본: 속성 1·2·3개, 부위 다섯 가지, 가진 단어/처음 단어.
## 단어찾기 칸 고르기를 끝내는 입력(손을 뗌)
func _release_at() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	return e


func _card_gallery(gd: Node) -> void:
	var layer := ColorRect.new()
	layer.color = UiKit.PAPER
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_child(layer)
	var v := UiKit.vbox(10)
	v.position = Vector2(30, 30)
	layer.add_child(v)
	var picked := {1: [], 2: [], 3: []}
	for id in gd.repo.all_ids():
		var w: WordData = gd.repo.get_word(id)
		var n := mini(3, w.attrs.size())
		if n > 0 and picked[n].size() < 5 and w.slot != "":
			picked[n].append(w)
	for n in [1, 2, 3]:
		var row := UiKit.hbox(10)
		v.add_child(row)
		for i in picked[n].size():
			row.add_child(WordCard.make(picked[n][i], "", 22, Callable(), 1 if i % 2 == 0 else 0))
	await _shot("31_word_cards")
	layer.queue_free()