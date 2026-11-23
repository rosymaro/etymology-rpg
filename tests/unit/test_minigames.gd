extends GutTest
## 미니게임 10개 규칙(01-rpg-base '미니게임 규칙 1차').

var cfg: Dictionary


func before_all() -> void:
	cfg = JsonFile.read("res://data/balance/minigames.json")


func _words(n: int) -> Array[WordData]:
	var ids := ["apple", "river", "stone", "candle", "forest", "music", "window", "garden", "planet", "silver",
		"bridge", "dream", "ocean", "pencil", "tiger"]
	var out: Array[WordData] = []
	for i in n:
		out.append(WordData.from_dict({"id": ids[i], "meaning": "뜻%d" % i, "attrs": [(i % 6) + 1], "tier": 1,
			"etym": [{"root": "r%d-" % i, "meaning": "앞%d" % i}, {"root": "x%d" % i, "meaning": "뒤%d" % i}]}))
	return out


func _make(script: GDScript, key: String, n: int = 12, seed: int = 5) -> Minigame:
	var g: Minigame = script.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	seed(seed)
	g.setup(_words(n), cfg[key], int(cfg["max_words"]), rng)
	return g


func test_order_right_card_earns_and_wrong_counts_miss() -> void:
	var g := _make(OrderGame, "order") as OrderGame
	var ans := g.current_word()
	var right := g.belt_ids().find(ans)
	assert_gt(right, -1, "답 카드는 늘 벨트에 있다")
	var before := g.items.size()
	assert_true(g.pick(right))
	assert_eq(g.earned, [ans] as Array[String])
	assert_eq(g.items.size(), before, "집은 자리에 새 카드가 들어온다")
	assert_ne(g.items[right]["id"], ans)
	var wrong := -1
	for i in g.items.size():
		if g.items[i]["id"] != g.current_word():
			wrong = i
	g.pick(wrong)
	assert_eq(g.misses, 1)


func test_order_cards_flow_left_to_right_and_answer_stays_on_belt() -> void:
	var g := _make(OrderGame, "order") as OrderGame
	var x0: float = g.items[0]["x"]
	g.update(0.5)
	assert_gt(g.items[0]["x"], x0, "카드는 오른쪽으로 흐른다")
	for k in 60:
		g.update(0.25)
		if g.finished:
			break
		assert_true(g.current_word() in g.belt_ids())
		var ids := g.belt_ids()
		var uniq := {}
		for id in ids:
			uniq[id] = true
		assert_eq(uniq.size(), ids.size(), "같은 카드가 두 장 올라오지 않는다")


func test_order_timeout_is_a_miss() -> void:
	var g := _make(OrderGame, "order") as OrderGame
	g.update(float(cfg["order"]["order_time"]) + 0.1)
	assert_eq(g.misses, 1)
	assert_eq(g.current, 1)


func test_trap_memory_pairs_word_with_its_meaning() -> void:
	var g := _make(MemoryGame, "trap") as MemoryGame
	assert_eq(g.cards.size(), int(cfg["trap"]["pairs"]) * 2)
	# 짝이 아닌 두 장 → 틀림, 덮인다
	var a := 0
	var b := -1
	for k in range(1, g.cards.size()):
		if g.cards[k]["w"] != g.cards[a]["w"]:
			b = k
			break
	assert_eq(g.flip(a), "open")
	assert_eq(g.flip(b), "miss")
	g.close_mismatch()
	assert_false(g.cards[a]["open"])
	# 짝인 두 장 → 걸림
	var mate := -1
	for k in g.cards.size():
		if k != a and g.cards[k]["w"] == g.cards[a]["w"]:
			mate = k
	g.flip(a)
	assert_eq(g.flip(mate), "match")
	assert_eq(g.score(), 1)
	assert_ne(g.cards[a]["side"], g.cards[mate]["side"], "한 장은 단어, 한 장은 뜻")


func test_trap_memory_finishes_when_all_pairs_found() -> void:
	var g := _make(MemoryGame, "trap") as MemoryGame
	var by := {}
	for k in g.cards.size():
		by.get_or_add(g.cards[k]["w"], []).append(k)
	for w in by:
		g.flip(by[w][0])
		g.flip(by[w][1])
	assert_true(g.finished)
	assert_eq(g.score(), mini(g.pairs(), int(cfg["max_words"])))


func test_search_removes_one_unused_letter_every_ten_seconds() -> void:
	var g := _make(WordSearchGame, "search") as WordSearchGame
	var answer := g.answer_cells()
	g.update(9.9)
	assert_eq(g.removed.size(), 0)
	g.update(0.2)
	assert_eq(g.removed.size(), 1, "10초에 하나")
	g.update(10.0)
	assert_eq(g.removed.size(), 2)
	for p in g.removed:
		assert_false(answer.has(p), "정답 글자는 지우지 않는다")


