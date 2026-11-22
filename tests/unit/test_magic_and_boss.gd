extends GutTest


func _de() -> BattleMagic:
	return EffectRegistry.make_magic({"id": "de", "prefix": "de-", "kind": "attack", "class": "StrikeFirst",
		"params": {"damage": "2*P", "atk_down": 1}})


func test_de_hits_first_enemy_before_it_enters_and_lowers_attack() -> void:
	var ctx := TestHelpers.ctx([false, false])
	ctx.power = 3
	ctx.magic = _de()
	ctx.allies = [TestHelpers.unit(0, 1, 0, 30)]
	var e := TestHelpers.unit(1, 4, 0, 20)
	ctx.enemies = [e]
	BattleEngine.new(ctx).run()
	assert_eq(ctx.log[0]["t"], "magic")
	assert_eq(ctx.log[0]["damage"], 6)
	var enter_e := ctx.log.filter(func(ev: Dictionary) -> bool: return ev["t"] == "enter" and ev["side"] == Combatant.ENEMY)
	assert_eq(enter_e[0]["hp"], 14, "나올 때 피해 6을 받고 나온다")
	assert_eq(e.atk, 3, "공격 −1")


func test_de_half_damage_on_de_words() -> void:
	var ctx := TestHelpers.ctx([])
	ctx.power = 3
	var e := TestHelpers.unit(1, 4, 0, 20)
	e.prefixes = ["de-"] as Array[String]
	ctx.enemies = [e]
	_de().cast(ctx, Combatant.ALLY)
	assert_eq(e.pre_damage, 3)


func test_recast_magic_skill_casts_again_once() -> void:
	var ctx := TestHelpers.ctx([true, false, true])
	ctx.power = 2
	ctx.magic = _de()
	var a := TestHelpers.unit(0, 1, 0, 50)
	a.skill = EffectRegistry.make_skill("fac", {"class": "RecastMagic", "params": {}}, "쉬움")
	ctx.allies = [a]
	ctx.enemies = [TestHelpers.unit(1, 1, 0, 9), TestHelpers.unit(1, 1, 0, 9)]
	BattleEngine.new(ctx).run()
	var magic_events := ctx.log.filter(func(ev: Dictionary) -> bool: return ev["t"] == "magic")
	assert_eq(magic_events.size(), 2)


func test_destroyer_coin_lock_turns_first_head_to_tails() -> void:
	var ctx := TestHelpers.ctx([true, true, false])
	ctx.is_boss_battle = true
	var a := TestHelpers.unit(0, 2, 0, 30, 2)
	ctx.allies = [a]
	var b := TestHelpers.unit(1, 1, 0, 5)
	b.is_boss = true
	b.boss_ability = EffectRegistry.make_boss({"class": "CoinLock", "params": {"count": 1}})
	ctx.enemies = [b]
	BattleEngine.new(ctx).run()
	assert_eq(a.flips, [false, true] as Array[bool])
	assert_eq(a.atk, 5, "앞면 1개만 남아 2 + 3")


func test_level_gate_reduces_damage_per_missing_level() -> void:
	var g := EffectRegistry.make_boss({"class": "LevelGate", "params": {"level": 60, "per_level": 2}})
	var atk := TestHelpers.unit(0, 1, 0, 1)
	atk.level = 57
	assert_eq(g.modify_incoming(null, null, atk, 10), 4)
	atk.level = 60
	assert_eq(g.modify_incoming(null, null, atk, 10), 10)
