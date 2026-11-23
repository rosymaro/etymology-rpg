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


func _frag_uid(g: OrderGame, w: int, p: int) -> int:
	for it in g.items:
		if it["w"] == w and it["piece"] == p:
			it["d"] = 0.3  # 위 변(보이는 곳)으로 옮긴다
			return it["uid"]
	return -1


func _craft(g: OrderGame, w: int, pieces: Array) -> void:
	for p in pieces:
		assert_true(g.pick(_frag_uid(g, w, p)), "보이는 조각을 집는다")
		g.action = {"kind": "furnace"}
		g.act()
	g.action = {"kind": "hammer"}
	g.act()


func test_order_fragments_hammered_into_word_then_shelved() -> void:
	var g := _make(OrderGame, "order") as OrderGame
	assert_eq(g.shelf.size(), int(cfg["order"]["shelf"]))
	var w: int = g.shelf[0]
	var n := g.pieces(w)
	assert_between(n, 2, 3, "단어는 2~3조각으로 깨져 있다")
	var joined := ""
	for p in n:
		joined += g.piece_text(w, p)
	assert_eq(joined, g.words[w].id, "조각을 이으면 단어")
	for p in n:
		assert_gt(_frag_uid(g, w, p), -1, "주문 단어의 조각은 모두 벨트에 있다")
	_craft(g, w, range(n))
	assert_eq(g.carry.get("word", -1), w, "두드리면 완성 단어를 든다")
	var next := g.orders[0] if not g.orders.is_empty() else -1
	assert_true(g.place(0))
	assert_eq(g.earned, [g.words[w].id] as Array[String])
	assert_eq(g.shelf[0], next, "빈 진열장 칸에 다음 주문")


func test_order_incomplete_or_mixed_breaks_and_wrong_shelf_is_miss() -> void:
	var g := _make(OrderGame, "order") as OrderGame
	var w: int = g.shelf[0]
	_craft(g, w, [0])  # 한 조각만
	assert_true(g.carry.is_empty(), "조각이 모자라면 실패")
	assert_true(g.furnace.is_empty(), "실패하면 조각이 사라진다")
	for _s in 40:
		g.update(0.5)
	assert_gt(_frag_uid(g, w, 0), -1, "사라진 조각은 창고에서 다시 나온다")
	var w2: int = g.shelf[1]
	_craft(g, w2, range(g.pieces(w2)))
	assert_eq(g.carry.get("word", -1), w2)
	assert_false(g.place(0), "뜻이 다른 칸")
	assert_eq(g.misses, 1)


func test_order_fragments_never_overlap_over_a_long_game() -> void:
	var g := _make(OrderGame, "order") as OrderGame
	var gap := float(cfg["order"]["min_gap"])
	for step in 600:
		if step % 7 == 0 and not g.items.is_empty():  # 가끔 조각을 집어 가서 빈자리를 만든다
			var it: Dictionary = g.items[step % g.items.size()]
			it["d"] = 0.3
			g.carry = {}
			g.pick(it["uid"])
			g.carry = {}
		g.update(0.1)
		if g.finished:
			break
		for a in g.items.size():
			for b in range(a + 1, g.items.size()):
				var diff := absf(fposmod(g.items[a]["d"] - g.items[b]["d"] + g.perimeter() / 2.0, g.perimeter()) - g.perimeter() / 2.0)
				assert_gte(diff, gap - 0.001, "조각끼리 겹치지 않는다")
				if diff < gap - 0.001:
					return


func test_order_belt_loops_and_left_side_is_hidden() -> void:
	var g := _make(OrderGame, "order") as OrderGame
	var it: Dictionary = g.items[0]
	it["d"] = 0.0
	var d0: float = it["d"]
	g.update(0.5)
	assert_gt(it["d"], d0, "벨트가 돈다")
	it["d"] = g.perimeter() - 0.1  # 왼쪽 변
	assert_false(g.visible(it), "왼쪽은 창고 벽에 가려 보이지 않는다")
	assert_false(g.pick(it["uid"]), "안 보이는 조각은 집을 수 없다")
	it["d"] = 0.5
	assert_true(g.visible(it))
	g.update(g.perimeter() / float(cfg["order"]["belt_speed"]))
	assert_almost_eq(fposmod(it["d"], g.perimeter()), 0.5, 0.05, "한 바퀴 돌아 제자리")
	# 캐릭터가 걸어가서 집는다
	it["d"] = 0.4
	g.go_pick(it["uid"])
	for _s in 300:
		g.update(0.02)
		if g.action.is_empty():
			break
	assert_false(g.carry.is_empty(), "걸어가서 집었다")


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


