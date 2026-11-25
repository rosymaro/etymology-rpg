extends GutTest
## 턴마다 고르는 전투 마법(01-rpg-base '마법 쓰기'): 엔진은 턴 앞에서 멈추고, 고른 마법을 먼저 건 뒤 공격한다.


func _ctx(flips: Array = []) -> BattleContext:
	var c := TestHelpers.ctx(flips)
	for m in GameData.bal.magic["magics"]:
		c.magic_defs[m["id"]] = m
	return c


func _defs() -> Array:
	return GameData.bal.magic["magics"]


func _p(id: String) -> Dictionary:
	return GameData.bal.magic_def(id)["params"]


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


func test_ex_sends_only_my_fighter_back_with_more_hp() -> void:
	var ctx := _ctx()
	ctx.power = 6  # ceil(P/3) = 2
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
	assert_eq(ctx.cur(Combatant.ENEMY), e1, "적은 그대로(지금 아군에게만 건다)")
	assert_eq(a1.hold_hp, 11, "9 + 지나친 1명 × 2")


func test_sub_pools_waiting_allies_hp_to_the_fighter() -> void:
	var ctx := _ctx()
	var a1 := TestHelpers.unit(0, 1, 0, 10, 0)
	var a2 := TestHelpers.unit(0, 1, 0, 10, 0)
	var a3 := TestHelpers.unit(0, 1, 0, 7, 0)
	ctx.allies = [a1, a2, a3]
	ctx.enemies = [TestHelpers.unit(1, 1, 0, 50, 0)]
	var eng := BattleEngine.new(ctx)
	eng.begin()
	eng.turn("sub")
	var sp: Dictionary = _p("sub")
	var g2 := int(floor(10 * float(sp["give_ratio"])))
	var g3 := int(floor(7 * float(sp["give_ratio"])))
	assert_eq(a1.hp, 10 + int(floor((g2 + g3) * float(sp["boost_pct"]) / 100.0)) - 1, "동료가 보탠 몫(×boost)을 받고 한 대 맞는다")
	assert_eq(a2.pre_damage, g2)
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
	assert_eq(a.heads_chance, 0.65)


## 한 턴 마법만 걸고(공격 전) 결과를 본다.
func _cast(id: String, allies: Array, enemies: Array, power := 4, chance := true) -> BattleContext:
	var ctx := _ctx()
	ctx.power = power
	(ctx.coin_source as FixedCoinSource).always_chance = chance
	ctx.allies.assign(allies)
	ctx.enemies.assign(enemies)
	var eng := BattleEngine.new(ctx)
	eng.begin()
	ctx.use_magic(id)
	return ctx


func test_attack_damage_is_flat_plus_ten_percent_of_enemy_hp() -> void:
	var e := TestHelpers.unit(1, 5, 0, 200, 0)
	_cast("de", [TestHelpers.unit(0, 1, 0, 30, 0)], [e], 4)
	assert_eq(e.hp, 200 - (Formula.int_value(_p("de")["damage"], {"P": 4}) + 20), "고정값 + 체력 10%(올림): 후반 큰 적에게도 듣는다")
	var e2 := TestHelpers.unit(1, 5, 0, 31, 0)
	_cast("un", [TestHelpers.unit(0, 1, 0, 30, 0)], [e2], 4)
	assert_eq(e2.hp, 31 - (Formula.int_value(_p("un")["damage"], {"P": 4}) + 4), "고정값 + ceil(3.1)")


func test_attack_magic_hits_only_the_current_enemy() -> void:
	var e1 := TestHelpers.unit(1, 5, 0, 30, 0)
	var e2 := TestHelpers.unit(1, 5, 0, 30, 0)
	_cast("ob", [TestHelpers.unit(0, 1, 0, 30, 0)], [e1, e2])
	assert_lt(e1.hp, 30)
	assert_eq(e2.pre_damage, 0, "기다리는 적은 안 맞는다(전체 마법 없음)")


func test_un_undoes_enemy_coins_and_in_neg_seals_skills() -> void:
	var ctx := _ctx([true, true])
	ctx.power = 2
	var e := TestHelpers.unit(1, 2, 0, 40, 2)
	ctx.allies = [TestHelpers.unit(0, 1, 0, 30, 0)]
	ctx.enemies = [e]
	var eng := BattleEngine.new(ctx)
	eng.begin()
	var atk0 := e.atk
	ctx.use_magic("un")
	assert_eq(e.heads(), 2 - int(ceil(2 * float(_p("un")["undo_pct"]) / 100.0)), "코인 앞면 일부(undo_pct)가 뒷면으로")
	assert_lt(e.atk, atk0, "코인으로 오른 공격이 사라진다")
	ctx.use_magic("in_neg")
	assert_true(e.sealed)


