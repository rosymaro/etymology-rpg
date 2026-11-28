extends GutTest
## 필드 사냥(07-fun.md 1절): 떨어지는 것, 레벨업 보기, 주머니와 마을, 지면 절반, 뿌리먹이.

var cfg: Dictionary
var rng := RandomNumberGenerator.new()


func before_each() -> void:
	cfg = JsonFile.read("res://data/balance/field_hunt.json")
	rng.seed = 11


func test_starts_with_hammer_and_levels_up_from_orbs() -> void:
	var run := HuntRun.new({}, cfg)
	assert_eq(run.level(), 0)
	assert_true(run.d["weapons"].has("u01"), "처음 무기는 뚝딱의 망치")
	var need := run.need()
	assert_false(run.pick_orbs(need - 1))
	assert_true(run.pick_orbs(1), "구슬이 차면 레벨업")
	assert_eq(run.level(), 1)
	assert_eq(int(run.bag()["orbs"]), need, "구슬은 주머니에도 담긴다")


func test_level_up_choices_upgrade_companion_weapons() -> void:
	var run := HuntRun.new({}, cfg)
	run.set_units([1, 10])
	var seen := {}
	for k in 30:
		for c in run.choices(rng):
			seen[c["type"] + ":" + c["id"]] = true
	assert_true(seen.has("up:u01") and seen.has("up:u10"), "데리고 다니는 유닛의 무기 강화")
	assert_false(seen.has("up:u05"), "안 데리고 다니는 유닛 무기는 안 나온다")
	run.apply({"type": "up", "id": "u01"})
	assert_eq(run.weapon("u01")["cd"], float(cfg["weapons"]["u01"]["cd"][1]))
	run.apply({"type": "magnet", "id": ""})
	assert_gt(run.magnet(), float(cfg["magnet"]))


func test_each_unit_has_its_own_weapon() -> void:
	var run := HuntRun.new({}, cfg)
	var types := {}
	for u in range(1, 13):
		var id := run.weapon_of(u)
		assert_ne(id, "", "유닛 %d의 무기" % u)
		types[cfg["weapons"][id]["type"]] = true
	assert_eq(types.size(), 12, "유닛마다 다른 공격")
	run.set_units([5, 10, 6])
	assert_eq(run.d["weapons"].keys(), ["u05", "u10", "u06"], "데리고 다니는 유닛의 무기만")
	run.apply({"type": "up", "id": "u05"})
	run.set_units([5, 1])
	assert_eq(int(run.d["weapons"]["u05"]), 1, "남은 무기의 강화는 그대로")
	run.reset()
	assert_eq(run.d["weapons"], {"u05": 0, "u01": 0}, "마을을 나서면 0단계에서")


func test_drops_sometimes_include_a_word() -> void:
	var run := HuntRun.new({}, cfg)
	var words := 0
	for k in 2000:
		if run.drops("chase", ["abc"], rng)["word"] != "":
			words += 1
	assert_between(words, 40, 180, "단어는 가끔(5%쯤)")


## 사용자 의견: 마을에서는 코인·단어만 내 것이 되고 사냥 레벨·구슬은 그대로. 퀴즈를 틀려 전투로 가면 레벨·구슬을, 지면 코인·단어도 잃는다.
func test_bank_keeps_level_and_orbs_and_losses() -> void:
	var s := GameState.new()
	var run := HuntRun.new(s.hunt, cfg)
	run.pick_orbs(10)
	run.pick_coins(8)
	run.pick_word("information")
	run.d["level"] = 3
	assert_eq(s.hunt["bag"]["coins"], 8, "상태에 남는다(저장·화면 전환)")
	var exp0 := s.unit_exp[0]
	var got := run.bank(s, GameData.rules)
	assert_eq(int(got["coins"]), 8)
	assert_eq(s.wallet, 8, "마을에서 코인이 지갑으로")
	assert_true(s.has_word("information"), "단어가 도감으로")
	assert_gt(s.unit_exp[0], exp0, "새로 모은 구슬이 경험치로")
	assert_eq(run.level(), 3, "사냥 레벨은 그대로")
	assert_eq(int(run.bag()["orbs"]), 10, "구슬도 그대로")
	assert_eq(int(run.bag()["coins"]), 0)
	var exp1 := s.unit_exp[0]
	run.bank(s, GameData.rules)
	assert_eq(s.unit_exp[0], exp1, "같은 구슬로 두 번 경험치를 받지 않는다")
	# 퀴즈를 틀려 전투로: 레벨·구슬만 잃는다
	run.pick_coins(5)
	run.pick_word("format")
	run.lose_orbs()
	assert_eq(run.level(), 0)
	assert_eq(int(run.bag()["orbs"]), 0)
	assert_eq(int(run.bag()["coins"]), 5, "코인은 그대로")
	assert_eq(run.bag()["words"], ["format"], "단어도 그대로")
	# 전투에서 졌다: 코인·단어도 모두
	run.lose()
	assert_eq(int(run.bag()["coins"]), 0, "지면 코인을 모두 잃는다")
	assert_true((run.bag()["words"] as Array).is_empty(), "단어도 모두")
	assert_eq(GameState.from_dict(s.to_dict()).wallet, 8, "지갑은 저장된다")


