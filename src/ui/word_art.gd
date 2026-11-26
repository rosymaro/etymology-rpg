class_name WordArt
extends Control
## 카드의 그림 자리(사용자 의견: 전투 카드·누르고 있을 때 창·도감에 그림 자리. 그림은 나중에 직접 채운다).
## 먼저 찾는 그림: 단어 assets/art/word/<단어>.png → 어원 assets/art/root/<어원 형태>.png.
## 그림이 없으면 뜻으로 고른 임시 도형(WordPicture, data/art/word_pictures.json). 그것도 없으면 어원 글자 무늬.
## 유닛 카드면 유닛 그림(assets/art/unit/uNN.png), 없으면 필드 동행 도형(PalArt).

static var _wp: WordPicture

var word: WordData
var unit := 0
var _pick := {}
var _tex: Texture2D
var _font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 120)


static func picker() -> WordPicture:
	if _wp == null:
		_wp = WordPicture.load_default()
	return _wp


func set_word(w: WordData) -> void:
	word = w
	unit = 0
	_tex = null
	_pick = {}
	if w:
		_tex = Art.tex("word", w.id)
		if _tex == null:
			for e in w.etym:
				if not String(e.get("root", "")).ends_with("-"):
					_tex = Art.tex("root", String(e.get("form", "")))
					if _tex:
						break
		_pick = picker().pick(w.meaning, w.etym)
	queue_redraw()


func set_unit(n: int) -> void:
	unit = n
	word = null
	_tex = Art.tex("unit", "u%02d" % n)
	queue_redraw()


func _bg_color() -> Color:
	if word and not word.attrs.is_empty():
		return MinigameScreen.attr_color(int(word.attrs[0])).lerp(Color.WHITE, 0.55)
	if unit > 0:
		return PalArt.color(unit).lerp(Color.WHITE, 0.6)
	return UiKit.PAPER


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := UiKit.box(_bg_color(), 14, 3)
	sb.shadow_size = 0
	draw_style_box(sb, r)
	var inner := r.grow(-8)
	if _tex:
		var ts := Vector2(_tex.get_size())
		var k := minf(inner.size.x / ts.x, inner.size.y / ts.y)
		draw_texture_rect(_tex, Rect2(inner.get_center() - ts * k / 2.0, ts * k), false)
		return
	if unit > 0:
		var k := minf(inner.size.x, inner.size.y) / (PalArt.R * 3.4)
		draw_set_transform(inner.get_center() + Vector2(0, PalArt.R * 0.2 * k), 0.0, Vector2(k, k))
		PalArt.draw(self, unit, Vector2.ZERO, Vector2.RIGHT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if word == null:
		return
	var side := minf(inner.size.x, inner.size.y) * 0.86
	var box := Rect2(inner.get_center() - Vector2(side, side) / 2.0, Vector2(side, side))
	var g := String(_pick.get("glyph", ""))
	if g != "":
		_draw_shapes(picker().shapes(g), box)
	else:
		_draw_emblem(box)
	var m := String(_pick.get("mod", ""))
	if m != "":  # 접두사 표시: 오른쪽 위 작은 동그라미
		var bs := side * 0.36
		var bp := Vector2(inner.end.x - bs * 0.5, inner.position.y + bs * 0.5)
		draw_circle(bp, bs * 0.58, Color.WHITE)
		draw_arc(bp, bs * 0.58, 0, TAU, 32, UiKit.INK, 2.5, true)
		_draw_shapes(picker().shapes(m), Rect2(bp - Vector2(bs, bs) * 0.4, Vector2(bs, bs) * 0.8))


## 뜻 그림이 없는 단어: 어원 형태 글자(예: dict)를 둥근 무늬 안에
func _draw_emblem(box: Rect2) -> void:
	var form := word.id.substr(0, 4)
	for e in word.etym:
		if not String(e.get("root", "")).ends_with("-") and String(e.get("form", "")) != "":
			form = String(e.get("form", ""))
			break
	var c := box.get_center()
	var rad := box.size.x * 0.42
	var col := MinigameScreen.attr_color(int(word.attrs[0])) if not word.attrs.is_empty() else UiKit.GRAY
	draw_circle(c, rad, col.lerp(Color.WHITE, 0.25))
	draw_arc(c, rad, 0, TAU, 48, UiKit.INK, 3, true)
	draw_arc(c, rad * 0.82, 0, TAU, 48, Color(1, 1, 1, 0.7), 2, true)
	if _font == null:
		_font = ThemeDB.fallback_font
	var fs := int(clampf(rad * 1.6 / maxf(1.0, form.length() * 0.62), 14, rad * 0.9))
	draw_string(_font, Vector2(c.x - rad, c.y + fs * 0.35), form, HORIZONTAL_ALIGNMENT_CENTER, rad * 2, fs, UiKit.INK)


## 100×100 도형 목록(WordPicture)을 box에 그린다. 칠한 도형은 갈색 외곽선.
func _draw_shapes(list: Array, box: Rect2) -> void:
	var k := box.size.x / 100.0
	var o := box.position
	var lw := maxf(1.5, 3.0 * k)
	for sh in list:
		var t := String(sh[0])
		match t:
			"c":
				var c := o + Vector2(float(sh[1]), float(sh[2])) * k
				var rr := float(sh[3]) * k
				if sh[4] != null:
					draw_circle(c, rr, Color(String(sh[4])))
				draw_arc(c, rr, 0, TAU, 32, UiKit.INK, lw, true)
			"e":
				var pts := PackedVector2Array()
				for i in 28:
					var a := TAU * i / 28.0
					pts.append(o + (Vector2(float(sh[1]), float(sh[2])) + Vector2(cos(a) * float(sh[3]), sin(a) * float(sh[4]))) * k)
				_poly(pts, Color(String(sh[5])), lw)
			"r":
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color(String(sh[6]))
				sb.border_color = UiKit.INK
				sb.set_border_width_all(int(maxf(1.0, lw)))
				sb.set_corner_radius_all(int(float(sh[5]) * k))
				sb.anti_aliasing = true
				draw_style_box(sb, Rect2(o + Vector2(float(sh[1]), float(sh[2])) * k, Vector2(float(sh[3]), float(sh[4])) * k))
			"p":
				var pts := PackedVector2Array()
				var a: Array = sh[1]
				for i in range(0, a.size(), 2):
					pts.append(o + Vector2(float(a[i]), float(a[i + 1])) * k)
				_poly(pts, Color(String(sh[2])), lw)
			"l":
				var pts := PackedVector2Array()
				var a: Array = sh[1]
				for i in range(0, a.size(), 2):
					pts.append(o + Vector2(float(a[i]), float(a[i + 1])) * k)
				draw_polyline(pts, Color(String(sh[3])), float(sh[2]) * k, true)


func _poly(pts: PackedVector2Array, col: Color, lw: float) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():  # 자기 교차 등 칠할 수 없는 모양은 선만
		pass
	else:
		draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, UiKit.INK, lw, true)
