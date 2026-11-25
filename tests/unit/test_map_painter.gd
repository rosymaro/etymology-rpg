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


func test_effects_can_be_turned_off_one_by_one() -> void:
	# 사용자 의견: 폰에서 프레임이 떨어지면 옵션에서 지도 효과를 하나씩 끈다
	var m := WorldMap.load_default()
	var p := MapPainter.new()
	p._setup(m)
	p.fx_sway = false
	assert_eq(p.sway(100, 50, 3.0, 1.0), 0.0, "흔들림을 끄면 가만히 있다")
	var life := MapLife.new(p)
	life.on_critters = false
	life.on_particles = false
	var hero := m.start(1)
	life.update(0.1, hero, hero - Vector2(360, 640), Vector2(720, 1280), 1.0)
	assert_eq(life.critters.size(), 0, "동물을 끄면 안 나온다")
	assert_eq(life.parts.size(), 0, "날리는 것을 끄면 안 나온다")
	life.on_particles = true
	life.update(0.1, hero, hero - Vector2(360, 640), Vector2(720, 1280), 1.1)
	assert_gt(life.parts.size(), 0, "다시 켜면 나온다")


func test_map_effect_settings_are_saved() -> void:
	var path := "user://test_settings_map_fx.cfg"
	var s := SettingsStore.new(path)
	for k in SettingsStore.MAP_KEYS:
		assert_eq(bool(s.get(k)), k != "show_fps", "처음에는 효과는 켜져 있고 FPS는 꺼져 있다: " + k)
	s.map_grass = false
	s.map_water = false
	s.show_fps = true
	s.save_settings()
	var s2 := SettingsStore.new(path)
	s2.load_settings()
	assert_false(s2.map_grass)
	assert_false(s2.map_water)
	assert_true(s2.map_sway)
	assert_true(s2.show_fps)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
