class_name TitleScreen
extends Screen
## 타이틀: 새 게임 / 이어하기 / 옵션.


func open(_args: Dictionary) -> void:
	UiKit.fill_bg(self, UiKit.SKY)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var v := UiKit.vbox(20)
	c.add_child(v)
	var title := UiKit.label(t("ui.title.name"), 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UiKit.label(t("ui.title.sub"), 26)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var has_save := GameData.save_store.exists()
	if has_save:
		v.add_child(UiKit.button(t("ui.title.continue"), func() -> void: main.flow.continue_game(), UiKit.LEAF))
	v.add_child(UiKit.button(t("ui.title.new"), func() -> void:
		if has_save:
			_confirm_new()
		else:
			main.flow.new_game()))
	v.add_child(UiKit.button(t("ui.option.title"), func() -> void: main.flow.go_options(main.flow.go_title), UiKit.PINK))


func _confirm_new() -> void:
	main.notice(t("ui.title.new_confirm"), func() -> void: main.flow.new_game())
