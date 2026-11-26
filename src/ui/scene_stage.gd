class_name SceneStage
extends Control
## 대화 장면의 무대(사용자 의견: 이름·성별을 고르면 장면이 바뀌어 대장간에서 대화가 시작된다).
## 장면의 conti(data/scenes/*.json)를 따른다: 컷마다 bg(배경 자리), actors(인물과 화면 위 자리 %), say(그 컷의 대사 줄 수).
## 배경은 그린 지도(assets/map/ground)에서 그 자리(지도 spot)를 잘라 쓴다. 인물은 assets/art 그림(없으면 간단한 도형).

const SHOT_SCALE := {"wide": 0.8, "mid": 1.0, "close": 1.35}  ## 컷 크기: 멀리·중간·가까이
const ACTOR_H := 230.0  ## 중간 컷에서 인물 키(px)
const PIECE := Vector2(1024, 1536)  ## 지도 그림 한 장 크기

var _shots: Array = []
var _starts: Array[int] = []  ## 컷마다 시작하는 대사 번호
var _shot := -1
var _map: WorldMap
var _veil: ColorRect
var _cache := {}


func setup(scene: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map = WorldMap.load_default()
	var n := 0
	for c in scene.get("conti", []):
		_shots.append(c)
		_starts.append(n)
		n += int(c.get("say", 0))
	_veil = ColorRect.new()  # 컷이 바뀔 때 잠깐 어두워졌다 밝아진다
	_veil.color = Color(0.1, 0.08, 0.06, 0.0)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.offset_top = -UiKit.BG_BLEED
	_veil.offset_bottom = UiKit.BG_BLEED
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)


func has_shots() -> bool:
	return not _shots.is_empty()


## 대사 i번째 줄에 맞는 컷. 줄 수(say)가 0인 컷은 건너뛴다. 줄이 더 많으면 마지막 컷.
static func shot_for(starts: Array, shots: Array, i: int) -> int:
	var k := -1
	for j in shots.size():
		if int(shots[j].get("say", 0)) > 0 and int(starts[j]) <= i:
			k = j
	return k if k >= 0 else shots.size() - 1


func show_line(i: int) -> void:
	var k := shot_for(_starts, _shots, i)
	if k == _shot:
		return
	var first := _shot < 0
	_shot = k
	if first:
		queue_redraw()
		return
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 1.0, 0.25)
	tw.tween_callback(queue_redraw)
	tw.tween_property(_veil, "color:a", 0.0, 0.35)


func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


func _draw() -> void:
	if _shot < 0:
		return
	var c: Dictionary = _shots[_shot]
	var fx: Dictionary = c.get("fx", {})
	var k: float = SHOT_SCALE.get(String(c.get("shot", "mid")), 1.0)
	var full := Rect2(Vector2(0, -UiKit.BG_BLEED), Vector2(size.x, size.y + UiKit.BG_BLEED * 2))
	draw_rect(full, Color("3b2f2a"))
	var bg := String(c.get("bg", ""))
	var grey := fx.has("rootscut") or fx.has("grey")
	var tint := Color(0.62, 0.62, 0.7) if grey else Color.WHITE
	if bg != "":
		_draw_place(bg, k, full, tint)
	for a in c.get("actors", []):
		_draw_actor(a, k)


## 지도에서 그 자리(spot)를 가운데(조금 위)에 두고 잘라 그린다. k만큼 확대.
func _draw_place(bg: String, k: float, full: Rect2, tint: Color) -> void:
	var sp := _map.spot(1, bg)
	if sp == Vector2.INF:
		return
	var view := full.size / k
	var tl := sp - Vector2(view.x / 2.0, view.y * 0.42)
	var cx0 := floori(tl.x / PIECE.x)
	var cy0 := floori(tl.y / PIECE.y)
	for cy in range(cy0, floori((tl.y + view.y) / PIECE.y) + 1):
		for cx in range(cx0, floori((tl.x + view.x) / PIECE.x) + 1):
			var t := _tex("res://assets/map/ground/%d_%d.png" % [cx, cy])
			if t == null:
				t = _tex("res://assets/map/ground/%d_%d.webp" % [cx, cy])
			if t == null:
				continue
			var p0 := Vector2(cx, cy) * PIECE
			draw_texture_rect(t, Rect2(full.position + (p0 - tl) * k, Vector2(t.get_size()) * k), false, tint)


func _draw_actor(a: Dictionary, k: float) -> void:
	var id := String(a.get("id", ""))
	var foot := Vector2(float(a.get("x", 50)) / 100.0 * size.x, float(a.get("y", 70)) / 100.0 * size.y * 0.9)  # 대화 상자(아래 1/3) 위에 서게
	var h := ACTOR_H * k
	var drawn := false
	match id:
		"hero":
			var look := GameData.state.hero_look if GameData.state else "m"
			drawn = Art.draw_anim(self, "hero", look, "idle", foot, h)
		_:
			var u := GameData.UNIT_CHARS.find(id)
			if u >= 0:
				drawn = Art.draw_anim(self, "pal", "%02d" % (u + 1), "joy" if String(a.get("pose", "")) == "joy" else "idle", foot, h * 0.62)
			else:
				drawn = Art.draw_anim(self, "npc", id, "idle", foot, h * 1.05)
	if not drawn:  # 그림이 아직 없는 사람: 발밑 그림자, 둥근 몸과 얼굴(그림 파일에는 그림자가 들어 있다)
		draw_circle(foot + Vector2(0, -4), h * 0.18, Color(0, 0, 0, 0.18))
		var body := foot + Vector2(0, -h * 0.3)
		draw_circle(body, h * 0.22, Color("8a6a52"))
		draw_arc(body, h * 0.22, 0, TAU, 32, UiKit.INK, 3)
		var head := foot + Vector2(0, -h * 0.68)
		draw_circle(head, h * 0.17, Color("ffe3c4"))
		draw_arc(head, h * 0.17, 0, TAU, 32, UiKit.INK, 3)
		draw_circle(head + Vector2(-h * 0.06, 0), 3, UiKit.INK)
		draw_circle(head + Vector2(h * 0.06, 0), 3, UiKit.INK)
