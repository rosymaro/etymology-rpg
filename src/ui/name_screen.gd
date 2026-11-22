class_name NameScreen
extends Screen
## 주인공 이름 입력(s01_intro의 game_note).

var _edit: LineEdit


func open(_args: Dictionary) -> void:
	UiKit.fill_bg(self, UiKit.PAPER)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var v := UiKit.vbox(20)
	c.add_child(v)
	v.add_child(UiKit.label(t("ui.name.ask"), 34))
	_edit = LineEdit.new()
	_edit.max_length = 8
	_edit.placeholder_text = t("ui.name.placeholder")
	_edit.add_theme_font_size_override("font_size", 34)
	_edit.custom_minimum_size = Vector2(420, 72)
	v.add_child(_edit)
	v.add_child(UiKit.button(t("ui.common.ok"), _done, UiKit.LEAF))


func _done() -> void:
	var n := _edit.text.strip_edges()
	if n == "":
		n = t("ui.name.default")
	main.flow.name_entered(n)
