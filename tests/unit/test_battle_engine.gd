extends GutTest
## 01-rpg-base '전투: 4 대 4 서바이벌'


func test_simultaneous_rounds_min_damage_one() -> void:
	var ctx := TestHelpers.ctx([false, false])
	ctx.allies = [TestHelpers.unit(0, 5, 0, 10)]
	ctx.enemies = [TestHelpers.unit(1, 1, 9, 3)]
	var r := BattleEngine.new(ctx).run()
	# 아군 공격 5 − 적 방어 9 → 최소 1, 3라운드에 적이 쓰러진다. 적 공격 1.
	assert_true(r.won())
	assert_eq(ctx.allies[0].hp, 7)


func test_survivor_keeps_hp_and_only_new_unit_flips() -> void:
	# 코인 순서: 아군1, 적1, (적2만 새로 던짐)
	var ctx := TestHelpers.ctx([true, false, true])
	ctx.allies = [TestHelpers.unit(0, 4, 0, 20)]
	ctx.enemies = [TestHelpers.unit(1, 2, 0, 7), TestHelpers.unit(1, 2, 0, 7)]
	var r := BattleEngine.new(ctx).run()
	assert_true(r.won())
	assert_eq(ctx.allies[0].atk, 7, "아군은 처음 코인(앞면) 그대로")
	assert_eq(ctx.enemies[1].atk, 5, "적 2번은 새로 던진 앞면")


func test_both_down_counts_as_kill() -> void:
	var ctx := TestHelpers.ctx([false, false])
	ctx.allies = [TestHelpers.unit(0, 5, 0, 5)]
	ctx.enemies = [TestHelpers.unit(1, 5, 0, 5)]
	var r := BattleEngine.new(ctx).run()
	assert_eq(r.kills(), 1)
	assert_true(r.won(), "마지막에 같이 쓰러져도 적을 다 쓰러뜨렸으면 이긴 것")


func test_first_strike_avoids_mutual_down() -> void:
	var ctx := TestHelpers.ctx([false, false])
	var a := TestHelpers.unit(0, 5, 0, 5)
	a.skill = FirstStrikeSkill.new()
	a.skill.configure("mot", {}, "쉬움")
	ctx.allies = [a]
	ctx.enemies = [TestHelpers.unit(1, 5, 0, 5)]
	# 앞면이 없으면 쉬움 조건(1개)도 못 채운다 → 같이 쓰러짐
	BattleEngine.new(ctx).run()
	assert_true(a.hp <= 0)
	var ctx2 := TestHelpers.ctx([true, false])
	var a2 := TestHelpers.unit(0, 2, 0, 5)
	a2.skill = FirstStrikeSkill.new()
	a2.skill.configure("mot", {}, "쉬움")
	ctx2.allies = [a2]
	ctx2.enemies = [TestHelpers.unit(1, 5, 0, 5)]
	BattleEngine.new(ctx2).run()
	assert_true(a2.hp > 0, "먼저 쳐서 쓰러뜨리면 반격을 받지 않는다")


func test_reward_rule_partial_gives_one_killed_word() -> void:
	var r := BattleResult.new()
	r.enemy_count = 3
	r.killed = [1]
	var words: Array[String] = ["a", "b", "c"]
	assert_eq(RewardRule.words_won(r, words, FixedCoinSource.new()), ["b"] as Array[String])
	r.killed = []
	assert_eq(RewardRule.words_won(r, words, FixedCoinSource.new()).size(), 0)
	r.killed = [0, 1, 2]
	assert_eq(RewardRule.words_won(r, words, FixedCoinSource.new()).size(), 3)
