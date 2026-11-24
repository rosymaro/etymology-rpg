class_name UiKit
extends RefCounted
## 화면 공통 모양(art-direction.md): 둥근 카드, 종이 바탕, 통통한 알약 버튼, 남보라 외곽선, 파스텔.

const INK := Color("4b3f72")  ## 남보라 선
const PAPER := Color("fbf6ec")
const SKY := Color("cfe8f3")
const LEAF := Color("cfe9c4")
const APRICOT := Color("f8d9c0")
const PINK := Color("f6d3dc")
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
	return s


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


static func button(text: String, on_press: Callable, bg: Color = APRICOT, size: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", GRAY)
	b.add_theme_stylebox_override("normal", box(bg, 30))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.15), 30))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.1), 30))
	b.add_theme_stylebox_override("disabled", box(PAPER, 30))
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