func test_word_search_hidden_words_are_readable() -> void:
	var g := _make(WordSearchGame, "search") as WordSearchGame
	assert_gt(g.placed.size(), 2)
	var p: Dictionary = g.placed[0]
	var a: Vector2i = p["start"]
	var b: Vector2i = a + p["dir"] * (p["len"] - 1)
	assert_true(p["dir"] in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)], "오른쪽·아래·오른쪽 아래로만 숨긴다")
	assert_eq(g.select(b, a), p["id"], "거꾸로 그어도 찾는다")
	assert_eq(g.score(), 1)
	assert_eq(g.read(Vector2i(0, 0), Vector2i(1, 2)), "", "직선이 아니면 안 읽는다")


func test_pipe_paths_are_long_for_many_seeds() -> void:
	for sd in range(1, 30):
		var g := _make(PipeGame, "kite", 12, sd) as PipeGame
		assert_gte(g.solution.size(), int(cfg["kite"]["min_path"]))


func test_pipe_solution_connects_when_rotated_back() -> void:
	var g := _make(PipeGame, "kite") as PipeGame
	assert_false(g._reaches_end(), "처음에는 안 이어져 있다")
	# 정답 길의 칸마다, 이어질 때까지 돌려 본다(최대 4번)
	for i in g.solution.size():
		var p: Vector2i = g.solution[i]
		var prev: Vector2i = Vector2i(p.x, p.y - 1) if i == 0 else g.solution[i - 1]
		var next: Vector2i = Vector2i(p.x, p.y + 1) if i == g.solution.size() - 1 else g.solution[i + 1]
		var want: int = g._dir(p, prev) | g._dir(p, next)
		for t in 4:
			if (g.tiles[p.x][p.y] & want) == want:
				break
			g.rotate(p)
	assert_true(g._reaches_end())
	assert_gte(g.solution.size(), int(cfg["kite"]["min_path"]), "정답 길은 10칸 이상")
	assert_eq(g.word_at_cell.size(), 8, "정답 5 + 함정 3")
	var path: Array[Vector2i] = g.solution.duplicate()
	assert_eq(g.judge(path), "ok", "정답 길은 정답을 모두 지나고 함정을 지나지 않는다")
	for c in g.word_at_cell:
		if g.is_decoy(c):
			path.append(c)
			break
	assert_eq(g.judge(path), "trap", "함정이 섞이면 오답")
	var partial: Array[Vector2i] = [g.solution[0]]
	assert_eq(g.judge(partial), "missing")


func test_anagram_right_spelling_earns() -> void:
	var g := _make(AnagramGame, "copy") as AnagramGame
	var w := g.current().id
	var order: Array[int] = []
	var left := g.tiles.duplicate()
	for ch in w:
		var i := left.find(ch)
		order.append(i)
		left[i] = "*"
	var res := ""
	for i in order:
		res = g.pick(i)
	assert_eq(res, "right")
	assert_eq(g.earned, [w] as Array[String])


func test_cryptex_turning_alone_never_scores() -> void:
	var g := _make(CryptexGame, "wheel") as CryptexGame
	for k in g.n * 2:
		g.turn_inner(1)
	assert_eq(g.score(), 0, "돌리기만 해서는 맞지 않는다. 수문을 열어야 한다")


func test_cryptex_open_gates_tries_then_reveals() -> void:
	var g := _make(CryptexGame, "wheel") as CryptexGame
	assert_eq(g.open_gates(), "wrong")
	assert_eq(g.open_gates(), "lost", "두 번 틀리면 답을 보여 준다")
	assert_true(g.revealed and g.solved())
	g.next_round()
	assert_eq(g.rounds_done, 1)
	assert_eq(g.score(), 0)
	for k in g.n:
		g.inner_rot = k
		if g.solved():
			break
	assert_eq(g.open_gates(), "right")
	assert_eq(g.score(), 1)


func test_cryptex_one_offset_solves_all_gates() -> void:
	var g := _make(CryptexGame, "wheel") as CryptexGame
	assert_false(g.solved())
	var hits := 0
	for k in g.n:
		g.inner_rot = k
		if g.solved():
			hits += 1
	assert_eq(hits, 1, "맞는 자리는 하나뿐")


func test_ore_combo_of_five_earns_and_rock_breaks_combo() -> void:
	var g := _make(OreSlashGame, "ore") as OreSlashGame
	for i in 5:
		g.spawn(true, Vector2(100 + i * 100, 300), Vector2(0, -1))
	g.slash(Vector2(50, 300), Vector2(700, 300))
	assert_eq(g.score(), 1)
	g.spawn(false, Vector2(300, 500), Vector2(0, -1))
	g.slash(Vector2(250, 500), Vector2(350, 500))
	assert_eq(g.combo, 0)


func _fight(g: FishingGame, follow: bool) -> void:
	## follow = 막대가 물고기를 따라가도록 누른다(잘 싸움). false면 손을 뗀다.
	for _i in 4000:
		if g.state != "fight":
			return
		g.hold(follow and g.bar_pos + g.bar_size() / 2.0 < g.fish_pos)
		g.update(0.02)


