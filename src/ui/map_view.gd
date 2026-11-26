class_name MapView
extends Node2D
## 큰 지도 그림(표현 층). 사용자 의견: 효과를 다 꺼도 FPS가 20 아래였다(매 프레임 칸마다 다시 그렸다).
## 그래서 지도를 조각(CHUNK칸 = 512px)으로 한 번만 그려 두고 매 프레임 붙이기만 한다. 겹(아래부터):
##   ground 바닥(땅·물 바탕·바닷가·길·다리), grass 풀·꽃, 물 움직임(매 프레임 그림), mtn 산, trees 나무
## 풀·나무 겹은 화면 크기 한 장으로 모은 뒤 셰이더로 바람에 흔든다(GPU가 하므로 가볍다).
## 그림 파일(사용자 의견: 배경을 직접 그려 넣는다)이 있으면 그 조각은 파일을 쓴다:
##   res://assets/map/<겹>/<열>_<행>.webp(.png), 한 장 FILE_CELLS칸 = 1024×1536px (사용자 의견: 픽셀 기준 1024×1536, assets/map/README.md)
## 부모(FieldScreen)보다 먼저 그려진다(show_behind_parent). 몹·주인공·작은 동물은 부모가 그 위에 그린다.

const CHUNK := 8
const FILE_CELLS := Vector2i(16, 24)  ## 그림 파일 한 장(가로×세로 칸)
const MARGIN := {"ground": [1, 1, 1], "grass": [1, 1, 1], "mtn": [3, 1, 6], "trees": [2, 1, 3]}  ## 옆, 위, 아래(높은 것은 아래 칸에서 솟는다)
const KEEP := 36  ## 겹마다 남겨 둘 조각 수
const SWAY_SHADER := """
shader_type canvas_item;
render_mode blend_premul_alpha;
uniform vec2 cam_px;
uniform float t;
uniform float speed = 0.9;
uniform float wave = 0.0025;
uniform vec2 amp = vec2(2.0, 7.0);
uniform float strength = 1.0;
void fragment() {
	vec2 wp = UV / TEXTURE_PIXEL_SIZE + cam_px;
	float w = 0.5 + 0.5 * sin(t * speed - (wp.x + wp.y * 0.4) * wave + sin(t * 0.37) * 1.5);
	float sw = sin(t * 2.6 + wp.x * 0.012 + wp.y * 0.03) * mix(amp.x, amp.y, w) + w * amp.y * 0.6;
	COLOR = texture(TEXTURE, UV - vec2(sw * strength, 0.0) * TEXTURE_PIXEL_SIZE);
}
"""

var painter: MapPainter
var bleed := 0.0
var gates := {}
var cam := Vector2.ZERO
var view := Vector2(720, 1280)
var t := 0.0
var on_grass := true
var on_sway := true
var on_water := true
var baked := 0  ## 지금까지 그린 조각 수(테스트·시간 재기용)
var art_dir := "res://assets/map"  ## 사람이 그린 그림 파일 폴더(테스트는 user://)
var from_files := 0  ## 그림 파일을 쓴 조각 수

var _roots := {}  ## 겹 -> 조각 Sprite2D를 담는 Node2D
var _comp := {}  ## 흔들리는 겹 -> 화면 크기로 모으는 SubViewport
var _show := {}  ## 흔들리는 겹 -> 모은 그림을 셰이더로 보여 주는 Sprite2D
var _water: Node2D
var _bake: Node
var _chunks := {}  ## "겹:열:행" -> {sprite, vp(없으면 파일), used}
var _files := {}  ## 파일 경로 -> Texture2D 또는 null
var _paths := {}  ## "겹/열_행" -> 파일 경로("" 없음)
var _refs := {}  ## 파일 경로 -> 그 파일을 쓰는 조각 수
var _has := {}  ## "겹:열:행" -> 그릴 것이 있나(산·나무 없는 조각은 건너뛴다)
var _premul := CanvasItemMaterial.new()
var _frame := 0


