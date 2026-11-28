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
		await wait_physics_frames(2)
		q._next()  # 풀이를 읽고 다음
		await wait_physics_frames(2)


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
	for _k in 300:  # 빨리 보기: 끝날 때까지(느린 기계에서도)
		if bs._ended:
			break
		await wait_physics_frames(1)
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
	for _k in 300:  # 빨리 보기: 끝날 때까지(느린 기계에서도)
		if boss_screen._ended:
			break
		await wait_physics_frames(1)
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


## 벽 없이 탁 트인 들판 자리(오른쪽으로 500px, 둘레 120px가 다 지나갈 수 있다). 무작위 자리가 벽 옆이면 시험이 흔들린다.
func _open_field_spot(m: WorldMap) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 400:
		var p := m.random_field_spot(1, rng, m.start(1), 900, 2200, 30)
		if p == Vector2.INF:
			continue
		var ok := true
		for x in range(-2, 9):
			for y in range(-2, 3):
				var c := m.cell(p + Vector2(x * 60, y * 60))
				if not m.walkable(c) or m.is_town(p + Vector2(x * 60, y * 60)) or m.ch(c) == "c":
					ok = false
		if ok:
			return p
	return Vector2.INF


func test_field_hunt_hammer_kills_mob_and_bag_is_banked_in_town() -> void:
	GameData.new_game("테스트")
	GameData.state.flags["s01_tut_battle"] = true
	var m := WorldMap.load_default()
	GameData.state.pos = _open_field_spot(m)
	assert_ne(GameData.state.pos, Vector2.INF, "탁 트인 들판 자리")
	main.flow.go_field()
	await wait_physics_frames(2)
	var f := main.current() as FieldScreen
	assert_false(f.map.is_town(f._hero))
	# 몹 하나만 망치 사거리 안에 둔다(레벨에 따라 새로 생기는 몹은 이 시험 동안 막는다)
	f._spawn_t = 1e9
	f._enemies.clear()
	var e := FieldMob.new()
	e.kind = "wander"
	e.max_hp = 2
	e.hp = 2
	e.words = ["information"] as Array[String]
	e.pos = f._hero + Vector2(160, 0)  # 맞으면 밀려나도 망치 사거리 안
	e.stun = 99.0
	f._enemies.append(e)
	for k in 400:
		await wait_physics_frames(1)
		if not f._enemies.has(e):
			break
	assert_false(f._enemies.has(e), "망치가 저절로 날아가 몹을 쓰러뜨린다")
	f._enemies.clear()  # 쓰러뜨린 자리에 새로 생긴 몹이 다가와 조우로 넘어가지 않게
	assert_false(f._drops.is_empty(), "구슬이 떨어진다")
	f._hero = (f._drops[0]["pos"] as Vector2) + Vector2(60, 0)  # 끌어당기는 거리 안으로 다가간다
	for k in 120:  # 구슬이 빨려 와 주머니에
		await wait_physics_frames(1)
		if int(f._run.bag()["orbs"]) > 0:
			break
	assert_gt(int(f._run.bag()["orbs"]), 0, "구슬은 주머니에")
	var exp0 := GameData.state.unit_exp[0]
	f._hero = f.map.start(1)
	await wait_physics_frames(3)
	var orbs := int(f._run.bag()["orbs"])
	assert_gt(orbs, 0, "사용자 의견: 마을에 들어가도 구슬은 그대로")
	assert_gt(GameData.state.unit_exp[0], exp0, "새로 모은 구슬이 경험치가 된다")


func test_mobs_never_enter_town_and_look_by_attribute() -> void:
	GameData.new_game("테스트")
	GameData.state.flags["s01_tut_battle"] = true
	GameData.state.pos = WorldMap.load_default().start(1)
	main.flow.go_field()
	await wait_physics_frames(2)
	var f := main.current() as FieldScreen
	for e in f._enemies:
		assert_false(f.map.is_town(e.pos), "몹은 마을에 생기지 않는다")
		assert_gt(e.attr, 0, "몹 색은 단어 속성으로")
		assert_ne(e.slot, "", "몹 모양은 단어 착용 부위로")
	# 마을 문 바로 밖의 쫓는 몹과 뿌리먹이: 마을 안 주인공을 쫓아도 들어오지 못한다
	var t: Array = f.map.region(1)["town"]
	var gate := Vector2i(-1, -1)
	for x in range(int(t[0]), int(t[0]) + int(t[2])):
		var c := Vector2i(x, int(t[1]) + int(t[3]) - 1)
		if f.map.ch(c) == "s" and f.map.walkable(c + Vector2i(0, 1)):
			gate = c
			break
	f._enemies.clear()
	for kind in ["chase", "eater"]:
		var m := FieldMob.new()
		m.kind = kind
		m.hp = 3
		m.max_hp = 3
		m.pos = (Vector2(gate + Vector2i(0, 2)) + Vector2(0.5, 0.5)) * f.map.tile
		f._enemies.append(m)
	f._hero = (Vector2(gate - Vector2i(0, 2)) + Vector2(0.5, 0.5)) * f.map.tile
	for k in 90:
		await wait_physics_frames(1)
	assert_true(main.current() is FieldScreen, "마을 안에서는 몹과 마주치지 않는다")
	for e in f._enemies:
		assert_false(f.map.is_town(e.pos), "%s 몹이 마을에 들어오지 못한다" % e.kind)


