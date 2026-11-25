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
	assert_eq(ids, ["s01_q_word", "s01_q_root", "s01_q_magic", "s01_q_hammer"])


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
	assert_eq(book.shown(s, 1).map(func(q: Dictionary) -> String: return q["id"]), ["s01_q_word", "s01_q_hammer"], "알림판과 마을 아이(동굴)")
	assert_false(book.finish(s, "s01_q_root", ["fac"]), "보이지 않는 퀘스트는 못 마친다")
	s.flags["s01_q_word"] = true
	assert_eq(book.shown(s, 1).size(), 3, "알림판을 마치면 다리 퀘스트가 열린다")
	assert_true(book.finish(s, "s01_q_root", ["fac"]))
	assert_eq(book.shown(s, 1).size(), 4, "다리를 고치면 절벽 퀘스트가 열린다")


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
	assert_eq(book.next_quest(s, 1)["id"], "s01_q_hammer", "보스와 상관없는 마을 아이 퀘스트는 남는다")


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


func test_field_magic_cooldown_and_effects() -> void:
	var cfg: Dictionary = JsonFile.read("res://data/balance/field.json")["magic"]
	var fm := FieldMagicUse.new(cfg)
	var near := FieldMob.new()
	near.pos = Vector2(100, 0)
	var far := FieldMob.new()
	far.pos = Vector2(2000, 0)
	assert_true(fm.use("de", Vector2.ZERO, [near, far]))
	assert_gt(near.stun, 0.0, "de-: 가까운 몹이 멈춘다")
	assert_eq(far.stun, 0.0)
	assert_false(fm.use("de", Vector2.ZERO, [near]), "쉬는 동안은 못 쓴다")
	fm.tick(float(cfg["de"]["cd"]) + 0.1)
	assert_true(fm.ready("de"))
	var v := near.steer(Vector2.ZERO, 0.1, kinds, rng)
	assert_eq(v, Vector2.ZERO, "멈춘 몹은 움직이지 않는다")
	fm.use("ob", Vector2.ZERO, [near])
	assert_gt((near.get_meta("push") as Vector2).x, 0.0, "ob-: 바깥으로 밀친다")
	fm.use("sub", Vector2.ZERO, [])
	assert_gt(fm.sneak, 0.0, "sub-: 몰래 걷기")
	var ch := FieldMob.new()
	ch.kind = "chase"
	ch.ignore = true
	ch.steer(Vector2(100, 0), 0.016, kinds, rng)
	assert_false(ch.alert, "몰래 걷는 동안은 쫓지 않는다")


func test_loadout_slots() -> void:
	var s := GameState.new()
	s.magics = ["de", "sub", "re"] as Array[String]
	assert_eq(Loadout.field(s), ["de", "sub"] as Array[String], "처음엔 가진 것 앞에서부터")
	assert_true(Loadout.set_field(s, 0, "re"))
	assert_eq(Loadout.field(s), ["re", "sub"] as Array[String])
	assert_true(Loadout.set_field(s, 1, "re"), "다른 칸에 있으면 서로 바꾼다")
	assert_eq(Loadout.field(s), ["sub", "re"] as Array[String])
	assert_false(Loadout.set_field(s, 0, "ob"), "가진 것만")
	assert_eq(Loadout.deck(s, GameData.rules), ["", "", "", ""] as Array[String], "스테이지 1은 전투 마법 없음")
	s.stage = 2
	assert_eq(Loadout.deck(s, GameData.rules).filter(func(x: String) -> bool: return x != "").size(), 4)
	assert_true(Loadout.set_deck(s, GameData.rules, 3, ""))
	var rng2 := RandomNumberGenerator.new()
	for k in 10:
		var off := GameData.rules.magic_offer(s, ["fac"], rng2)
		assert_eq(off.size(), 3, "덱 3개 중 3개")
		for id in off:
			assert_true(id in Loadout.deck(s, GameData.rules), "덱에 있는 것만 나온다")
	var back := GameState.from_dict(s.to_dict())
	assert_eq(Loadout.field(back), ["sub", "re"] as Array[String], "저장된다")


func test_item_quest_needs_the_cave_item() -> void:
	var s := GameState.new()
	s.flags["s01_skit_cheok"] = true
	assert_false(book.finish(s, "s01_q_hammer", []), "망치가 없으면 못 마친다")
	s.items.append("toy_hammer")
	assert_true(book.finish(s, "s01_q_hammer", []))
	assert_eq(book.boss_blockers(s, 1).filter(func(q: Dictionary) -> bool: return q["id"] == "s01_q_hammer").size(), 0, "보스와는 상관없다")


func test_caves_on_the_map() -> void:
	var m := WorldMap.load_default()
	var kinds := m.caves.map(func(c: Dictionary) -> String: return c["kind"])
	kinds.sort()
	assert_eq(kinds, ["pass", "quest", "treasure"], "넘어가는·보물·퀘스트 동굴")
	var open := {"s01_q_root": true, "s01_q_magic": true}
	for it in m.items:
		var p := (Vector2(float(it["cell"][0]), float(it["cell"][1])) + Vector2(0.5, 0.5)) * m.tile
		assert_true(m.in_cave(p), "퀘스트 물건은 어두운 동굴 안")
		assert_gt(m.path_len(m.start(1), p, open), -1, "걸어갈 수 있다")
	var pc: Dictionary = m.caves.filter(func(c: Dictionary) -> bool: return c["kind"] == "pass")[0]
	var a := (Vector2(float(pc["mouths"][0][0]), float(pc["mouths"][0][1])) + Vector2(0.5, 0.5)) * m.tile
	var b := (Vector2(float(pc["mouths"][1][0]), float(pc["mouths"][1][1])) + Vector2(0.5, 0.5)) * m.tile
	assert_gt(m.path_len(a, b, open), -1, "넘어가는 동굴은 두 입구가 이어진다")
	assert_eq(m.nearest_mouth(a + Vector2(10, 10)), a, "ex-: 가장 가까운 입구로")