func test_pipe_straight_tiles_have_direction() -> void:
	var g := _make(PipeGame, "kite") as PipeGame
	for p in g.solution:
		while g.turns[p] != 0:
			g.rotate(p)
	assert_true(g._reaches_end(), "정답 방향이면 이어진다")
	var straight := Vector2i(-1, -1)
	for p in g.solution:
		if g.is_straight(p):
			straight = p
			break
	assert_ne(straight, Vector2i(-1, -1), "정답 길에 일자 타일이 있다")
	g.rotate(straight)
	g.rotate(straight)
	assert_true(g.is_straight(straight))
	assert_false(g._reaches_end(), "일자 타일을 반 바퀴 돌리면 화살표가 거꾸로라 막힌다")


func test_pipe_paths_are_long_for_many_seeds() -> void:
	for sd in range(1, 40):
		var g := _make(PipeGame, "kite", 12, sd) as PipeGame
		assert_gte(g.solution.size(), int(cfg["kite"]["min_path"]))


func test_pipe_word_tiles_show_right_meaning_only_on_path_turn() -> void:
	var g := _make(PipeGame, "kite") as PipeGame
	assert_eq(g.rows, 7)
	assert_eq(g.word_at_cell.size(), int(cfg["kite"]["words"]), "함정 없이 정답 5개만")
	for c in g.word_at_cell:
		assert_true(c in g.solution, "단어는 모두 정답 길 위")
		assert_ne(g.shown_meaning(c), g.words[g.word_at_cell[c]].meaning, "처음엔 맞는 뜻이 안 보인다")
		var seen := {}
		for k in 4:
			seen[g.shown_meaning(c)] = true
			g.rotate(c)
		assert_eq(seen.size(), 4, "돌릴 때마다 뜻이 바뀐다(정답 1 + 오답 3)")
	# 정답 방향으로 되돌리면 맞는 뜻이 보이고 성공
	for p in g.solution:
		while g.turns[p] != 0:
			g.rotate(p)
	for c in g.word_at_cell:
		assert_eq(g.shown_meaning(c), g.words[g.word_at_cell[c]].meaning)
	assert_true(g._reaches_end())
	assert_eq(g.judge(g.connected()), "ok")
	var any: Vector2i = g.word_at_cell.keys()[0]
	g.rotate(any)
	g.rotate(any)
	assert_ne(g.judge(g.solution.duplicate()), "ok", "뜻이 틀린 방향이면 성공이 아니다")
	var partial: Array[Vector2i] = [g.solution[0]]
	assert_eq(g.judge(partial), "missing")
	for p in g.solution:
		while g.turns[p] != 3:
			g.rotate(p)
	g.turn(g.solution[0])  # 마지막으로 돌려서 모두 정답 방향(0)이 되면 성공
	for p in g.solution.slice(1):
		g.turn(p)
	assert_true(g.finished)
	assert_eq(g.score(), int(cfg["kite"]["words"]))