## 사용자 의견: 동행을 바꾸면 빠진 동행의 레벨(무기 단계)을 새 동행이 이어받는다
func test_swap_units_hands_over_levels() -> void:
	var run := HuntRun.new({}, cfg)
	run.set_units([1, 5])
	run.d["weapons"][run.weapon_of(1)] = 3
	run.d["weapons"][run.weapon_of(5)] = 2
	assert_eq(run.swap_units([1, 10]), {10: 2}, "하나를 바꾸면 그 동행의 레벨")
	assert_eq(int(run.d["weapons"][run.weapon_of(1)]), 3, "남은 동행은 그대로")
	run.d["weapons"][run.weapon_of(10)] = 4
	var two := run.swap_units([5, 2])  # 1(3)과 10(4)을 둘 다 바꾸면 평균 3(버림)
	assert_eq(two, {5: 3, 2: 3}, "둘을 바꾸면 평균(버림)을 각각")
	var one := run.swap_units([10])  # 5(3), 2(3) → 하나
	assert_eq(one, {10: 3}, "둘을 하나로 바꾸면 합이 아니라 평균")
	assert_eq(run.swap_units([1, 5]), {1: 3, 5: 3}, "하나를 둘로 바꾸면 그 레벨을 각각")
	assert_eq(run.swap_units([1, 5, 10]), {10: 0}, "빠진 동행 없이 늘면 0")


func test_eater_comes_after_time_and_cannot_be_killed() -> void:
	var run := HuntRun.new({}, cfg)
	var e: Dictionary = cfg["eater"]
	assert_false(run.tick(float(e["after_sec"]) - 1.0))
	assert_true(run.tick(2.0), "시간이 되면 뿌리먹이")
	assert_false(run.tick(1.0))
	assert_true(run.tick(float(e["again_sec"])), "그 뒤 또")
	var m := FieldMob.new()
	m.kind = "eater"
	m.hp = 5
	assert_false(m.take_hit(100), "뿌리먹이는 쓰러지지 않는다")
	assert_eq(m.hp, 1)
	var run2 := HuntRun.new({}, cfg)
	run2.d["level"] = int(cfg["max_level"])
	assert_true(run2.tick(0.1), "최대 레벨이면 바로 나온다")


func test_mobs_never_die_in_one_hit_and_grow_with_level() -> void:
	var run := HuntRun.new({}, cfg)
	assert_eq(run.mob_hp("flee"), maxi(2, roundi(int(cfg["mob_hp"]["flee"]) * float(cfg["mob_hp_party"][0]))), "레벨 0, 혼자: 기본 체력 × 혼자 배율")
	assert_gt(run.mob_hp("flee"), run.best_dmg(), "망치 한 방에는 안 죽는다")
	assert_eq(run.mob_count(18), 18)
	run.d["level"] = 20
	run.d["weapons"] = {"u01": 4, "u10": 4, "u12": 4}
	for kind in ["wander", "chase", "flee"]:
		assert_gt(run.mob_hp(kind), run.best_dmg(), "레벨 20, 다 강화해도 한 방에 안 죽는다: " + kind)
	var lv0 := HuntRun.new({}, cfg)
	lv0.set_units([1, 10, 12])
	assert_gt(run.mob_hp("wander"), lv0.mob_hp("wander"), "레벨이 오르면 단단해진다")
	assert_eq(run.mob_count(18), 38, "레벨이 오르면 몹이 많아진다")
	run.d["level"] = 40
	assert_eq(run.mob_count(18), int(cfg["spawn_max"]), "최대까지만")


func test_level_and_coin_caps() -> void:
	var run := HuntRun.new({}, cfg)
	run.d["level"] = int(cfg["max_level"])
	assert_true(run.max_level())
	assert_false(run.pick_orbs(1000), "MAX에서는 더 오르지 않는다")
	assert_eq(run.level(), int(cfg["max_level"]))
	var cap := run.coin_cap()
	assert_false(run.pick_coins(cap - 1))
	assert_true(run.pick_coins(5), "이번에 가득 찼다")
	assert_eq(int(run.bag()["coins"]), cap, "상한 넘게는 모이지 않는다")
	assert_false(run.pick_coins(3), "이미 가득")
	for k in 50:
		assert_eq(int(run.drops("wander", [], rng)["coins"]), 0, "가득 차면 코인이 떨어지지 않는다")


func test_more_companions_make_mobs_tougher() -> void:
	var one := HuntRun.new({}, cfg)
	one.set_units([1])
	var three := HuntRun.new({}, cfg)
	three.set_units([1, 5, 10])
	assert_gt(three.mob_hp("chase"), one.mob_hp("chase"), "동행이 많으면 몹이 단단하다(막는 비율을 80%쯤으로)")


func test_free_pulls_every_five_levels() -> void:
	var s := GameState.new()
	var run := HuntRun.new(s.hunt, cfg)
	assert_eq(run.free_pulls_for(4), 0, "5를 넘지 않으면 없다")
	assert_eq(run.free_pulls_for(5), 1)
	assert_eq(run.free_pulls_for(12), 2)
	run.d["level"] = 11
	var got := run.bank(s, GameData.rules)
	assert_eq(int(got["free_pulls"]), 2)
	assert_eq(s.free_pulls, 2, "마을에 들어오면 무료 뽑기를 받는다")
	assert_eq(int(run.bank(s, GameData.rules)["free_pulls"]), 0, "레벨이 그대로면 또 받지 않는다")
	run.d["level"] = 15
	assert_eq(int(run.bank(s, GameData.rules)["free_pulls"]), 1, "새로 오른 만큼만")
	s.free_pulls = 2
	var g := Gacha.new(GameData.repo, GameData.rules, JsonFile.read("res://data/balance/gacha.json"))
	var w0 := s.wallet
	assert_eq(g.pull_free(s, 2, GameData.rng).size(), 2)
	assert_eq(s.free_pulls, 0)
	assert_eq(s.wallet, w0, "코인이 들지 않는다")
	assert_true(g.pull_free(s, 1, GameData.rng).is_empty(), "무료가 없으면 못 뽑는다")