func _init(p: MapPainter, bleed_px: float) -> void:
	painter = p
	bleed = bleed_px
	painter.painted = ResourceLoader.exists("res://assets/map/ground/0_0.webp") or ResourceLoader.exists("res://assets/map/ground/0_0.png")
	show_behind_parent = true
	_premul.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_bake = Node.new()
	add_child(_bake)
	var shader := Shader.new()
	shader.code = SWAY_SHADER
	var wcfg: Dictionary = p.cfg.get("wind", {})
	var sw: Array = wcfg.get("sway", [2.0, 7.0])
	for layer in MapPainter.LAYERS:
		var root := Node2D.new()
		_roots[layer] = root
		if layer == "grass" or layer == "trees":
			var vp := SubViewport.new()
			vp.transparent_bg = true
			vp.disable_3d = true
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			vp.add_child(root)
			_bake.add_child(vp)
			_comp[layer] = vp
			var spr := Sprite2D.new()
			spr.centered = false
			spr.texture = vp.get_texture()
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("speed", float(wcfg.get("speed", 0.9)))
			mat.set_shader_parameter("wave", float(wcfg.get("wave", 0.0025)))
			mat.set_shader_parameter("amp", Vector2(float(sw[0]), float(sw[1])))
			mat.set_shader_parameter("strength", 0.5 if layer == "grass" else 0.8)
			spr.material = mat
			_show[layer] = spr
			add_child(spr)
		else:
			add_child(root)
		if layer == "grass":  # 물 움직임은 풀 위, 산 아래
			_water = Node2D.new()
			_water.draw.connect(func() -> void:
				if on_water:
					painter.draw_water_live(_water, -cam, cam, view, t, bleed)
				painter.draw_changing(_water, -cam, cam, view, bleed, gates))
			add_child(_water)


## 매 프레임: 보이는 조각을 준비하고(없으면 그린다), 자리를 옮긴다.
func update(cam_px: Vector2, view_px: Vector2, now: float, gates_now: Dictionary) -> void:
	_frame += 1
	cam = cam_px
	view = view_px
	t = now
	gates = gates_now  # 조각 그림은 길목이 열린 모습. 닫힌 길목·구멍은 물 움직임과 함께 매 프레임 덮어 그린다
	var ts := float(painter.map.tile) * CHUNK
	var a := Vector2i(floori(cam.x / ts), floori((cam.y - bleed) / ts))
	var b := Vector2i(floori((cam.x + view.x) / ts), floori((cam.y + view.y + bleed) / ts))
	var prefetch := 1
	for layer in MapPainter.LAYERS:
		(_roots[layer] as Node2D).visible = layer != "grass" or on_grass
		if layer == "grass" and not on_grass:
			continue
		for cy in range(a.y - 1, b.y + 2):
			for cx in range(a.x - 1, b.x + 2):
				var inside := cx >= a.x and cx <= b.x and cy >= a.y and cy <= b.y
				var id := "%s:%d:%d" % [layer, cx, cy]
				if _chunks.has(id):
					_chunks[id]["used"] = _frame
				elif inside or prefetch > 0:  # 보이는 조각은 바로, 둘레 조각은 프레임마다 하나씩 미리
					if not inside:
						prefetch -= 1
					_make(layer, cx, cy, id)
	for layer in MapPainter.LAYERS:
		var root: Node2D = _roots[layer]
		if _comp.has(layer):
			var vp: SubViewport = _comp[layer]
			var sz := Vector2i(int(ceil(view.x)), int(ceil(view.y + bleed * 2)))
			if vp.size != sz:
				vp.size = sz
			root.position = -cam + Vector2(0, bleed)
			var spr: Sprite2D = _show[layer]
			spr.position = Vector2(0, -bleed)
			spr.visible = root.visible
			var mat: ShaderMaterial = spr.material
			mat.set_shader_parameter("cam_px", cam - Vector2(0, bleed))
			mat.set_shader_parameter("t", t)
			mat.set_shader_parameter("strength", (0.5 if layer == "grass" else 0.8) if on_sway else 0.0)
		else:
			root.position = -cam
	_water.queue_redraw()
	_evict()