func test_push_rock_open_chest_and_piece_lock() -> void:
	GameData.new_game("테스트")
	GameData.state.flags["s01_tut_battle"] = true
	GameData.puzzles.clear()
	var wm := WorldMap.load_default()
	var q: Dictionary = wm.puzzles.filter(func(x: Dictionary) -> bool: return x["kind"] == "plates")[0]
	GameData.state.pos = (Vector2(int(q["entry"][0]), int(q["entry"][1])) + Vector2(0.5, 0.5)) * wm.tile
	main.flow.go_field()
	await wait_physics_frames(2)
	var f := main.current() as FieldScreen
	f._enemies.clear()
	var pz: PushPuzzle = GameData.puzzles[q["id"]]
	# 돌 왼쪽에 서서 오른쪽으로 민다
	var rock: Vector2i = pz.rocks.keys()[0]
	f._hero = (Vector2(rock - Vector2i(1, 0)) + Vector2(0.5, 0.5)) * f.map.tile
	for k in 40:
		f._stick_on = true
		f._stick_vec = Vector2(1, 0)
		await wait_physics_frames(1)
		if not pz.rocks.has(rock):
			break
	f._stick_on = false
	assert_true(pz.rocks.has(rock + Vector2i(1, 0)), "돌이 한 칸 밀렸다")
	assert_true(f.map.extra_block.has(rock + Vector2i(1, 0)), "밀린 돌이 길을 막는다")
	# 발판을 다 채우면 상자가 열린다
	f._open_chest(pz)
	assert_false(GameData.state.flags.get("chest_" + pz.id, false), "발판 전에는 안 열린다")
	pz.rocks.clear()
	for c in pz.plates:
		pz.rocks[c] = "R"
	var coins := GameData.state.wallet
	f._open_chest(pz)
	assert_true(GameData.state.flags.get("chest_" + pz.id, false))
	assert_gt(GameData.state.wallet, coins, "보물: 코인")
	# 조각 자물쇠: 쪽지 조각을 차례로 눌러 답 단어
	var lq: Dictionary = wm.puzzles.filter(func(x: Dictionary) -> bool: return x["kind"] == "lock")[0]
	var lz: PushPuzzle = GameData.puzzles[lq["id"]]
	GameData.state.notes = ["forma", "in-"]
	f._open_lock(lz)
	assert_not_null(f._lock)
	var btns := f._lock.find_children("*", "Button", true, false)
	(btns[1] as Button).pressed.emit()  # in-
	(btns[0] as Button).pressed.emit()  # forma
	assert_true(GameData.state.flags.get("chest_" + lz.id, false), "in + form = inform 으로 열린다")
	assert_true(GameData.state.has_word("inform"))


func test_right_words_are_caught_and_only_wrong_ones_fight() -> void:
	main.flow.new_game()
	await wait_physics_frames(2)
	await _finish_overlays()
	var pool := GameData.repo.first_tier(1, "field")
	var ids: Array[String] = [pool[2].id, pool[3].id]
	main.flow.encounter(ids)
	await wait_physics_frames(2)
	for k in 2:  # 첫 단어는 맞히고 둘째는 틀린다
		var q := main.current() as QuizScreen
		var ans := q._qs[q._i].answer
		q._pick(ans if k == 0 else (ans + 1) % q._qs[q._i].options.size())
		await wait_physics_frames(2)
		q._next()
		await wait_physics_frames(2)
	for f in 20:
		if main.current() is BattlePrepScreen:
			break
		await wait_physics_frames(2)
	assert_true(main.current() is BattlePrepScreen, "틀린 단어가 있으면 전투 준비")
	assert_eq((main.current() as BattlePrepScreen)._words, [ids[1]] as Array[String], "틀린 단어만 싸운다")
	assert_true(GameData.state.has_word(ids[0]), "맞힌 단어는 싸우지 않고 잡았다")
	assert_false(GameData.state.has_word(ids[1]))


