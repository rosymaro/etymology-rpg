extends GutTest
## 퀘스트(QuestBook)와 필드 몹 움직임(FieldMob).

var book: QuestBook
var kinds: Dictionary
var rng := RandomNumberGenerator.new()


func before_each() -> void:
	book = QuestBook.load_default()
	kinds = JsonFile.read("res://data/balance/field.json")["kinds"]
	rng.seed = 7


func test_stage1_has_word_root_and_magic_quests() -> void:
	var ids := book.of_stage(1).map(func(q: Dictionary) -> String: return q["id"])
	assert_eq(ids, ["s01_q_word", "s01_q_root", "s01_q_magic"])


func test_quest_gates_match_the_map() -> void:
	var m := WorldMap.load_default()
	for q in book.quests:
		if q.has("gate"):
			assert_false(m.quest_gate(q["gate"]).is_empty(), "지도에 길목 %s" % q["gate"])


func test_quests_open_one_by_one_with_the_story() -> void:
	var s := GameState.new()
	assert_eq(book.shown(s, 1).size(), 0, "이야기 전에는 퀘스트가 없다")
	assert_true(book.next_quest(s, 1).is_empty())
	s.flags["s01_skit_cheok"] = true
	assert_eq(book.shown(s, 1).map(func(q: Dictionary) -> String: return q["id"]), ["s01_q_word"])
	assert_false(book.finish(s, "s01_q_root", ["fac"]), "보이지 않는 퀘스트는 못 마친다")
	s.flags["s01_q_word"] = true
	assert_eq(book.shown(s, 1).size(), 2, "알림판을 마치면 다리 퀘스트가 열린다")
	assert_true(book.finish(s, "s01_q_root", ["fac"]))
	assert_eq(book.shown(s, 1).size(), 3, "다리를 고치면 절벽 퀘스트가 열린다")


func test_word_quest_needs_all_three_words() -> void:
	var s := GameState.new()
	s.flags["s01_skit_cheok"] = true
	var q := book.get_quest("s01_q_word")
	assert_eq(book.progress(s, q, [])["have"], 0)
	s.dex["information"] = 1
	s.dex["inform"] = 2
	assert_false(book.finish(s, "s01_q_word", []), "두 개로는 못 마친다")
	s.dex["format"] = 3
	assert_true(book.finish(s, "s01_q_word", []))
	assert_true(book.done(s, "s01_q_word"))
	assert_false(book.finish(s, "s01_q_word", []), "두 번 마치지 않는다")


func test_root_and_magic_quests_open_their_gates() -> void:
	var s := GameState.new()
	s.flags["s01_q_word"] = true
	s.magics = []
	assert_false(book.finish(s, "s01_q_root", []), "fac 없으면 다리를 못 고친다")
	assert_true(book.finish(s, "s01_q_root", ["fac"]))
	assert_false(book.finish(s, "s01_q_magic", ["fac"]), "de 없으면 절벽을 못 내려간다")
	s.magics = ["de"]
	assert_true(book.finish(s, "s01_q_magic", []))
	assert_eq(book.open_gates(s), {"s01_q_root": true, "s01_q_magic": true})


func test_boss_waits_for_all_stage_quests() -> void:
	var s := GameState.new()
	s.flags["s01_skit_cheok"] = true
	assert_eq(book.boss_blockers(s, 1).size(), 3)
	assert_eq(book.next_quest(s, 1)["id"], "s01_q_word")
	for id in ["s01_q_word", "s01_q_root", "s01_q_magic"]:
		s.flags[id] = true
	assert_eq(book.boss_blockers(s, 1).size(), 0)
	assert_true(book.next_quest(s, 1).is_empty())


func test_chaser_follows_and_gives_up() -> void:
	var m := FieldMob.new()
	m.kind = "chase"
	var v := m.steer(Vector2(300, 0), 0.016, kinds, rng)
	assert_true(m.alert)
	assert_gt(v.x, 0.0, "주인공 쪽으로")
	assert_lt(v.length(), float(JsonFile.read("res://data/balance/field.json")["hero_speed"]), "주인공보다 느리다")
	m.steer(Vector2(800, 0), 0.016, kinds, rng)
	assert_true(m.alert, "give_up 전까지는 계속 쫓는다")
	m.steer(Vector2(2000, 0), 0.016, kinds, rng)
	assert_false(m.alert, "멀어지면 그만 쫓는다")


func test_fleer_runs_away_and_wanderer_ignores_hero() -> void:
	var f := FieldMob.new()
	f.kind = "flee"
	var v := f.steer(Vector2(200, 0), 0.016, kinds, rng)
	assert_lt(v.x, 0.0, "주인공 반대쪽으로")
	var w := FieldMob.new()
	w.kind = "wander"
	w.steer(Vector2(50, 0), 0.016, kinds, rng)
	assert_false(w.alert)
	assert_lte(w.vel.length(), float(kinds["wander"]["speed"][1]) + 0.01)


func test_kinds_are_mixed() -> void:
	var seen := {}
	for i in 200:
		seen[FieldMob.pick_kind(kinds, rng)] = true
	assert_eq(seen.size(), 3)


func test_rest_after_losing_lasts_three_minutes_of_real_time() -> void:
	var s := GameState.new()
	var sec := int(JsonFile.read("res://data/balance/field.json")["rest_sec"])
	assert_eq(sec, 180)
	GameData.rules.start_rest(s, 1000, sec)
	assert_eq(GameData.rules.rest_left(s, 1000), 180)
	assert_eq(GameData.rules.rest_left(s, 1100), 80, "앱을 꺼 두어도 진짜 시계로 흐른다")
	assert_eq(GameData.rules.rest_left(s, 2000), 0)
	var back := GameState.from_dict(s.to_dict())
	assert_eq(back.rest_until, 1180, "저장된다")


func test_big_town_has_facilities_and_a_hospital() -> void:
	var m := WorldMap.load_default()
	var town: Array = m.region(1)["town"]
	assert_eq([int(town[2]), int(town[3])], [30, 20], "마을은 30 × 20")
	var s := m.start(1)
	for id in ["forge", "board", "hospital", "tree", "notice"]:
		var p := m.spot(1, id)
		assert_true(m.is_town(p), "%s는 마을 안" % id)
		assert_gt(m.path_len(s, p), -1, "%s까지 걸어간다" % id)
	var ids: Array = m.region(1)["buildings"].map(func(b: Dictionary) -> String: return b["id"])
	assert_true("hospital" in ids)
