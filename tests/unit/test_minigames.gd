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
	var right := g.belt.find(ans)
	assert_gt(right, -1, "답 카드는 늘 벨트에 있다")
	assert_true(g.pick(right))
	assert_eq(g.earned, [ans] as Array[String])
	var wrong := -1
	for i in g.belt.size():
		if g.belt[i] != g.current_word():
			wrong = i
	g.pick(wrong)
	assert_eq(g.misses, 1)


func test_order_timeout_is_a_miss() -> void:
	var g := _make(OrderGame, "order") as OrderGame
	g.update(float(cfg["order"]["order_time"]) + 0.1)
	assert_eq(g.misses, 1)
	assert_eq(g.current, 1)


func test_trap_numbers_and_rules() -> void:
	var g := _make(TrapGame, "trap") as TrapGame
	g.place_at([Vector2i(0, 0), Vector2i(0, 2)] as Array[Vector2i])
	assert_eq(g.number(Vector2i(0, 1)), 2)
	g.trap(Vector2i(0, 0))
	assert_eq(g.score(), 1)
	assert_false(g.finished)
	g.trap(Vector2i(5, 5))
	assert_true(g.finished, "빈 칸에 덫을 놓으면 끝")


func test_trap_first_reveal_is_safe_and_reveal_word_loses() -> void:
	var g := _make(TrapGame, "trap") as TrapGame
	g.reveal(Vector2i(3, 3))
	assert_false(g.finished)
	assert_true(g.revealed.has(Vector2i(3, 3)))
	var w: Vector2i = g.hidden.keys()[0]
	g.reveal(w)
	assert_true(g.lost)


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