func _make(layer: String, cx: int, cy: int, id: String) -> void:
	var m := painter.map
	if cx < 0 or cy < 0 or cx * CHUNK >= m.w or cy * CHUNK >= m.h:
		return
	var ts := float(m.tile)
	var spr := Sprite2D.new()
	spr.centered = false
	spr.position = Vector2(cx, cy) * CHUNK * ts
	var entry := {"sprite": spr, "vp": null, "used": _frame, "path": ""}
	var name := "%d_%d" % [cx * CHUNK / FILE_CELLS.x, cy * CHUNK / FILE_CELLS.y]
	var path := _find(layer, name)
	var tex := _file(path) if path != "" else null
	if tex == null and _find("ground", name) != "":
		# 그린 그림이 있는 장은 모든 겹을 그림 파일로만(없는 겹은 비어 있는 것): 코드 그림과 섞지 않는다
		_chunks[id] = {"sprite": null, "vp": null, "used": _frame, "path": ""}
		spr.free()
		return
	if tex:  # 그린 그림(사람이 그렸거나 tools/map/paint가 그린 것)
		entry["path"] = path
		_refs[path] = int(_refs.get(path, 0)) + 1
		var per := FILE_CELLS / CHUNK
		spr.texture = tex
		spr.region_enabled = true
		var pos := Vector2((cx % per.x) * CHUNK, (cy % per.y) * CHUNK) * ts
		var tsz := Vector2(tex.get_size())  # 지도 끝 조각은 지도가 끝나는 칸까지만이라 더 작다
		if pos.x >= tsz.x or pos.y >= tsz.y:
			_chunks[id] = entry
			entry["sprite"] = null
			spr.free()
			return
		spr.region_rect = Rect2(pos, (Vector2(CHUNK, CHUNK) * ts).min(tsz - pos))
		from_files += 1
	else:
		if not _worth(layer, cx, cy):
			_chunks[id] = {"sprite": null, "vp": null, "used": _frame}
			return
		var vp := SubViewport.new()
		vp.size = Vector2i(CHUNK, CHUNK) * m.tile
		vp.transparent_bg = layer != "ground"
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var c := Node2D.new()
		var mg: Array = MARGIN[layer]
		var x0 := cx * CHUNK
		var y0 := cy * CHUNK
		c.draw.connect(func() -> void:
			painter.draw_layer(c, layer, -Vector2(x0, y0) * ts, x0 - int(mg[0]), y0 - int(mg[1]), x0 + CHUNK + int(mg[0]), y0 + CHUNK + int(mg[2])))
		vp.add_child(c)
		_bake.add_child(vp)
		spr.texture = vp.get_texture()
		spr.material = _premul  # 투명 바탕에 그린 그림은 색이 알파만큼 곱해져 있다
		entry["vp"] = vp
		baked += 1
	(_roots[layer] as Node2D).add_child(spr)
	_chunks[id] = entry


## 산·나무 겹은 그 조각(과 둘레)에 산·나무가 있을 때만 그린다.
func _worth(layer: String, cx: int, cy: int) -> bool:
	if layer == "ground" or layer == "grass":
		return true
	var id := "%s:%d:%d" % [layer, cx, cy]
	if _has.has(id):
		return _has[id]
	var m := painter.map
	var mg: Array = MARGIN[layer]
	var want := "^c" if layer == "mtn" else "T"
	var found := false
	for y in range(maxi(0, cy * CHUNK - int(mg[1])), mini(m.h, cy * CHUNK + CHUNK + int(mg[2]))):
		var row := m.rows[y]
		for x in range(maxi(0, cx * CHUNK - int(mg[0])), mini(m.w, cx * CHUNK + CHUNK + int(mg[0]))):
			if want.contains(row[x]):
				found = true
				break
		if found:
			break
	_has[id] = found
	return found


## 그림 파일 경로(.webp 또는 .png). 없으면 "".
func _find(layer: String, name: String) -> String:
	var key := layer + "/" + name
	if not _paths.has(key):
		var found := ""
		for ext in [".png", ".webp"]:  # 사람이 그린 .png가 지도 그리개(tools/map/paint)의 .webp보다 먼저
			var p: String = art_dir + "/" + key + ext
			if (p.begins_with("res://") and ResourceLoader.exists(p)) or (not p.begins_with("res://") and FileAccess.file_exists(p)):
				found = p
				break
		_paths[key] = found
	return _paths[key]


func _file(path: String) -> Texture2D:
	if not _files.has(path):
		if path.begins_with("res://"):
			_files[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
		else:  # user:// (가져오기 전 그림, 테스트)
			var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
			_files[path] = ImageTexture.create_from_image(img) if img else null
	return _files[path]


func _free(id: String) -> void:
	var e: Dictionary = _chunks[id]
	var p := String(e.get("path", ""))
	if p != "":  # 그림 파일도 더 쓰는 조각이 없으면 내려놓는다(폰 메모리)
		_refs[p] = int(_refs.get(p, 1)) - 1
		if int(_refs[p]) <= 0:
			_refs.erase(p)
			_files.erase(p)
	if e["sprite"]:
		(e["sprite"] as Node).queue_free()
	if e["vp"]:
		(e["vp"] as Node).queue_free()
	_chunks.erase(id)


## 오래 안 본 조각은 버린다(겹마다 KEEP개까지).
func _evict() -> void:
	if _chunks.size() <= KEEP * MapPainter.LAYERS.size():
		return
	var ids := _chunks.keys()
	ids.sort_custom(func(x: String, y: String) -> bool: return int(_chunks[x]["used"]) < int(_chunks[y]["used"]))
	for i in ids.size() - KEEP * MapPainter.LAYERS.size():
		if int(_chunks[ids[i]]["used"]) < _frame:
			_free(ids[i])
