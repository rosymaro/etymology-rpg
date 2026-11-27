class_name Art
extends RefCounted
## 그림 파일 찾기(04-meta.md 4절). res://assets/art/<종류>/<id>.png가 있으면 그림을, 없으면 null을 돌려준다.
## 화면은 null이면 지금처럼 도형으로 그린다. 그래서 그림이 하나씩 생길 때마다 그 자리만 바뀐다.
## 목록과 크기는 assets/art/README.md, AI 프롬프트는 assets/art/PROMPTS.md.

static var _cache: Dictionary = {}


static func tex(kind: String, id: String) -> Texture2D:
	var path := "res://assets/art/%s/%s.png" % [kind, id]
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = t
	return t


## 가운데 center, 크기 size로 그림을 그린다. 그림이 없으면 false(도형으로 그리라는 뜻).
static func draw(ci: CanvasItem, kind: String, id: String, center: Vector2, size: Vector2, modulate: Color = Color.WHITE) -> bool:
	var t := tex(kind, id)
	if t == null:
		return false
	ci.draw_texture_rect(t, Rect2(center - size / 2, size), false, modulate)
	return true


## 움직이는 그림: <id>_<동작>_1.png, _2.png … 를 차례로(초당 fps장). 그 동작이 없으면 idle, 그것도 없으면 <id>.png.
## 사용자가 준 캐릭터 시트를 tools/art/cut_sprites.py가 잘라 넣는다.
static func frames(kind: String, id: String, anim: String) -> Array:
	var key := "%s/%s:%s" % [kind, id, anim]
	if _cache.has(key):
		return _cache[key]
	var out: Array = []
	var n := 1
	while true:
		var t := tex(kind, "%s_%s_%d" % [id, anim, n])
		if t == null:
			break
		out.append(t)
		n += 1
	if out.is_empty() and anim != "idle":
		out = frames(kind, id, "idle")
	if out.is_empty() and tex(kind, id) != null:
		out = [tex(kind, id)]
	_cache[key] = out
	return out


## 발끝 foot(아래 가운데)에 높이 h로 그린다(비율 유지). flip이면 좌우를 뒤집는다. 그림이 없으면 false.
## sink: 0~1, 발밑 땅속으로 그만큼 가라앉은 모습(위쪽만 땅 위에 보인다. de- 땅속 숨기).
static func draw_anim(ci: CanvasItem, kind: String, id: String, anim: String, foot: Vector2, h: float, flip: bool = false, fps: float = 6.0, modulate: Color = Color.WHITE, sink: float = 0.0) -> bool:
	var fr := frames(kind, id, anim)
	if fr.is_empty():
		return false
	if sink >= 1.0:
		return true
	var t: Texture2D = fr[int(Time.get_ticks_msec() / 1000.0 * fps) % fr.size()]
	var sz := Vector2(h * float(t.get_width()) / float(t.get_height()), h)
	ci.draw_set_transform(foot, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	if sink > 0.0:
		var keep := 1.0 - sink
		ci.draw_texture_rect_region(t, Rect2(Vector2(-sz.x / 2.0, -sz.y * keep), Vector2(sz.x, sz.y * keep)),
			Rect2(Vector2.ZERO, Vector2(t.get_width(), t.get_height() * keep)), modulate)
	else:
		ci.draw_texture_rect(t, Rect2(Vector2(-sz.x / 2.0, -sz.y), sz), false, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


## 카드·버튼 안에 넣는 그림(없으면 빈 노드 대신 null).
static func rect(kind: String, id: String, size: Vector2) -> TextureRect:
	var t := tex(kind, id)
	if t == null:
		return null
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
