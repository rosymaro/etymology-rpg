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
	assert_true(run.d["weapons"].has("hammer"), "처음 무기는 망치")
	var need := run.need()
	assert_false(run.pick_orbs(need - 1))
	assert_true(run.pick_orbs(1), "구슬이 차면 레벨업")
	assert_eq(run.level(), 1)
	assert_eq(int(run.bag()["orbs"]), need, "구슬은 주머니에도 담긴다")


func test_level_up_choices_offer_owned_skills() -> void:
	var run := HuntRun.new({}, cfg)
	var seen := {}
	for k in 30:
		for c in run.choices(["hammer", "spin"], rng):
			seen[c["type"] + ":" + c["id"]] = true
	assert_true(seen.has("new:spin"), "가진 어원 스킬이 새 무기로 나온다")
	assert_true(seen.has("up:hammer"), "쓰는 무기 강화")
	assert_false(seen.has("new:shout"), "안 가진 스킬은 안 나온다")
	run.apply({"type": "up", "id": "hammer"})
	assert_eq(run.weapon("hammer")["cd"], float(cfg["weapons"]["hammer"]["cd"][1]))
	run.apply({"type": "magnet", "id": ""})
	assert_gt(run.magnet(), float(cfg["magnet"]))


func test_drops_sometimes_include_a_word() -> void:
	var run := HuntRun.new({}, cfg)
	var words := 0
	for k in 2000:
		if run.drops("chase", ["abc"], rng)["word"] != "":
			words += 1
	assert_between(words, 40, 180, "단어는 가끔(5%쯤)")


func test_bank_in_town_and_lose_half_when_beaten() -> void:
	var s := GameState.new()
	var run := HuntRun.new(s.hunt, cfg)
	run.pick_orbs(10)
	run.pick_coins(8)
	run.pick_word("information")
	assert_eq(s.hunt["bag"]["coins"], 8, "상태에 남는다(저장·화면 전환)")
	run.lose()
	assert_eq(int(run.bag()["coins"]), 4, "지면 절반을 잃는다")
	assert_eq(int(run.bag()["orbs"]), 5)
	assert_eq(run.level(), 0, "나들이는 끝")
	run.pick_word("format")
	var exp0 := s.unit_exp[0]
	var got := run.bank(s, GameData.rules)
	assert_eq(int(got["coins"]), 4)
	assert_eq(s.wallet, 4, "마을에서 코인이 지갑으로")
	assert_gt(s.unit_exp[0], exp0, "구슬이 경험치로")
	assert_true(s.has_word("format"), "단어가 도감으로")
	assert_eq(int(run.bag()["orbs"]), 0, "주머니는 비었다")
	assert_eq(GameState.from_dict(s.to_dict()).wallet, 4, "지갑은 저장된다")


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
