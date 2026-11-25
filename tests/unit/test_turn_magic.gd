extends GutTest
## 턴마다 고르는 전투 마법(01-rpg-base '마법 쓰기'): 엔진은 턴 앞에서 멈추고, 고른 마법을 먼저 건 뒤 공격한다.


func _ctx(flips: Array = []) -> BattleContext:
	var c := TestHelpers.ctx(flips)
	for m in GameData.bal.magic["magics"]:
		c.magic_defs[m["id"]] = m
	return c


func _defs() -> Array:
	return GameData.bal.magic["magics"]


func test_engine_stops_before_each_turn() -> void:
	var ctx := _ctx()
	ctx.allies = [TestHelpers.unit(0, 2, 0, 10, 0)]
	ctx.enemies = [TestHelpers.unit(1, 1, 0, 6, 0)]
	var eng := BattleEngine.new(ctx)
	eng.begin()
	assert_eq(ctx.log[-1]["t"], "clash", "첫 턴 앞에서 멈춘다")
	assert_false(eng.finished)
	eng.turn("")
	assert_eq(ctx.log[-1]["t"], "round")
	assert_eq(eng.turns, 1)
	while not eng.finished:
		eng.turn("")
	assert_eq(eng.res.killed, [0])


func test_de_in_the_middle_hits_the_current_enemy() -> void:
	var ctx := _ctx()
	ctx.power = 3
	ctx.allies = [TestHelpers.unit(0, 1, 0, 30, 0)]
	var e := TestHelpers.unit(1, 4, 0, 20, 0)
	ctx.enemies = [e]
	var eng := BattleEngine.new(ctx)
	eng.begin()
	eng.turn("")
	eng.turn("de")
	var mg := ctx.log.filter(func(ev: Dictionary) -> bool: return ev["t"] == "magic")
	assert_eq(mg.size(), 1)
	assert_true(mg[0].has("before"), "화면이 전→후를 깜빡일 수 있다")
	assert_eq(e.atk, 3, "공격 −1")
	assert_eq(ctx.used, ["de"] as Array[String])


func test_ex_sends_both_fighters_back_with_more_hp() -> void:
	var ctx := _ctx()
	ctx.power = 4  # ceil(P/2) = 2
	var a1 := TestHelpers.unit(0, 1, 0, 10, 0)
	var a2 := TestHelpers.unit(0, 1, 0, 10, 0)
	ctx.allies = [a1, a2]
	var e1 := TestHelpers.unit(1, 1, 0, 10, 0)
	var e2 := TestHelpers.unit(1, 1, 0, 10, 0)
	ctx.enemies = [e1, e2]
	var eng := BattleEngine.new(ctx)
	eng.begin()
	eng.turn("")  # 둘 다 9
	eng.turn("ex")
	assert_eq(ctx.cur(Combatant.ALLY), a2, "다음 아군이 나왔다")
	assert_eq(ctx.cur(Combatant.ENEMY), e2)
	var enters := ctx.log.filter(func(ev: Dictionary) -> bool: return ev["t"] == "enter")
	assert_eq(enters.size(), 4, "새 두 유닛이 나온다")
	while not eng.finished:
		eng.turn("")
	var back := ctx.log.filter(func(ev: Dictionary) -> bool: return ev["t"] == "enter" and ev["idx"] == 0 and ev["side"] == Combatant.ALLY)
	if back.size() > 1:
		assert_eq(back[1]["hp"], 11, "9 + 지나친 1명 × 2, 다시 나와도 체력은 그대로")


func test_sub_pools_waiting_allies_hp_to_the_fighter() -> void:
	var ctx := _ctx()
	var a1 := TestHelpers.unit(0, 1, 0, 10, 0)
	var a2 := TestHelpers.unit(0, 1, 0, 8, 0)
	var a3 := TestHelpers.unit(0, 1, 0, 6, 0)
	ctx.allies = [a1, a2, a3]
	ctx.enemies = [TestHelpers.unit(1, 1, 0, 50, 0)]
	var eng := BattleEngine.new(ctx)
	eng.begin()
	eng.turn("sub")
	assert_eq(a1.hp, 10 + 4 + 3 - 1, "4 + 3을 받고 한 대 맞는다")
	assert_eq(a2.pre_damage, 4)
	eng.turn("sub", false)
	var fail := ctx.log.filter(func(ev: Dictionary) -> bool: return ev["t"] == "magic" and ev.get("failed", false))
	assert_eq(fail.size(), 1, "퀴즈를 틀리면 마법만 쓰이고 효과는 없다")


func test_in_rerolls_tails_with_better_odds() -> void:
	var ctx := _ctx([false, false, true, true])
	var a := TestHelpers.unit(0, 1, 0, 30, 2)
	ctx.allies = [a]
	ctx.enemies = [TestHelpers.unit(1, 1, 0, 30, 0)]
	var eng := BattleEngine.new(ctx)
	eng.begin()
	assert_eq(a.heads(), 0)
	eng.turn("in")
	assert_eq(a.heads(), 2, "뒷면 둘을 다시 던져 앞면")
	assert_eq(a.heads_chance, 0.75)


func test_stage1_has_no_battle_magic_and_stage2_gets_one_of_each_kind() -> void:
	var s := GameState.new()
	assert_eq(GameData.rules.battle_magics(s).size(), 0, "스테이지 1에는 전투 마법이 없다")
	s.stage = 2
	var got := GameData.rules.battle_magics(s)
	got.sort()
	assert_eq(got, ["de", "ex", "in", "sub"] as Array[String])
	var kinds := {}
	for id in got:
		kinds[GameData.bal.magic_def(id)["kind"]] = true
	assert_eq(kinds.size(), 4, "종류마다 하나씩")


func test_offer_is_three_random_and_defense_needs_a_combo() -> void:
	var s := GameState.new()
	s.stage = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var off := GameData.rules.magic_offer(s, [], rng)
	assert_eq(off.size(), 3)
	assert_false("sub" in off, "조합 단어가 없으면 방어 마법은 나오지 않는다")
	var seen := {}
	for k in 30:
		for id in GameData.rules.magic_offer(s, ["fac"], rng):
			seen[id] = true
	assert_true(seen.has("sub"), "fac이 있으면 suffice로 sub-를 쓸 수 있다")


func test_combo_quiz_needs_all_right_and_no_wrong() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var q := ComboQuiz.make(GameData.repo, "sub-", ["fac"], rng)
	assert_not_null(q)
	assert_eq(q.options.size(), ComboQuiz.OPTIONS)
	var right := -1
	var wrong := -1
	for i in q.options.size():
		if q.options[i]["right"]:
			right = i
		else:
			wrong = i
	assert_eq(q.pick(right), "done")
	assert_true(q.all_found())
	var q2 := ComboQuiz.make(GameData.repo, "sub-", ["fac"], rng)
	for i in q2.options.size():
		if not q2.options[i]["right"]:
			assert_eq(q2.pick(i), "wrong")
			break
	assert_true(q2.failed)
	assert_null(ComboQuiz.make(GameData.repo, "sub-", ["zzz"], rng), "조합 단어가 없으면 퀴즈도 없다")
