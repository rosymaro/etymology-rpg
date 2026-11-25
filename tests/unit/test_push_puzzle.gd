extends GutTest
## 돌 밀기 퍼즐(07-fun.md 3절): 지도에 박힌 퍼즐마다 규칙대로 풀 수 있다(게임 규칙으로 너비 우선 찾기).

var m: WorldMap


func before_all() -> void:
	m = WorldMap.load_default()


func _key(p: PushPuzzle) -> String:
	var ks: Array = p.rocks.keys()
	ks.sort()
	var fs: Array = p.filled.keys()
	fs.sort()
	return str(ks) + str(fs)


## 게임 규칙(PushPuzzle)으로 너비 우선 찾기: 목표(발판·상자 곁·쪽지)에 닿을 수 있는가.
func _solvable(q: Dictionary, heavy_ok: bool) -> bool:
	var p := PushPuzzle.from_dict(q)
	var seen := {}
	var queue: Array = [[p.rocks.duplicate(), p.filled.duplicate()]]
	while not queue.is_empty() and seen.size() < 20000:
		var st: Array = queue.pop_front()
		p.rocks = st[0].duplicate()
		p.filled = st[1].duplicate()
		var k := _key(p)
		if seen.has(k):
			continue
		seen[k] = true
		var area := p.reach(p.entry)
		var ok := p.plates_done() if not p.plates.is_empty() else true
		if p.plates.is_empty():
			if not p.chests.is_empty():
				ok = p.chests.any(func(c: Vector2i) -> bool: return PushPuzzle.DIRS.any(func(d: Vector2i) -> bool: return area.has(c + d)))
			if not p.secrets.is_empty():
				ok = ok and p.secrets.any(func(s: Vector2i) -> bool: return area.has(s) and not p.rocks.has(s))
		if ok:
			return true
		for r in st[0].keys():
			for d in PushPuzzle.DIRS:
				if not area.has(r - d):
					continue
				p.rocks = st[0].duplicate()
				p.filled = st[1].duplicate()
				if p.push(r, d, heavy_ok):
					queue.append([p.rocks.duplicate(), p.filled.duplicate()])
	return false


func test_stage1_has_eight_varied_puzzles() -> void:
	var push := m.puzzles.filter(func(q: Dictionary) -> bool: return q["kind"] != "cave")
	assert_eq(push.size(), 8)
	var kinds := {}
	for q in push:
		kinds[q["kind"]] = true
	assert_gte(kinds.size(), 7, "여러 가지 경우")


func test_every_puzzle_is_solvable_with_game_rules() -> void:
	for q in m.puzzles:
		assert_true(_solvable(q, true), "풀 수 있다: %s" % q["id"])


func test_heavy_rock_needs_com() -> void:
	for q in m.puzzles:
		if q["kind"] == "heavy":
			assert_false(_solvable(q, false), "무거운 돌은 com- 없이 못 민다")


func test_water_fills_and_ice_slides() -> void:
	var water: Dictionary = m.puzzles.filter(func(q: Dictionary) -> bool: return q["kind"] == "water")[0]
	var p := PushPuzzle.from_dict(water)
	var r: Vector2i = p.rocks.keys().filter(func(c: Vector2i) -> bool: return p.ch(c + Vector2i(1, 0)) == "w")[0]
	assert_true(p.push(r, Vector2i(1, 0), false))
	assert_true(p.filled.has(r + Vector2i(1, 0)), "물에 빠진 돌은 징검다리")
	assert_true(p.open_cell(r + Vector2i(1, 0)))
	var ice: Dictionary = m.puzzles.filter(func(q: Dictionary) -> bool: return q["kind"] == "ice")[0]
	var pi := PushPuzzle.from_dict(ice)
	var ir: Vector2i = pi.rocks.keys()[0]
	pi.push(ir, Vector2i(1, 0), false)
	var moved: Vector2i = pi.rocks.keys()[0]
	assert_gt(moved.x - ir.x, 1, "얼음 위 돌은 미끄러진다")
	pi.reset()
	assert_true(pi.rocks.has(ir), "다시 하면 처음 자리로")
