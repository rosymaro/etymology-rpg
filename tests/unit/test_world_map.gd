extends GutTest
## 월드맵: 스테이지 1~10이 한 지도에 있고, 스토리에 맞지 않는 길은 문·지형이 막는다.

var m: WorldMap


func before_all() -> void:
	m = WorldMap.load_default()


func test_stage1_is_in_the_middle_and_others_around_it() -> void:
	var mid := m.size_px() / 2
	assert_eq(m.stage_at(mid), 1, "한가운데는 스테이지 1")
	var s2 := m.start(2) - m.start(1)
	assert_true(s2.x > 0 and s2.y < 0, "스테이지 2는 오른쪽 위(2시 쪽)")
	var s4 := m.start(4) - m.start(1)
	assert_true(s4.x < 0 and s4.y < 0, "스테이지 4는 왼쪽 위(10시 쪽)")
	var s5 := m.start(5) - m.start(1)
	assert_gt(s5.y, 0.0, "스테이지 5는 아래(6시 쪽)")


func test_each_gate_opens_only_the_next_region() -> void:
	for k in range(1, 10):
		var open := {k: true, "s01_q_root": true, "s01_q_magic": true}
		assert_gt(m.path_len(m.start(1), m.start(k + 1), open), -1, "문 %d → 지역 %d" % [k, k + 1])
		for other in range(2, 11):
			if other != k + 1:
				assert_eq(m.path_len(m.start(1), m.start(other), open), -1, "문 %d로 지역 %d엔 못 간다" % [k, other])


func test_all_ten_regions_on_one_big_map() -> void:
	assert_eq(m.regions.size(), 10)
	assert_gt(m.size_px().x * m.size_px().y, 2600.0 * 1500.0 * 20, "예전 필드보다 훨씬 크다")
	for st in range(1, 11):
		assert_eq(m.stage_at(m.start(st)), st, "지역 %d 시작 자리" % st)
		assert_true(m.is_town(m.start(st)), "시작 자리는 마을")


func test_stage1_quests_open_the_way_to_the_boss() -> void:
	var s := m.start(1)
	var b := m.spot(1, "boss")
	assert_eq(m.path_len(s, b), -1, "퀘스트 없이 보스에 못 간다")
	assert_eq(m.path_len(s, b, {"s01_q_root": true}), -1, "다리만 고쳐서는 절벽 아래로 못 간다")
	assert_gt(m.path_len(s, b, {"s01_q_root": true, "s01_q_magic": true}), -1, "다리를 고치고 절벽을 내려가면 간다")
	assert_eq(m.quest_gate("s01_q_root")["kind"], "bridge")
	assert_eq(m.quest_gate("s01_q_magic")["kind"], "cliff")


func test_stage1_spots_are_reachable_but_next_stage_is_gated() -> void:
	var s := m.start(1)
	var q := {"s01_q_root": true, "s01_q_magic": true}
	for id in ["forge", "tree", "board", "boss"]:
		assert_gt(m.path_len(s, m.spot(1, id), q), -1, "스테이지 1 %s까지 걸어간다" % id)
	assert_eq(m.path_len(s, m.start(2), q), -1, "문이 닫혀 있으면 스테이지 2로 못 간다")
	var open := {1: true, "s01_q_root": true, "s01_q_magic": true}
	assert_gt(m.path_len(s, m.start(2), open), -1, "스테이지 1 문이 열리면 간다")
	assert_eq(m.path_len(s, m.start(3), open), -1, "스테이지 2 문은 아직 닫혀 있다")
	open[2] = true
	assert_gt(m.path_len(s, m.start(3), open), -1, "스테이지 2 문이 열리면 가운데에서 지역 3으로")


func test_every_boss_reachable_when_all_gates_open() -> void:
	var open := {"s01_q_root": true, "s01_q_magic": true}
	for st in range(1, 11):
		open[st] = true
	for st in range(1, 11):
		assert_gt(m.path_len(m.start(1), m.spot(st, "boss"), open), -1, "보스 %d" % st)


func test_river_and_ridge_make_the_route_longer_than_straight_line() -> void:
	var s := m.start(1)
	var b := m.spot(1, "boss")
	var straight := (absf(b.x - s.x) + absf(b.y - s.y)) / m.tile
	assert_gt(float(m.path_len(s, b, {"s01_q_root": true, "s01_q_magic": true})), straight * 1.3, "강·산줄기는 정해 둔 다리·고갯길로만 건너서 돌아가야 한다")


func test_map_is_golden_ratio_landscape() -> void:
	var r := float(m.w) / float(m.h)
	assert_almost_eq(r, 1.618, 0.03, "가로가 긴 황금비")


func test_only_a_few_regions_have_a_maze() -> void:
	var with_maze := 0
	for rg in m.regions:
		with_maze += 1 if not (rg.get("maze", []) as Array).is_empty() else 0
	assert_eq(with_maze, 3, "미로는 지역 세 곳(2, 6, 9)에 한 군데씩만")


func test_region_borders_are_not_straight_lines() -> void:
	# 지역 1의 경계 칸들이 한 줄(같은 x나 같은 y)에 몰리지 않는다
	var xs := {}
	var ys := {}
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			var a := m.stage_of(Vector2i(x, y))
			if a == 1 and m.stage_of(Vector2i(x + 1, y)) not in [1, 0]:
				xs[x] = true
			if a == 1 and m.stage_of(Vector2i(x, y + 1)) not in [1, 0]:
				ys[y] = true
	assert_gt(xs.size(), 25, "경계가 들쭉날쭉하다(가로 자리)")
	assert_gt(ys.size(), 20, "경계가 들쭉날쭉하다(세로 자리)")


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


func test_field_spot_avoids_the_visible_screen() -> void:
	# 사용자 의견: 몹은 화면 밖에서만 다시 나온다
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var view := Rect2(m.start(1) - Vector2(360, 640), Vector2(720, 1280))
	var got := 0
	for k in 30:
		var p := m.random_field_spot(1, rng, m.start(1), 300, 1500, 30, view)
		if p != Vector2.INF:
			got += 1
			assert_false(view.grow(30).has_point(p))
	assert_gt(got, 10)