func test_fishing_bait_gathers_constant_school_and_match_is_easier() -> void:
	var g := _make(FishingGame, "fishing") as FishingGame
	var n := int(cfg["fishing"]["fish"])
	var right := -1
	for i in g.fish.size():
		if g.is_match(g.fish[i]["w"]):
			right = i
	assert_gt(right, -1, "미끼와 뜻이 맞는 물고기가 있다")
	assert_eq(g.fish.size(), n)
	var w: WordData = g.words[g.fish[right]["w"]]
	assert_true(g.hook(right))
	assert_eq(g.state, "fight")
	var easy := g.bar_size()
	var easy_speed := g.fish_speed()
	_fight(g, true)
	assert_eq(g.earned, [w.id] as Array[String], "잘 싸우면 낚는다")
	assert_eq(g.fish.size(), n, "다음 판에도 물고기 수가 그대로다")
	var wrong := -1
	for i in g.fish.size():
		if not g.is_match(g.fish[i]["w"]):
			wrong = i
	g.hook(wrong)
	assert_lt(g.bar_size(), easy, "뜻이 안 맞으면 막대가 작다")
	assert_gt(g.fish_speed(), easy_speed, "뜻이 안 맞으면 물고기가 빠르다")
	_fight(g, false)
	assert_eq(g.misses, 1, "손을 놓으면 놓친다")
	assert_eq(g.fish.size(), n)


func test_fishing_mismatch_fish_can_still_be_caught() -> void:
	var g := _make(FishingGame, "fishing", 12, 9) as FishingGame
	var caught := 0
	for _r in 3:
		var wrong := -1
		for i in g.fish.size():
			if not g.is_match(g.fish[i]["w"]):
				wrong = i
		g.hook(wrong)
		_fight(g, true)
		caught = g.score()
	assert_gt(caught, 0, "뜻이 다른 물고기도 잘 싸우면 낚인다")


func test_guard_pass_true_block_false_and_climbers() -> void:
	var g := _make(GuardGame, "guard") as GuardGame
	g.walkers.clear()
	# 맞는 짝: 비켜서 통과시키면 얻는다
	g.spawn_gate_word()
	var w: Dictionary = g.walkers[0]
	w["true"] = true
	w["shown"] = g.words[w["w"]].meaning
	g.unit_x = 0.0
	g.move_to(0.0)
	w["y"] = 0.999
	w["x"] = g.gate_x
	g.update(0.01)
	assert_eq(g.score(), 1, "맞는 짝을 통과시켰다")
	# 틀린 짝: 막으면 맞다
	g.spawn_gate_word()
	w = g.walkers[-1]
	w["true"] = false
	g.unit_x = g.gate_x
	g.move_to(g.gate_x)
	w["y"] = 0.999
	w["x"] = g.gate_x
	g.update(0.01)
	assert_eq(g.misses, 0, "틀린 짝을 막았다")
	# 맞는 짝을 막으면 실수
	g.spawn_gate_word()
	w = g.walkers[-1]
	w["true"] = true
	w["y"] = 0.999
	w["x"] = g.gate_x
	g.update(0.01)
	assert_eq(g.misses, 1)
	# 담 넘는 단어: 막으면 괜찮고, 놓치면 실수
	g.spawn_climber()
	var c: Dictionary = g.walkers[-1]
	g.unit_x = c["x"]
	g.move_to(c["x"])
	c["y"] = 0.999
	g.update(0.01)
	assert_eq(g.misses, 1, "담 넘는 단어를 막았다")
	g.spawn_climber()
	c = g.walkers[-1]
	c["x"] = fposmod(g.unit_x + 0.5, 1.0)
	c["y"] = 0.999
	g.update(0.01)
	assert_eq(g.misses, 2, "담 넘는 단어를 놓쳤다")


func test_guard_unit_moves_toward_finger_and_words_keep_coming() -> void:
	var g := _make(GuardGame, "guard") as GuardGame
	g.move_to(1.0)
	g.update(0.5)
	assert_almost_eq(g.unit_x, 0.5 + float(cfg["guard"]["unit_speed"]) * 0.5, 0.001)
	var seen_climb := false
	var seen_gate := false
	for _i in 300:
		g.update(0.05)
		for w in g.walkers:
			seen_climb = seen_climb or w["kind"] == "climb"
			seen_gate = seen_gate or w["kind"] == "gate"
	assert_true(seen_gate and seen_climb, "손님과 담 넘는 단어가 모두 온다")
	for w in g.walkers:
		if w["kind"] == "gate" and not w["true"]:
			assert_ne(w["shown"], g.words[w["w"]].meaning)


func test_root_link_word_to_its_etymology() -> void:
	var g := _make(RootLinkGame, "pattern") as RootLinkGame
	assert_eq(g.left.size(), int(cfg["pattern"]["pairs"]))
	var a := 0
	var right_b := g.right.find(g.left[a])
	var wrong_b := (right_b + 1) % g.right.size()
	assert_false(g.link(a, wrong_b))
	assert_eq(g.misses, 1)
	assert_true(g.link(a, right_b))
	assert_eq(g.score(), 1)
	assert_string_contains(RootLinkGame.etym_text(g.words[g.left[a]]), " + ")
	for i in g.left.size():
		g.link(i, g.right.find(g.left[i]))
	assert_true(g.finished)
