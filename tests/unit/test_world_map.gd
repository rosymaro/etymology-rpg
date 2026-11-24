extends GutTest
## 월드맵: 스테이지 1~10이 한 지도에 있고, 스토리에 맞지 않는 길은 문·지형이 막는다.

var m: WorldMap


func before_all() -> void:
	m = WorldMap.load_default()


func test_all_ten_regions_on_one_big_map() -> void:
	assert_eq(m.regions.size(), 10)
	assert_gt(m.size_px().x * m.size_px().y, 2600.0 * 1500.0 * 20, "예전 필드보다 훨씬 크다")
	for st in range(1, 11):
		assert_eq(m.stage_at(m.start(st)), st, "지역 %d 시작 자리" % st)
		assert_true(m.is_town(m.start(st)), "시작 자리는 마을")


func test_stage1_spots_are_reachable_but_next_stage_is_gated() -> void:
	var s := m.start(1)
	for id in ["forge", "tree", "board", "boss"]:
		assert_gt(m.path_len(s, m.spot(1, id)), -1, "스테이지 1 %s까지 걸어간다" % id)
	assert_eq(m.path_len(s, m.start(2)), -1, "문이 닫혀 있으면 스테이지 2로 못 간다")
	var open := {1: true}
	assert_gt(m.path_len(s, m.start(2), open), -1, "스테이지 1 문이 열리면 간다")
	assert_eq(m.path_len(s, m.start(3), open), -1, "스테이지 2 문은 아직 닫혀 있다")


func test_every_boss_reachable_when_all_gates_open() -> void:
	var open := {}
	for st in range(1, 11):
		open[st] = true
	for st in range(1, 11):
		assert_gt(m.path_len(m.start(1), m.spot(st, "boss"), open), -1, "보스 %d" % st)


func test_river_and_ridge_make_the_route_longer_than_straight_line() -> void:
	var s := m.start(1)
	var b := m.spot(1, "boss")
	var straight := (absf(b.x - s.x) + absf(b.y - s.y)) / m.tile
	assert_gt(float(m.path_len(s, b)), straight * 1.3, "강·산줄기는 정해 둔 다리·고갯길로만 건너서 돌아가야 한다")


func test_map_is_golden_ratio_landscape() -> void:
	var r := float(m.w) / float(m.h)
	assert_almost_eq(r, 1.618, 0.03, "가로가 긴 황금비")


func test_only_a_few_regions_have_a_maze() -> void:
	var with_maze := 0
	for rg in m.regions:
		with_maze += 1 if not (rg.get("maze", []) as Array).is_empty() else 0
	assert_eq(with_maze, 3, "미로는 지역 세 곳(2, 6, 9)에 한 군데씩만")


func test_walls_block_and_slide() -> void:
	var p := m.start(1)
	# 한 방향으로 오래 걸어도 막는 타일 위에 서지 않는다
	for k in 400:
		p = m.move(p, Vector2(9, 3), 26.0)
		assert_true(m.fits(p, 26.0), "막힌 곳에 들어가지 않는다")
	assert_eq(m.stage_at(p), 1, "다른 지역으로 넘어가지 않는다")


func test_closed_gate_is_reported() -> void:
	var gate_tile := Vector2i(-1, -1)
	for y in m.h:
		var x := m.rows[y].find("=")
		if x >= 0:
			gate_tile = Vector2i(x, y)
			break
	assert_ne(gate_tile, Vector2i(-1, -1))
	assert_false(m.walkable(gate_tile))
	assert_gt(m.closed_gate(gate_tile), 0)
	var st := m.closed_gate(gate_tile)
	assert_true(m.walkable(gate_tile, {st: true}))


func test_field_spot_for_encounters_is_in_the_stage_field() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var got := 0
	for k in 20:
		var p := m.random_field_spot(1, rng, m.start(1), 300, 1500, 30)
		if p != Vector2.INF:
			got += 1
			assert_eq(m.stage_at(p), 1)
			assert_false(m.is_town(p))
			assert_true(m.fits(p, 30))
	assert_gt(got, 10)
