extends Node
## 지도 풍경 캡처(지역마다 한 장): 산·숲·물·들판이 고루 보이는 자리를 골라 찍는다. Main이 --capture-map=<폴더>를 보면 붙인다.

var out_dir := "user://map_shots"
var main: Main
var root: Window


func start(m: Main, dir: String) -> void:
	main = m
	out_dir = dir
	root = get_tree().root
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


## 그 지역 안에서 화면(11×20칸)에 산·숲·물·풀이 가장 고루 보이는 자리.
func _best_spot(wm: WorldMap, stage: int) -> Vector2:
	var rg: Dictionary = wm.region(stage)
	var r: Array = rg["rect"]
	var best := wm.start(stage)
	var score := -1
	for k in 300:
		var c := Vector2i(int(r[0]) + randi() % int(r[2]), int(r[1]) + randi() % int(r[3]))
		if wm.ch(c) != "." or wm.stage_of(c) != stage:
			continue
		var seen := {}
		for y in range(c.y - 9, c.y + 10):
			for x in range(c.x - 5, c.x + 6):
				var ch := wm.ch(Vector2i(x, y))
				if ch in ["^", "T", "~", "w", "."]:
					seen[ch] = int(seen.get(ch, 0)) + 1
		var sc := 0
		for v in seen.values():
			sc += mini(int(v), 25)
		if sc > score:
			score = sc
			best = (Vector2(c) + Vector2(0.5, 0.5)) * wm.tile
	return best


func _run() -> void:
	seed(3)
	var gd: Node = root.get_node("GameData")
	gd.save_prefix = "user://mapshots_"
	gd.use_dev_save(false)
	gd.save_store.erase()
	gd.new_game("하늘")
	gd.tutorials_enabled = false
	var s: GameState = gd.state
	s.flags["s01_tut_battle"] = true
	var wm := WorldMap.load_default()
	for st in range(1, 11):
		s.pos = _best_spot(wm, st)
		main.flow.go_field()
		var fs := main.current() as FieldScreen
		fs._enemies.clear()
		fs._spawn_t = 1e9
		await get_tree().create_timer(1.6).timeout
		fs._enemies.clear()
		await _shot("map_%02d" % st)
	get_tree().quit()
