extends GutTest
## 01-rpg-base '유닛 레벨과 경험치', 02-rpg-v2 '기존 체계와 연결'

var repo: WordRepository
var rules: ProgressRules
var state: GameState


func before_each() -> void:
	repo = TestHelpers.repo()
	var bal := Balance.new()
	bal.progress = JsonFile.read("res://data/balance/progress.json")
	bal.skills = JsonFile.read("res://data/balance/skills.json")
	bal.skill_roots = {"ple": {"id": "ple", "family": 1, "tier": "쉬움"}}
	rules = ProgressRules.new(repo, bal)
	state = GameState.new()


func test_level_from_cumulative_exp_200_l_squared() -> void:
	assert_eq(rules.level_of(0), 1)
	assert_eq(rules.level_of(800), 2)
	assert_eq(rules.level_of(799), 1)
	assert_eq(rules.level_of(720000), 60)
	assert_eq(rules.level_of(9999999), 60)


func test_capture_gives_all_units_and_wearer_double() -> void:
	var ev := rules.gain_word(state, "fa")
	assert_true(ev["new"])
	assert_eq(state.unit_exp[0], 20, "입는 유닛(만들기)은 2배")
	assert_eq(state.unit_exp[5], 10, "다른 유닛은 스테이지 × 10")


func test_duplicate_gives_one_tenth() -> void:
	rules.gain_word(state, "fa")
	var ev := rules.gain_word(state, "fa")
	assert_false(ev["new"])
	assert_eq(state.unit_exp[5], 11)


func test_evolution_exp_is_max_stage_times_4_times_tier() -> void:
	assert_eq(rules.base_exp(repo.get_word("ev2")), 1 * 4 * 2)


func test_auto_equip_only_empty_slot() -> void:
	assert_eq(rules.gain_word(state, "fa")["equipped"], 1)
	assert_eq(rules.gain_word(state, "fb")["equipped"], 0, "무기 칸이 이미 차 있다")
	assert_eq(state.eq(1).get_in("weapon"), "fa")


func test_dex_keeps_acquisition_order() -> void:
	rules.gain_word(state, "fc")
	rules.gain_word(state, "fa")
	assert_eq(state.dex["fc"], 1)
	assert_eq(state.dex["fa"], 2)


func test_root_unlocks_with_word() -> void:
	var ev := rules.gain_word(state, "fa")
	assert_eq(ev["roots"], ["ple"] as Array[String])
	assert_eq(rules.equippable_roots(state, 1), ["ple"] as Array[String])
	assert_eq(rules.equippable_roots(state, 4).size(), 0, "다른 계열 유닛은 장착할 수 없다")


func test_boss_gate_needs_more_than_half() -> void:
	# 스테이지 1 1차: fa fb fc 3개 → 2개 넘게(=2개 이상) 필요
	assert_false(rules.boss_gate(state, 1)["open"])
	rules.gain_word(state, "fa")
	assert_false(rules.boss_gate(state, 1)["open"])
	rules.gain_word(state, "fb")
	assert_true(rules.boss_gate(state, 1)["open"])
