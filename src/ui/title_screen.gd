class_name TitleScreen
extends Screen
## 처음 화면: 스토리 모드 / 개발자 모드(스토리, 모든 단어를 갖추고 평가용) / 미니게임(보상 없이) / 옵션.


func open(_args: Dictionary) -> void:
	UiKit.fill_bg(self, UiKit.SKY)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var v := UiKit.vbox(16)
	c.add_child(v)
	var title := UiKit.label(t("ui.title.name"), 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UiKit.label(t("ui.title.sub"), 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	GameData.use_dev_save(false)
	var has_save := GameData.save_store.exists()
	var story := UiKit.vbox(12)  # 세로 화면: 위아래로
	if has_save:
		story.add_child(UiKit.button(t("ui.title.story_continue"), func() -> void: main.flow.continue_game(), UiKit.LEAF))
	story.add_child(UiKit.button(t("ui.title.story_new"), func() -> void:
		if has_save:
			main.notice(t("ui.title.new_confirm"), func() -> void: main.flow.new_game())
		else:
			main.flow.new_game(), UiKit.LEAF if not has_save else UiKit.APRICOT))
	v.add_child(story)
	v.add_child(UiKit.button(t("ui.title.dev"), func() -> void: main.flow.dev_game(), UiKit.PINK))
	var note := UiKit.wrap(UiKit.label(t("ui.title.dev_note"), 18, UiKit.INK.lightened(0.3)), 520)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	v.add_child(UiKit.button(t("ui.title.minigames"), func() -> void: main.flow.go_minigames(), UiKit.APRICOT))
	v.add_child(UiKit.button(t("ui.option.title"), func() -> void: main.flow.go_options(main.flow.go_title), UiKit.PAPER))
