class_name UiKit
extends RefCounted
## 화면 공통 모양(art-direction.md): 둥근 카드, 크림 바탕, 통통하게 솟은 알약 버튼, 따뜻한 갈색 외곽선, 파스텔.
## 사용자 의견(레퍼런스 그림): 갈색 선, 크림색, 아이콘 달린 버튼, 둥근 글꼴(Jua).

const INK := Color("5c3a24")  ## 따뜻한 갈색 선·글씨
const PAPER := Color("fff6e3")  ## 크림
const SKY := Color("d4ecf5")
const LEAF := Color("d9f0bf")
const APRICOT := Color("ffdcae")
const PINK := Color("ffd6de")
const SHADOW := Color(0.36, 0.22, 0.12, 0.3)  ## 카드·버튼 아래 그림자
const FONT_PATH := "res://assets/fonts/Jua-Regular.ttf"
const ICON_DIR := "res://assets/ui/icons/"
const ACCENT := Color("f29e4c")  ## 주황: 효과·강조에만
const GRAY := Color("c9c4cf")
const GOOD := Color("6fbf73")
const BAD := Color("e07a7a")
const BG_BLEED := 800.0  ## 바탕색을 화면 밖 여백까지 넓히는 길이
## 엄지 자리: 자주 누르는 버튼(다음, 결과 보기, 확인 …)의 가운데를 화면(Main 틀) 아래에서 이만큼 위에 둔다.
## 조우 퀴즈 4지선다의 4번째 보기와 같은 높이다.
const THUMB_ROW := 220.0
const THUMB_H := 70.0


static func box(bg: Color, radius: int = 18, border: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = INK
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if border > 0:  # 아래로 살짝 그림자(떠 있는 카드)
		s.shadow_color = SHADOW
		s.shadow_size = 2
		s.shadow_offset = Vector2(0, 4)
	s.anti_aliasing = true
	return s


## 솟은 알약: 아래 테두리를 두껍게 해서 눌리는 버튼처럼 보인다. 눌린 모양은 아래 테두리가 얇아지고 글씨가 내려간다.
static func pill(bg: Color, radius: int = 30, pressed: bool = false) -> StyleBoxFlat:
	var s := box(bg, radius)
	s.border_width_bottom = 3 if pressed else 7
	s.content_margin_top = 13 if pressed else 9
	s.content_margin_bottom = 7 if pressed else 11
	s.shadow_offset = Vector2(0, 1 if pressed else 4)
	return s


## 아이콘 그림(assets/ui/icons/<이름>.png, tools/ui/make_icons.py). 없으면 null.
static func icon_tex(name: String) -> Texture2D:
	var p := ICON_DIR + name + ".png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


static func icon(name: String, px: float = 36.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon_tex(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## 아이콘 + 글씨 카드(위치, 할 일, 코인 …). 글씨 Label을 meta "label"에 둔다.
static func chip(icon_name: String, text: String, size: int = 22, bg: Color = PAPER, px: float = 34.0) -> PanelContainer:
	var c := card(bg)
	var st := box(bg, 22)
	st.content_margin_left = 10
	st.content_margin_right = 16
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	c.add_theme_stylebox_override("panel", st)
	var h := hbox(8)
	c.add_child(h)
	var ic := icon(icon_name, px)
	h.add_child(ic)
	var l := label(text, size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	c.set_meta("label", l)
	c.set_meta("icon", ic)
	return c

static func label(text: String, size: int = 26, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## 줄바꿈을 켠다. 폭이 정해진 자리(가득 찬 컨테이너, 또는 min_w)에서만 쓴다. 폭 없이 켜면 한 글자씩 세로로 쌓인다.
static func wrap(l: Label, min_w: float = 0.0) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if min_w > 0.0:
		l.custom_minimum_size.x = min_w
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## 버튼을 엄지 자리(THUMB_ROW)에 둔다. ax: 0 왼쪽, 0.5 가운데, 1 오른쪽. ox: 옆으로 비킬 만큼.
static func thumb(c: Control, ax: float = 0.5, ox: float = 0.0) -> void:
	c.custom_minimum_size.y = THUMB_H
	var side := 24.0 if ax <= 0.0 else (-24.0 if ax >= 1.0 else 0.0)
	pin(c, ax, 1, side + ox, -(THUMB_ROW - THUMB_H / 2.0))


## icon_name: 글씨 앞(또는 icon_top이면 위)에 붙는 아이콘(assets/ui/icons).
static func button(text: String, on_press: Callable, bg: Color = APRICOT, size: int = 26, icon_name: String = "", icon_top: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = icon_tex(icon_name)
		b.add_theme_constant_override("icon_max_width", int(size * (2.0 if icon_top else 1.45)))
		b.add_theme_constant_override("h_separation", 6)
		if icon_top:
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", GRAY)
	b.add_theme_stylebox_override("normal", pill(bg))
	b.add_theme_stylebox_override("hover", pill(bg.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", pill(bg.darkened(0.08), 30, true))
	b.add_theme_stylebox_override("disabled", pill(PAPER.darkened(0.04)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(120, 64)
	b.pressed.connect(on_press)
	return b


static func card(bg: Color = PAPER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg))
	# PanelContainer는 기본으로 누름을 삼킨다(STOP). 카드는 그림일 뿐이므로 뒤(부모)로 넘긴다.
	# 예: 대화 상자 위를 눌러도 대화가 넘어가야 한다.
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func fill_bg(parent: Control, color: Color = SKY) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.offset_top = -BG_BLEED  # 화면 위아래 여백(Main)까지 칠한다
	r.offset_bottom = BG_BLEED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## 화면 가장자리에 붙인다. ax·ay = 앵커(0 왼쪽/위, 0.5 가운데, 1 오른쪽/아래), ox·oy = 앵커에서 떨어진 거리.
## 오른쪽·아래에 붙이면 안쪽으로 자라게 한다.
static func pin(c: Control, ax: float, ay: float, ox: float, oy: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN if ax >= 1.0 else (Control.GROW_DIRECTION_BOTH if ax > 0.0 else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if ay >= 1.0 else (Control.GROW_DIRECTION_BOTH if ay > 0.0 else Control.GROW_DIRECTION_END)


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


## 유닛 이름: "뚝딱(만들기)"
static func unit_name(unit_no: int) -> String:
	return "%s(%s)" % [TranslationServer.translate("name.char." + GameData.UNIT_CHARS[unit_no - 1]),
		TranslationServer.translate("name.unit.%02d" % unit_no)]
