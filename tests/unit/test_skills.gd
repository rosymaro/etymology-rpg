extends GutTest


func _skill(root: String, cls: String, params: Dictionary, tier: String = "쉬움") -> Skill:
	return EffectRegistry.make_skill(root, {"class": cls, "params": params}, tier)


func test_ple_adds_hp_unless_leg() -> void:
	var ctx := TestHelpers.ctx([])
	var me := TestHelpers.unit(0, 1, 0, 5)
	me.hp = 5
	_skill("ple", "StatBonus", {"hp": 3}).on_clash(ctx, me, me)
	assert_eq(me.hp, 8)
	ctx.no_skill_heal = true
	_skill("ple", "StatBonus", {"hp": 3}).on_clash(ctx, me, me)
	assert_eq(me.hp, 8)


func test_not_only_on_enemies_missing_from_dex() -> void:
	var ctx := TestHelpers.ctx([])
	ctx.in_dex = func(id: String) -> bool: return id == "known"
	var me := TestHelpers.unit(0, 1, 0, 5)
	var foe := TestHelpers.unit(1, 1, 0, 5)
	foe.word_id = "known"
	me.atk = 1
	_skill("not", "UnknownEnemyAtk", {"atk": 2}).on_clash(ctx, me, foe)
	assert_eq(me.atk, 1)
	foe.word_id = "new"
	_skill("not", "UnknownEnemyAtk", {"atk": 2}).on_clash(ctx, me, foe)
	assert_eq(me.atk, 3)


func test_form_copies_enemy_skill() -> void:
	var ctx := TestHelpers.ctx([])
	var me := TestHelpers.unit(0, 1, 0, 5)
	me.atk = 1
	var foe := TestHelpers.unit(1, 1, 0, 5)
	foe.skill = _skill("spect", "StatBonus", {"atk": 2})
	_skill("form", "CopyEnemySkill", {}).on_clash(ctx, me, foe)
	assert_eq(me.atk, 3)


func test_par_rerolls_tails_of_next_ally() -> void:
	# 아군1 뒷면(코인1) → par 발동 못 함. 조건을 쉬움으로 하고 앞면으로 시작
	var ctx := TestHelpers.ctx([true, false, false, true])
	var a1 := TestHelpers.unit(0, 1, 0, 1)
	a1.skill = _skill("par", "RerollNext", {"count": 1})
	var a2 := TestHelpers.unit(0, 1, 0, 30)
	ctx.allies = [a1, a2]
	ctx.enemies = [TestHelpers.unit(1, 3, 0, 30)]
	BattleEngine.new(ctx).run()
	# 코인: a1 앞, 적 뒤, a2 뒤 → 다시 던져 앞
	assert_eq(a2.flips, [true] as Array[bool])


func test_unimplemented_skills_are_not_made() -> void:
	assert_null(EffectRegistry.make_skill("nat", {"class": "Unimplemented"}))
