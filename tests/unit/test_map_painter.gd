extends GutTest
## 지도 풍경(MapPainter, data/map/biomes.json): 지역마다 풍경이 있고, 산은 안쪽일수록 깊다(산맥처럼 큰 봉우리).


func test_every_stage_has_a_distinct_biome() -> void:
	var p := MapPainter.for_map(WorldMap.load_default())
	var names := {}
	for st in range(1, 11):
		assert_true(p.bio.has(st), "스테이지 %d 풍경" % st)
		names[p.bio[st]["name"]] = true
	assert_eq(names.size(), 10, "지역마다 다른 풍경")
	for want in ["desert", "lava", "jungle", "snow"]:
		assert_true(names.has(want), "사용자 의견: " + want)


func test_mountain_ranges_get_deeper_inside() -> void:
	var m := WorldMap.load_default()
	var p := MapPainter.for_map(m)
	var deepest := 0
	for y in m.h:
		for x in m.w:
			if m.rows[y][x] == "^":
				var d := int(p._mtn[y * m.w + x])
				assert_gt(d, 0)
				deepest = maxi(deepest, d)
	assert_gte(deepest, 3, "산줄기 안쪽은 높은 봉우리(칸마다 같은 세모가 아니다)")


func test_wind_moves_over_time_and_space() -> void:
	var p := MapPainter.for_map(WorldMap.load_default())
	assert_ne(p.wind(0, 0, 0.0), p.wind(0, 0, 2.0), "시간에 따라 바람이 분다")
	assert_ne(p.wind(0, 0, 1.0), p.wind(800, 0, 1.0), "돌풍이 지도 위를 지나간다")
	var w := p.wind(123, 45, 6.0)
	assert_between(w, 0.0, 1.0)


func test_lava_region_water_is_lava_and_minimap_uses_biome_colors() -> void:
	var m := WorldMap.load_default()
	var p := MapPainter.for_map(m)
	assert_true(p.bio[9].get("lava", false), "용암 지대의 물은 용암")
	var c := m.start(4)
	var cell := m.cell(c)
	assert_ne(p.mini_color(cell.x, cell.y, {}), Color.MAGENTA)