func test_ore_shows_two_roots_and_only_their_words_count() -> void:
	var ws: Array[WordData] = []
	var rows := [["transport", [["trans-", "가로질러"], ["portare", "나르다"]]], ["export", [["ex-", "밖"], ["portare", "나르다"]]],
		["inspect", [["in-", "안"], ["specere", "보다"]]], ["respect", [["re-", "다시"], ["specere", "보다"]]],
		["import", [["in-", "안"], ["portare", "나르다"]]], ["river", [["ripa", "강둑"]]], ["music", [["mousa", "뮤즈"]]]]
	for r in rows:
		var et := []
		for e in r[1]:
			et.append({"root": e[0], "meaning": e[1]})
		ws.append(WordData.from_dict({"id": r[0], "meaning": r[0] + "뜻", "attrs": [1], "tier": 1, "etym": et}))
	var g := OreSlashGame.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	g.setup(ws, cfg["ore"], 5, rng)
	assert_eq(g.roots.size(), 2, "어원 2개를 알려 준다")
	assert_eq(g.roots[0]["key"], "portare", "가장 많이 쓰인 어근부터")
	assert_eq(g.roots[1]["key"], "specere")
	assert_eq(g.targets.size(), 5)
	g.spawn(true, Vector2(300, 300), Vector2(0, -1))
	g.spawn(true, Vector2(500, 300), Vector2(0, -1))
	g.slash(Vector2(250, 300), Vector2(550, 300))
	assert_gt(g.score(), 0, "어원이 든 단어를 깨면 얻는다")
	g.spawn(false, Vector2(300, 500), Vector2(0, -1))
	g.slash(Vector2(250, 500), Vector2(350, 500))
	assert_eq(g.misses, 1, "다른 단어를 깨면 실수")
	assert_false(g.has_root(ws[5]))


func _hook(g: FishingGame, i: int) -> void:
	for f in g.fish:
		f["vel"] = Vector2.ZERO
	g.cast(g.fish[i]["pos"] + Vector2(0.01, 0))
	for _s in 400:
		if g.state == "bite" and g.ring <= float(g.cfg["hook_ring"]):
			break
		g.update(0.02)
	assert_eq(g.release(), "hook")


func _fight(g: FishingGame, good: bool) -> void:
	for _s in 2000:
		if g.state != "fight":
			return
		if good and g.note_dir >= 0 and g.note_t >= 0.85:
			g.tap(g.note_dir)
		g.update(0.02)


func _index_of(g: FishingGame, want_match: bool) -> int:
	for i in g.fish.size():
		if g.is_match(g.fish[i]["w"]) == want_match:
			return i
	return -1


func test_fishing_hold_bite_release_then_rhythm_fight() -> void:
	var g := _make(FishingGame, "fishing") as FishingGame
	var n := int(cfg["fishing"]["fish"])
	assert_eq(g.fish.size(), n)
	var right := _index_of(g, true)
	assert_gt(right, -1, "미끼와 뜻이 맞는 물고기가 있다")
	var w: WordData = g.words[g.fish[right]["w"]]
	_hook(g, right)
	assert_eq(g.state, "fight")
	assert_eq(g.need(), int(cfg["fishing"]["need_match"]), "뜻이 맞으면 적게 맞혀도 잡힌다")
	_fight(g, true)
	assert_eq(g.earned, [w.id] as Array[String])
	assert_eq(g.fish.size(), n, "다음 판에도 물고기 수가 그대로")
	var wrong := _index_of(g, false)
	_hook(g, wrong)
	assert_eq(g.need(), int(cfg["fishing"]["notes"]), "뜻이 틀리면 전부 맞혀야 잡힌다")
	_fight(g, false)
	assert_eq(g.misses, 1, "못 맞히면 놓친다")


func test_fishing_early_release_scares_and_wrong_circle_misses() -> void:
	var g := _make(FishingGame, "fishing", 12, 9) as FishingGame
	for f in g.fish:
		f["vel"] = Vector2.ZERO
	g.cast(g.fish[0]["pos"] + Vector2(0.01, 0))
	for _s in 200:
		if g.state == "bite":
			break
		g.update(0.02)
	assert_eq(g.state, "bite")
	assert_eq(g.release(), "early", "원이 크면 너무 이르다")
	assert_eq(g.state, "idle")
	assert_eq(g.misses, 0, "달아난 것은 실수가 아니다")
	var wrong := _index_of(g, false)
	_hook(g, wrong)
	for _s in 400:
		if g.note_dir >= 0 and g.note_t >= 0.85:
			break
		g.update(0.02)
	assert_false(g.tap((g.note_dir + 1) % FishingGame.DIRS), "다른 원을 누르면 틀림")
	assert_eq(g.state, "idle", "뜻이 틀린 물고기는 하나만 틀려도 놓친다")
	assert_eq(g.misses, 1)
	# 뜻이 다른 물고기도 모두 맞히면 잡힌다
	_hook(g, _index_of(g, false))
	var before := g.score()
	_fight(g, true)
	assert_eq(g.score(), before + 1)


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
	g.spawn_climber()
	assert_has(cfg["guard"]["climber_words"], g.walkers[-1]["name"], "담 넘는 것은 도둑·범죄자 단어")
	for w in g.walkers:
		if w["kind"] == "gate" and not w["true"]:
			assert_ne(w["shown"], g.words[w["w"]].meaning)


