extends Node
## 필드 시간 재기(사용자 의견: 폰에서 FPS가 20 아래). Main이 --perf-field를 보면 붙인다.
## 지역·효과 설정마다 몇 초씩 걸으며 지도 그리기·나머지 그리기·계산 시간(ms)과 FPS를 찍는다.

var main: Main
var root: Window


func start(m: Main, _dir: String) -> void:
	main = m
	root = get_tree().root
	_run.call_deferred()


func _measure(label: String, fs: FieldScreen) -> void:
	fs.perf.clear()
	var t := 0.0
	var frames := 0
	var t0 := Time.get_ticks_usec()
	while t < 3.0:
		fs._stick_on = true
		fs._stick_vec = Vector2.from_angle(t * 0.7) * 0.8  # 천천히 원을 그리며 걷는다
		await get_tree().process_frame
		t = (Time.get_ticks_usec() - t0) / 1e6
		frames += 1
	print("PERF %-28s fps %5.1f  map %6.2f  rest %6.2f  tick %6.2f  mobs %d" % [label, frames / t, fs.perf.get("map", 0.0), fs.perf.get("rest", 0.0), fs.perf.get("tick", 0.0), fs._enemies.size()])


func _run() -> void:
	seed(3)
	var gd: Node = root.get_node("GameData")
	gd.save_prefix = "user://perf_"
	gd.use_dev_save(false)
	gd.save_store.erase()
	gd.new_game("하늘")
	gd.tutorials_enabled = false
	var s: GameState = gd.state
	s.flags["s01_tut_battle"] = true
	var st: SettingsStore = gd.settings
	var wm := WorldMap.load_default()
	for stage in [1, 7]:
		var rg: Dictionary = wm.region(stage)
		var r: Array = rg["rect"]
		s.pos = (Vector2(int(r[0]) + int(r[2]) / 2, int(r[1]) + int(r[3]) / 2) + Vector2(0.5, 0.5)) * wm.tile
		main.flow.go_field()
		var fs := main.current() as FieldScreen
		await get_tree().create_timer(0.5).timeout
		for on in [true, false]:
			for k in ["map_water", "map_critters", "map_particles"]:
				st.set(k, on)
			await _measure("stage %d effects %s" % [stage, "on" if on else "off"], fs)
		fs._enemies.clear()
		fs._spawn_t = 1e9
		await _measure("stage %d off, no mobs" % stage, fs)
	get_tree().quit()