func test_ob_reflects_and_com_shares_this_clash() -> void:
	var a := TestHelpers.unit(0, 1, 0, 30, 0)
	var e := TestHelpers.unit(1, 10, 0, 100, 0)
	var ctx := _cast("ob", [a], [e], 2)
	var hp0 := e.hp
	var eng := BattleEngine.new(ctx)
	eng._a = a
	eng._b = e
	eng._round(a, e)
	assert_eq(e.hp, hp0 - 1 - int(ceil(10 * float(_p("ob")["reflect_pct"]) / 100.0)), "공격 1 + 받은 10의 일부 되돌림")
	var a1 := TestHelpers.unit(0, 1, 0, 30, 0)
	var a2 := TestHelpers.unit(0, 1, 0, 30, 0)
	var e2 := TestHelpers.unit(1, 10, 0, 100, 0)
	var c2 := _cast("com", [a1, a2], [e2])
	var eng2 := BattleEngine.new(c2)
	eng2._round(a1, e2)
	var share := int(floor(10 * float(_p("com")["share_pct"]) / 100.0))
	assert_eq(a1.hp, 30 - (10 - share), "share_pct만큼 동료가 맡는다")
	assert_eq(a2.pre_damage, int(ceil(share * float(_p("com")["taken_pct"]) / 100.0)), "함께 막아 맡은 몫보다 덜 받는다")


func test_defense_magic_on_the_current_ally() -> void:
	var a := TestHelpers.unit(0, 1, 0, 30, 0)
	var e := TestHelpers.unit(1, 10, 0, 100, 0)
	_cast("ad", [a], [e])
	assert_eq(a.reduce, Formula.int_value(_p("ad")["shield"]), "ad-: 받는 피해 -shield")
	var b := TestHelpers.unit(0, 1, 0, 30, 0)
	var c := _cast("inter", [b], [TestHelpers.unit(1, 10, 0, 100, 0)], 4)
	var wr := Formula.int_value(_p("inter")["rounds"])
	var wv := Formula.int_value(_p("inter")["reduce"], {"P": 4})
	assert_eq([b.wall, b.wall_rounds], [wv, wr], "inter-: rounds턴 동안 -reduce")
	var eng := BattleEngine.new(c)
	for k in wr + 1:
		eng._round(b, c.enemies[0])
	assert_eq(b.hp, 30 - (10 - wv) * wr - 10, "벽은 rounds턴만")
	var p := TestHelpers.unit(0, 1, 0, 30, 0)
	_cast("prae", [p], [TestHelpers.unit(1, 10, 0, 100, 0)])
	assert_true(p.first_strike)
	var r := TestHelpers.unit(0, 1, 0, 40, 0)
	var rc := _cast("re", [r], [TestHelpers.unit(1, 10, 0, 100, 0)], 4)
	assert_eq(r.hp, 40 + Formula.int_value(_p("re")["heal"], {"P": 4}) + int(ceil(40 * float(_p("re")["hp_pct"]) / 100.0)), "heal + 최대 체력 hp_pct%")


func test_dis_halves_the_current_enemy_attack() -> void:
	var e := TestHelpers.unit(1, 9, 0, 100, 0)
	_cast("dis", [TestHelpers.unit(0, 1, 0, 30, 0)], [e])
	assert_eq(e.atk, 9 - int(ceil(9 * float(_p("dis")["cut_pct"]) / 100.0)), "공격 cut_pct% 줄인다")


func test_pro_pulls_the_last_enemy_forward_weakened_or_fails() -> void:
	var e1 := TestHelpers.unit(1, 5, 0, 30, 0)
	var e2 := TestHelpers.unit(1, 5, 0, 30, 0)
	var boss := TestHelpers.unit(1, 9, 0, 100, 0)
	var ctx := _cast("pro", [TestHelpers.unit(0, 1, 0, 30, 0)], [e1, e2, boss], 4, true)
	assert_eq(ctx.cur(Combatant.ENEMY), boss, "가장 뒤의 적이 맨 앞으로")
	assert_eq(boss.pre_damage, Formula.int_value(_p("pro")["damage"], {"P": 4}) + 10, "고정값 + 체력 10%")
	assert_eq(boss.perm_atk, -2, "지나친 2명 × 공격 -1")
	assert_eq(ctx.waiting(Combatant.ENEMY)[0], e1, "싸우던 적은 바로 뒤로")
	var f1 := TestHelpers.unit(1, 5, 0, 30, 0)
	var fb := TestHelpers.unit(1, 9, 0, 100, 0)
	var c2 := _cast("pro", [TestHelpers.unit(0, 1, 0, 30, 0)], [f1, fb], 4, false)
	assert_eq(c2.cur(Combatant.ENEMY), f1, "실패하면 그대로")
	assert_true(c2.log.filter(func(ev: Dictionary) -> bool: return ev["t"] == "magic" and ev.get("failed", false)).size() == 1)


func test_every_battle_magic_is_implemented() -> void:
	for m in _defs():
		assert_true(EffectRegistry.magic_implemented(m), "%s(%s)" % [m["id"], m["class"]])


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