func _root_of(g: RootLinkGame, k: int, wrong := false) -> int:
	for i in g.roots.size():
		var r: Dictionary = g.roots[i]
		if r["state"] != "placed" and ((r["owner"] == g.targets[k]) != wrong):
			return i
	return -1


func _knock(g: RootLinkGame, i: int) -> void:
	## 다른 어원을 길에서 치지 않도록, 과녁만 활 바로 위로 옮겨 둔다
	g.roots[i]["vel"] = Vector2.ZERO
	g.roots[i]["pos"] = RootLinkGame.BOW + Vector2(-0.05, -0.04)
	g.shoot(g.roots[i]["pos"])
	for _s in 60:
		g.update(0.05)
		if g.roots[i]["state"] == "down":
			return


func test_root_link_board_has_words_roots_and_decoys() -> void:
	var g := _make(RootLinkGame, "pattern") as RootLinkGame
	var pc: Dictionary = cfg["pattern"]
	assert_eq(g.targets.size(), int(pc["pairs"]))
	var need := 0
	for k in g.targets.size():
		need += g.slots(k)
		assert_eq(g.slots(k), g.words[g.targets[k]].etym.size(), "어원 수만큼 뿌리 자리")
	var decoys := g.roots.filter(func(r: Dictionary) -> bool: return r["owner"] == -1).size()
	assert_eq(decoys, int(pc["decoys"]))
	assert_eq(g.roots.size(), need + decoys)
	for r in g.roots:
		assert_ne(String(r["meaning"]), "", "어원에도 뜻이 적힌다")


func test_root_link_shoot_drag_and_sprout() -> void:
	var g := _make(RootLinkGame, "pattern") as RootLinkGame
	var i := _root_of(g, 0)
	assert_false(g.place(i, 0), "돌아다니는 어원은 끌 수 없다")
	_knock(g, i)
	assert_eq(g.roots[i]["state"], "down", "화살에 맞으면 쓰러진다")
	assert_true(g.place(i, 0))
	assert_false(g.sprouted[0], "어원 하나로는 아직")
	var bad := _root_of(g, 0, true)
	_knock(g, bad)
	assert_true(g.place(bad, 0))
	assert_false(g.sprouted[0], "틀린 어원이 섞이면 새싹이 안 오른다")
	var extra := _root_of(g, 0)
	_knock(g, extra)
	assert_true(g.place(extra, 0), "어원 수보다 많이 놓을 수 있다(어원 수를 숨긴다)")
	assert_false(g.sprouted[0], "덤으로 틀린 어원이 있으면 새싹이 안 오른다")
	var more := _root_of(g, 1)
	_knock(g, more)
	assert_false(g.place(more, 0), "max_roots개를 넘으면 못 놓는다")
	g.place(more, -1, Vector2(0.5, 0.3))
	assert_true(g.place(bad, -1, Vector2(0.5, 0.3)), "놓은 어원을 떼어 낼 수 있다")
	assert_true(g.sprouted[0], "어원이 정확히 모두 맞으면 새싹")
	assert_eq(g.score(), 1)
	for k in range(1, g.targets.size()):
		for _n in g.slots(k):
			var j := _root_of(g, k)
			_knock(g, j)
			g.place(j, k)
	assert_true(g.complete())
	assert_true(g.finished, "새싹 5개면 완성")


func test_root_link_knocked_root_gets_up_and_time_out_reviews() -> void:
	var g := _make(RootLinkGame, "pattern") as RootLinkGame
	var i := _root_of(g, 0)
	_knock(g, i)
	for _s in int(float(cfg["pattern"]["down_time"]) / 0.1) + 2:
		g.update(0.1)
	assert_eq(g.roots[i]["state"], "roam", "오래 두면 다시 달아난다")
	g.update(float(cfg["pattern"]["duration"]) + 1.0)
	assert_true(g.finished)
	assert_false(g.complete(), "시간이 다 되면 미완성(정답을 보여 준다)")