## 사용자 버그: 뚝딱이만 데리고 있을 때 척척이가 합류하면 척척이가 안 보이고 공격만 주인공에게서 나갔다.
func test_new_companion_appears_on_field_without_restart() -> void:
	GameData.new_game("하늘")
	GameData.tutorials_enabled = false
	GameData.state.flags["s01_tut_battle"] = true
	var m := WorldMap.load_default()
	GameData.state.pos = _open_field_spot(m)
	main.flow.go_field()
	await wait_physics_frames(2)
	var f := main.current() as FieldScreen
	assert_eq(f._pal_units().size(), 1, "처음에는 하나")
	var second := 2 if not 2 in GameData.state.joined else 3
	GameData.state.joined.append(second)  # 필드에 있는 동안 합류
	GameData.state.loadout.erase("units")
	await wait_seconds(0.7)
	assert_eq(f._pal_units(), Loadout.companions(GameData.state), "보이는 동행과 공격하는 동행이 같다")
	assert_eq(f._pal_units().size(), 2, "새 동행이 주인공 옆에 보인다")


## 사용자 의견: 개발자 모드(자유 탐험)는 보스 말고 단어 전투에 안 들어가고, 벽에 안 막힌다.
func test_free_roam_mode_walks_through_walls_and_skips_word_battles() -> void:
	main.flow.dev_game(true)
	await wait_physics_frames(2)
	_finish_overlays()
	var f := main.current() as FieldScreen
	assert_not_null(f)
	assert_true(GameData.state.free_roam)
	var m := f.map
	# 벽(산) 칸 위로 걸어갈 수 있다
	var wall := Vector2i(-1, -1)
	for y in m.h:
		for x in m.w:
			if m.rows[y][x] == "^":
				wall = Vector2i(x, y)
				break
		if wall.x >= 0:
			break
	var target := (Vector2(wall) + Vector2(0.5, 0.5)) * m.tile
	assert_eq(m.move_free(target - Vector2(40, 0), Vector2(40, 0), 22.0), target, "벽 칸으로 들어간다")
	# 몹에 닿아도 퀴즈(단어 전투)로 가지 않는다
	GameData.state.pos = _open_field_spot(m)
	main.flow.go_field()
	await wait_physics_frames(2)
	f = main.current() as FieldScreen
	f._spawn_t = 1e9
	f._enemies.clear()
	var e := FieldMob.new()
	e.kind = "wander"
	e.max_hp = 999
	e.hp = 999
	e.words = ["information"] as Array[String]
	e.pos = f._hero
	f._enemies.append(e)
	await wait_physics_frames(10)
	assert_true(main.current() is FieldScreen, "닿아도 필드 그대로")
	GameData.use_save("free")
	GameData.save_store.erase()
	GameData.use_save("story")


## 사용자 의견: 성벽 너머로는 쏘지 못한다(입구로만). 마을 안의 주인공은 몹이 알아채지 못한다.
func test_town_does_not_shoot_over_wall_and_mobs_ignore_hero_inside() -> void:
	GameData.new_game("하늘")
	GameData.tutorials_enabled = false
	GameData.state.flags["s01_tut_battle"] = true
	var m := WorldMap.load_default()
	var t: Array = m.region(1)["town"]
	var wall := Vector2i(-1, -1)
	for x in range(int(t[0]) + 2, int(t[0]) + int(t[2]) - 2):  # 남쪽 성벽 가운데 성문이 아닌 곳
		var c := Vector2i(x, int(t[1]) + int(t[3]) - 1)
		if m.ch(c) == "M" and m.ch(c + Vector2i(-1, 0)) == "M" and m.ch(c + Vector2i(1, 0)) == "M":
			wall = c
			break
	GameData.state.pos = (Vector2(wall) + Vector2(0.5, -1.5)) * m.tile
	main.flow.go_field()
	await wait_physics_frames(2)
	var f := main.current() as FieldScreen
	assert_true(f.map.is_town(f._hero), "마을 안")
	f._spawn_t = 1e9
	f._enemies.clear()
	var e := FieldMob.new()
	e.kind = "chase"
	e.max_hp = 999
	e.hp = 999
	e.words = ["information"] as Array[String]
	e.pos = (Vector2(wall) + Vector2(0.5, 2.0)) * m.tile
	f._enemies.append(e)
	for k in 30:
		f._hero = GameData.state.pos
		e.pos = (Vector2(wall) + Vector2(0.5, 2.0)) * m.tile
		await wait_physics_frames(3)
	assert_eq(e.hp, 999, "성벽 너머 몹은 맞히지 못한다")
	assert_false(m.shot_line(GameData.state.pos, e.pos), "성벽이 무기를 막는다")
	assert_true(e.ignore, "마을 안의 주인공은 알아채지 못한다")
	assert_true(main.current() is FieldScreen, "전투로 넘어가지 않는다")
