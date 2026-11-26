class_name BattleSkin
extends RefCounted
## 전투 화면 모양(사용자 레퍼런스: 밤의 마법 서재, 금테 양피지 카드, 금테 알약, 고풍스러운 코인).
## 그림은 tools/ui/battle_art.py가 만든다(assets/ui/battle). 그림이 없으면 null을 돌려주고 화면은 원래 모양을 쓴다.

const DIR := "res://assets/ui/battle/"
const GOLD_TEXT := Color("ffe9a8")  ## 어두운 바탕 위 글씨(금빛)
const CREAM := Color("fff4dc")
const OUTLINE := Color("2a1a0c")


static func tex(name: String) -> Texture2D:
	var p := DIR + name
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


## 9-patch 틀. m: 그림 둘레에서 늘리지 않는 폭, pad: 글자와 틀 사이
static func box(name: String, m: Vector4, pad: Vector4, tint: Color = Color.WHITE) -> StyleBox:
	var t := tex(name)
	if t == null:
		return null
	var s := StyleBoxTexture.new()
	s.texture = t
	s.texture_margin_left = m.x
	s.texture_margin_top = m.y
	s.texture_margin_right = m.z
	s.texture_margin_bottom = m.w
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	s.modulate_color = tint
	return s


static func card_box() -> StyleBox:
	return box("card.png", Vector4(60, 60, 60, 60), Vector4(18, 16, 18, 16))


static func pill_box(dark := false, tint: Color = Color.WHITE) -> StyleBox:
	return box("pill_dark.png" if dark else "pill.png", Vector4(40, 38, 40, 38), Vector4(22, 10, 22, 12), tint)


## 금테 알약 버튼(글씨는 갈색, 어두운 버튼은 금빛)
static func style_button(b: Button, dark := false, tint: Color = Color.WHITE) -> void:
	var n := pill_box(dark, tint)
	if n == null:
		return
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", pill_box(dark, tint.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", pill_box(dark, tint.darkened(0.15)))
	b.add_theme_stylebox_override("disabled", pill_box(dark, tint.darkened(0.45)))
	b.add_theme_color_override("font_disabled_color", Color(0.25, 0.2, 0.15) if not dark else Color(0.6, 0.55, 0.45))
	var fc := GOLD_TEXT if dark else UiKit.INK
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, fc)


## 어두운 바탕 위 글씨: 금빛 + 진한 테두리
static func glow_label(l: Label, col: Color = GOLD_TEXT) -> void:
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 8)


## 화면 바탕(위아래 여백까지 덮는다)
static func fill_bg(parent: Control) -> bool:
	var t := tex("bg.webp")
	if t == null:
		return false
	UiKit.fill_bg(parent, Color("140f2c"))  # 화면 위아래 여백은 그림 끝 색으로
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return true