func _trap_spot(g: TrapGame, i: int) -> Vector2:
	return g.pos(i, g.period() * 0.3)


func test_trap_watch_place_hunt_catches_matching_meanings() -> void:
	var g := _make(TrapGame, "trap") as TrapGame
	var n := int(cfg["trap"]["words"])
	assert_eq(g.paths.size(), n)
	assert_eq(g.tray.size(), n, "단어마다 뜻 덫 하나")
	assert_true(g.visible(), "처음엔 지켜본다")
	g.update(1.0)
	var p0 := g.pos(0, 0.0)
	assert_eq(g.pos(0, g.period()), p0, "한 바퀴 돌면 같은 자리(똑같이 움직인다)")
	# 단어 0, 1에는 맞는 뜻의 덫, 단어 2가 지나는 자리에는 다른 뜻의 덫
	g.place_trap(g.tray.find(0), _trap_spot(g, 0))
	assert_false(g.visible(), "캐릭터가 움직이면 단어들이 숨는다")
	g.place_trap(g.tray.find(1), _trap_spot(g, 1))
	g.place_trap(g.tray.find(3), _trap_spot(g, 2))
	assert_true(g.hide())
	assert_eq(g.phase, "hunt")
	for _s in int(g.period() / 0.02) + 5:
		g.update(0.02)
	assert_true(g.finished, "한 바퀴가 끝나면 판이 끝난다")
	assert_true(g.caught[0] and g.caught[1], "뜻이 맞는 덫에 걸린다")
	assert_false(g.caught[2], "뜻이 다른 덫은 그냥 지나간다")
	assert_eq(g.score(), 2)


func test_trap_can_pick_up_trap_again() -> void:
	var g := _make(TrapGame, "trap") as TrapGame
	g.place_trap(0, Vector2(0.5, 0.5))
	assert_eq(g.traps.size(), 1)
	assert_true(g.pick_trap(0))
	assert_eq(g.traps.size(), 0)
	assert_eq(g.tray.size(), int(cfg["trap"]["words"]))
	assert_true(g.hide(), "덫을 놓은 뒤 다시 숨을 수 있다")


func _spell(g: AnagramGame, word: String) -> void:
	var left: Array[int] = []
	for i in g.tiles.size():
		left.append(i)
	for k in word.length():
		for i in left:
			if g.tiles[i] == word[k]:
				while g.ice[i] > 0:
					g.hit(i)
				g.put(i, k)
				left.erase(i)
				break


func test_anagram_ice_must_break_before_drag() -> void:
	var g := _make(AnagramGame, "copy") as AnagramGame
	var hp := int(cfg["copy"]["ice_hp"])
	assert_eq(g.ice[0], hp, "글자는 얼음에 갇혀 있다")
	assert_false(g.put(0, 0), "얼음이 있으면 끌 수 없다")
	for k in hp:
		g.hit(0)
	assert_eq(g.ice[0], 0)
	assert_true(g.put(0, 0), "깨면 끌어서 놓을 수 있다")
	assert_eq(g.slot_of(0), 0)
	g.take(0)
	assert_eq(g.slot_of(0), -1, "칸에서 다시 내릴 수 있다")


func test_anagram_right_spelling_earns_and_wrong_retries() -> void:
	var g := _make(AnagramGame, "copy") as AnagramGame
	var w := g.current().id
	var wrong := w.substr(1) + w[0]
	if wrong == w:
		wrong = w.reverse()
	if wrong != w:
		_spell(g, wrong)
		assert_eq(g.last, "wrong", "틀린 철자")
		assert_eq(g.ice.max(), 0, "깬 얼음은 그대로")
		assert_false(g.slots.any(func(x: int) -> bool: return x >= 0), "틀리면 글자가 아래로 돌아간다")
	_spell(g, w)
	assert_eq(g.earned, [w] as Array[String])
