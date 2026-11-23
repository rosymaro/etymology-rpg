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
		out.append(WordData.from_dict({"id": ids[i], "meaning": "뜻%d" % i, "attrs": [(i % 6) + 1], "tier": 1}))
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
	assert_eq(g.select(b, a), p["id"], "거꾸로 그어도 찾는다")
	assert_eq(g.score(), 1)
	assert_eq(g.read(Vector2i(0, 0), Vector2i(1, 2)), "", "직선이 아니면 안 읽는다")


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


func test_match3_swap_clears_and_fills_gauge() -> void:
	var g := _make(Match3Game, "fishing") as Match3Game
	var b := [
		[0, 0, 1, 0, 2, 3, 4], [1, 2, 3, 4, 0, 1, 2], [2, 3, 4, 0, 1, 2, 3], [3, 4, 0, 1, 2, 3, 4],
		[4, 0, 1, 2, 3, 4, 0], [0, 1, 2, 3, 4, 0, 1], [1, 2, 3, 4, 0, 1, 2]]
	g.set_board(b)
	assert_false(g.swap(Vector2i(1, 0), Vector2i(2, 0)), "줄이 안 생기면 되돌린다")
	assert_true(g.swap(Vector2i(0, 2), Vector2i(0, 3)))
	assert_gte(g.last_cleared, 3)
	assert_eq(g.moves_left, int(cfg["fishing"]["moves"]) - 1)


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


func test_cryptex_one_offset_solves_all_gates() -> void:
	var g := _make(CryptexGame, "wheel") as CryptexGame
	assert_false(g.solved())
	var hits := 0
	for k in g.n:
		g.inner_rot = k
		if g.solved():
			hits += 1
	assert_eq(hits, 1, "맞는 자리는 하나뿐")


func test_sort_is_scrambled_and_solvable_moves_follow_rules() -> void:
	var g := _make(SortGame, "guard") as SortGame
	assert_false(g.all_sorted())
	var total := 0
	for t in g.tubes:
		total += t.size()
	assert_eq(total, g.colors * g.per_tube)
	# 맨 위가 다른 무늬인 통으로는 못 옮긴다
	for a in g.tubes.size():
		for b in g.tubes.size():
			if a != b and not g.tubes[a].is_empty() and not g.tubes[b].is_empty() and g.tubes[b].size() < g.per_tube \
					and g.tubes[a][-1] != g.tubes[b][-1]:
				assert_false(g.can_move(a, b))
				return


func test_ore_combo_of_five_earns_and_rock_breaks_combo() -> void:
	var g := _make(OreSlashGame, "ore") as OreSlashGame
	for i in 5:
		g.spawn(true, Vector2(100 + i * 100, 300), Vector2(0, -1))
	g.slash(Vector2(50, 300), Vector2(700, 300))
	assert_eq(g.score(), 1)
	g.spawn(false, Vector2(300, 500), Vector2(0, -1))
	g.slash(Vector2(250, 500), Vector2(350, 500))
	assert_eq(g.combo, 0)


func test_flow_board_has_solution_and_solving_earns_all() -> void:
	var g := _make(FlowGame, "pattern") as FlowGame
	var cells := 0
	for seg in g.solution:
		cells += seg.size()
		assert_gte(seg.size(), int(cfg["pattern"]["min_len"]))
	assert_eq(cells, g.size * g.size)
	for k in g.pairs:
		var seg: Array = g.solution[k]
		assert_true(g.begin(seg[0]))
		for i in range(1, seg.size()):
			assert_true(g.extend(seg[i]))
		g.end_stroke()
	assert_true(g.finished)
	assert_eq(g.score(), g.pairs)


func test_flow_lines_cannot_cross() -> void:
	var g := _make(FlowGame, "pattern") as FlowGame
	var s0: Array = g.solution[0]
	var s1: Array = g.solution[1]
	g.begin(s0[0])
	for i in range(1, s0.size()):
		g.extend(s0[i])
	g.end_stroke()
	g.begin(s1[0])
	# s1의 첫 칸 이웃 중 s0이 지난 칸이 있으면 들어갈 수 없다
	for c in s0:
		if absi(c.x - s1[0].x) + absi(c.y - s1[0].y) == 1:
			assert_false(g.extend(c))
			return
	pass_test("이웃에 다른 선이 없다")
