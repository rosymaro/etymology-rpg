class_name NameScreen
extends Screen
## 주인공 모습(남·여)과 이름 입력(s01_intro의 game_note).

var _edit: LineEdit
var _look := "m"
var _look_btns := {}


func open(_args: Dictionary) -> void:
	UiKit.fill_bg(self, UiKit.PAPER)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var v := UiKit.vbox(20)
	c.add_child(v)
	v.add_child(UiKit.label(t("ui.name.look"), 30))
	var row := UiKit.hbox(24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for lk in ["m", "f"]:
		var b := UiKit.button(t("ui.name.look_" + lk), func() -> void: _pick(lk), UiKit.PAPER, 24)
		b.icon = Art.tex("hero", lk + "_idle_1")
		b.expand_icon = true
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(190, 260)
		row.add_child(b)
		_look_btns[lk] = b
	_pick("m")
	v.add_child(UiKit.label(t("ui.name.ask"), 34))
	_edit = LineEdit.new()
	_edit.max_length = 8
	_edit.placeholder_text = t("ui.name.placeholder")
	_edit.add_theme_font_size_override("font_size", 34)
	_edit.custom_minimum_size = Vector2(420, 72)
	_edit.add_theme_stylebox_override("normal", UiKit.box(Color.WHITE, 20))
	_edit.add_theme_stylebox_override("focus", UiKit.box(Color.WHITE, 20, 4))
	_edit.add_theme_color_override("font_color", UiKit.INK)
	_edit.add_theme_color_override("font_placeholder_color", Color(UiKit.INK, 0.4))
	_edit.add_theme_color_override("caret_color", UiKit.INK)
	v.add_child(_edit)
	v.add_child(UiKit.button(t("ui.common.ok"), _done, UiKit.LEAF))


func _done() -> void:
	var n := _edit.text.strip_edges()
	if n == "":
		n = t("ui.name.default")
	main.flow.name_entered(n, _look)


func _pick(lk: String) -> void:
	_look = lk
	for k in _look_btns:  # 고른 쪽은 살구색, 아닌 쪽은 크림
		var b: Button = _look_btns[k]
		var bg := UiKit.APRICOT if k == lk else UiKit.PAPER
		b.add_theme_stylebox_override("normal", UiKit.pill(bg))
		b.add_theme_stylebox_override("hover", UiKit.pill(bg.lightened(0.1)))
