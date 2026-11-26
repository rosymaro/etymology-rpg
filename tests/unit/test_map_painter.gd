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


func test_map_view_bakes_chunks_once_and_reuses_them() -> void:
	# 사용자 의견: 효과를 다 꺼도 FPS 20 아래 → 지도는 조각으로 한 번만 그리고 붙인다
	var m := WorldMap.load_default()
	var p := MapPainter.for_map(m)
	var mv := MapView.new(p, 80.0)
	mv.art_dir = "user://no_map_art"  # 그림 파일이 없을 때(게임 코드가 그린다)
	add_child_autofree(mv)
	var cam := m.start(1) - Vector2(360, 640)
	mv.update(cam, Vector2(720, 1280), 0.0, {})
	var first := mv.baked
	assert_gt(first, 0, "보이는 조각을 그린다")
	for i in 5:
		mv.update(cam, Vector2(720, 1280), i * 0.1, {})
	assert_lte(mv.baked, first + 5, "같은 자리면 다시 그리지 않는다(둘레 미리 그리기는 프레임마다 하나)")



func test_map_view_skips_empty_mountain_and_tree_chunks() -> void:
	var m := WorldMap.load_default()
	var mv := MapView.new(MapPainter.for_map(m), 80.0)
	add_child_autofree(mv)
	var any_empty := false
	for cy in m.h / MapView.CHUNK:
		for cx in m.w / MapView.CHUNK:
			if not mv._worth("mtn", cx, cy):
				any_empty = true
	assert_true(any_empty, "산이 없는 조각은 산 겹을 그리지 않는다")


func test_map_view_uses_drawn_picture_files_when_present() -> void:
	# 사용자 의견: 배경 그림을 직접 그려 넣는다 → <겹>/<열>_<행>.png(1024×1536px 조각)가 있으면 그것을 쓴다
	var m := WorldMap.load_default()
	var mv := MapView.new(MapPainter.for_map(m), 80.0)
	mv.art_dir = "user://test_map_art"
	DirAccess.make_dir_recursive_absolute(mv.art_dir + "/ground")
	var cam := m.start(1) - Vector2(360, 640)
	var c := Vector2i(int(cam.x / (64 * MapView.FILE_CELLS.x)), int((cam.y + 640) / (64 * MapView.FILE_CELLS.y)))
	var img := Image.create(1024, 1536, false, Image.FORMAT_RGBA8)
	img.fill(Color.HOT_PINK)
	var path := mv.art_dir + "/ground/%d_%d.png" % [c.x, c.y]
	img.save_png(path)
	add_child_autofree(mv)
	mv.update(cam, Vector2(720, 1280), 0.0, {})
	assert_gt(mv.from_files, 0, "그림 파일이 있는 조각은 파일을 쓴다")
	assert_gt(mv.baked, 0, "파일이 없는 조각은 스스로 그린다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_map_view_edge_picture_is_cut_at_map_end() -> void:
	# 사용자 의견: 지도 끝 조각은 칸 중간에서 끊기지 않게 지도가 끝나는 칸까지만(오른쪽 열 256px 폭, 아래 줄 1024px 높이)
	var m := WorldMap.load_default()
	var mv := MapView.new(MapPainter.for_map(m), 80.0)
	mv.art_dir = "user://test_map_art_edge"
	DirAccess.make_dir_recursive_absolute(mv.art_dir + "/ground")
	var fx := (m.w - 1) / MapView.FILE_CELLS.x
	var fy := (m.h - 1) / MapView.FILE_CELLS.y
	var size := Vector2i(m.w - fx * MapView.FILE_CELLS.x, m.h - fy * MapView.FILE_CELLS.y) * m.tile
	assert_eq(size, Vector2i(256, 1024))
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.HOT_PINK)
	var path := mv.art_dir + "/ground/%d_%d.png" % [fx, fy]
	img.save_png(path)
	add_child_autofree(mv)
	var cam := Vector2(m.w, m.h) * m.tile - Vector2(720, 1280)
	mv.update(cam, Vector2(720, 1280), 0.0, {})
	assert_gt(mv.from_files, 0, "지도 끝의 작은 그림도 쓴다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_painted_map_files_cover_every_piece() -> void:
	# 사용자 의견: 동화책 삽화풍 지도(tools/map/paint). 장마다 바닥 그림이 있고, 게임은 그것을 쓴다
	var m := WorldMap.load_default()
	for cy in ceili(m.h / float(MapView.FILE_CELLS.y)):
		for cx in ceili(m.w / float(MapView.FILE_CELLS.x)):
			assert_true(ResourceLoader.exists("res://assets/map/ground/%d_%d.webp" % [cx, cy]), "바닥 그림 %d_%d" % [cx, cy])
	var mv := MapView.new(MapPainter.for_map(m), 80.0)
	add_child_autofree(mv)
	mv.update(m.start(1) - Vector2(360, 640), Vector2(720, 1280), 0.0, {})
	assert_gt(mv.from_files, 0, "그림 파일을 쓴다")
	assert_eq(mv.baked, 0, "그림이 있는 장은 코드로 그리지 않는다(화풍을 섞지 않는다)")
