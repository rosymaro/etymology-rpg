extends Node
## 지도 그림 내보내기(사용자 의견: 배경을 같은 크기로 새로 그려 넣는다). Main이 --export-map=<폴더>를 보면 붙인다.
## 사라지지 않고 움직이지 않는 것만(사용자 의견): 길목은 열린 모습, 마을 건물 포함. 겹마다 1024×1536px(16×24칸, 사용자 의견) 조각을 <폴더>/<겹>/<열>_<행>.png로 쓴다. 게임은 res://assets/map/<겹>/에 같은 이름이 있으면 그것을 쓴다.
## 투명 겹(grass, mtn, trees)은 색이 알파만큼 곱해진 채로 나온다. tools/map/export_map.py가 바로잡고 미리보기를 만든다.
## --export-only=<열>_<행>,... 이면 그 조각만.

const PER_FRAME := 6

var out_dir := ""
var main: Main
var root: Window


func start(m: Main, dir: String) -> void:
	main = m
	out_dir = dir
	root = get_tree().root
	_run.call_deferred()


func _run() -> void:
	var only := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--export-only="):
			for s in a.trim_prefix("--export-only=").split(","):
				only[s] = true
	var m := WorldMap.load_default()
	var p := MapPainter.for_map(m)
	var n := MapView.FILE_CELLS
	var ts := m.tile
	var jobs: Array = []
	for cy in ceili(m.h / float(n.y)):
		for cx in ceili(m.w / float(n.x)):
			if not only.is_empty() and not only.has("%d_%d" % [cx, cy]):
				continue
			for layer in MapPainter.LAYERS:
				jobs.append([layer, cx, cy])
	for layer in MapPainter.LAYERS:
		DirAccess.make_dir_recursive_absolute(out_dir.path_join(layer))
	var done := 0
	while done < jobs.size():
		var batch: Array = []
		for j in jobs.slice(done, done + PER_FRAME):
			var layer: String = j[0]
			var vp := SubViewport.new()
			vp.size = n * ts
			vp.transparent_bg = layer != "ground"
			vp.disable_3d = true
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			var c := Node2D.new()
			var mg: Array = MapView.MARGIN[layer]
			var x0: int = j[1] * n.x
			var y0: int = j[2] * n.y
			c.draw.connect(func() -> void:
				p.draw_layer(c, layer, -Vector2(x0, y0) * ts, x0 - int(mg[0]), y0 - int(mg[1]), x0 + n.x + int(mg[0]), y0 + n.y + int(mg[2])))
			vp.add_child(c)
			add_child(vp)
			batch.append([vp, j])
		await RenderingServer.frame_post_draw
		for b in batch:
			var j: Array = b[1]
			var img: Image = (b[0] as SubViewport).get_texture().get_image()
			img.save_png(out_dir.path_join("%s/%d_%d.png" % [j[0], j[1], j[2]]))
			(b[0] as Node).queue_free()
		done += batch.size()
		print("export %d/%d" % [done, jobs.size()])
	get_tree().quit()
