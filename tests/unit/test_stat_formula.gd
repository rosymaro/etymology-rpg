extends GutTest

var f: StatFormula


func before_each() -> void:
	f = StatFormula.new(JsonFile.read("res://data/balance/unit.json"))


func test_level_growth_follows_unit_json() -> void:
	# 만들기(모두 보통) 레벨 60: 3 + int(0.36*59)=24, 0 + int(0.09*59)=5, 8 + int(0.9*59)=61 (sim-10stage.md 2절)
	var s := f.base(f.role(1), 60)
	assert_eq([s.atk, s.def, s.hp], [24, 5, 61])


func test_coin_count_by_level() -> void:
	assert_eq(f.coins(1), 1)
	assert_eq(f.coins(10), 2)
	assert_eq(f.coins(45), 5)
	assert_eq(f.coins(60), 5)


func test_coin_value_grows_with_level() -> void:
	assert_eq(f.coin_value(1), 3)
	assert_eq(f.coin_value(60), 6)


func test_attack_coin_adds_k_per_head() -> void:
	var flips: Array[bool] = [true, false, true]
	assert_eq(f.coin_terms("atk", 3, flips).atk, 6)


func test_skill_coin_uses_first_half() -> void:
	var flips: Array[bool] = [false, true, true, true]
	assert_eq(f.coin_terms("skill", 3, flips).atk, 3)  # 앞 2개 중 앞면 1개


func test_swing_adds_double_and_loses_hp_on_first_head() -> void:
	var flips: Array[bool] = [true, true]
	var t := f.coin_terms("swing", 3, flips)
	assert_eq([t.atk, t.hp], [12, -3])


func test_skill_condition_min_heads() -> void:
	assert_eq(f.skill_min_heads("쉬움", 5), 1)
	assert_eq(f.skill_min_heads("보통", 5), 3)
	assert_eq(f.skill_min_heads("어려움", 5), 5)
