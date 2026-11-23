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
