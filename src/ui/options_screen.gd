class_name OptionsScreen
extends Screen
## 옵션(04-meta.md 2절): 진동 켜기/끄기, 효과음·배경음악 켜기/끄기 + 음량, 지도 효과 하나씩 끄기, FPS 표시.

var _back: Callable


func open(args: Dictionary) -> void:
	_back = args.get("back", Callable())
	UiKit.fill_bg(self, UiKit.PAPER)
	var sc := ScrollContainer.new()  # 지도 효과 스위치가 늘어 작은 폰에서는 넘친다
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var c := CenterContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(c)
	var card := UiKit.card()
	card.custom_minimum_size = Vector2(660, 0)
	c.add_child(card)
	var v := UiKit.vbox(18)
	card.add_child(v)
	v.add_child(UiKit.label(t("ui.option.title"), 38))
	var s := GameData.settings
	v.add_child(_toggle("ui.option.vibration", s.vibration, func(on: bool) -> void: s.vibration = on))
	v.add_child(_toggle("ui.option.sfx", s.sfx, func(on: bool) -> void: s.sfx = on))
	v.add_child(_slider(s.sfx_volume, func(x: float) -> void: s.sfx_volume = x))
	v.add_child(_toggle("ui.option.bgm", s.bgm, func(on: bool) -> void: s.bgm = on))
	v.add_child(_slider(s.bgm_volume, func(x: float) -> void: s.bgm_volume = x))
	v.add_child(_toggle("ui.option.touch_marker", s.touch_marker, func(on: bool) -> void: s.touch_marker = on))
	var head := UiKit.label(t("ui.option.map_fx"), 30)  # 지도 효과: 폰이 버벅이면 하나씩 끈다
	v.add_child(head)
	v.add_child(UiKit.wrap(UiKit.label(t("ui.option.map_fx_hint"), 22), 600))
	for k in SettingsStore.MAP_KEYS:
		var key: String = k
		v.add_child(_toggle("ui.option." + key, bool(s.get(key)), func(on: bool) -> void: s.set(key, on)))
	v.add_child(UiKit.button(t("ui.options.tutorial_again"), func() -> void:  # 08-tutorial.md
		TutorialBook.reset_all(GameData.state)
		GameData.save()
		main.notice(t("ui.options.tutorial_reset")), UiKit.PAPER))
	v.add_child(UiKit.button(t("ui.options.to_title"), func() -> void:  # 사용자 의견: 처음 화면으로
		for ov in main._overlay.get_children():
			ov.queue_free()
		if GameData.state:
			GameData.save()
		main.flow.go_title(), UiKit.PAPER))
	v.add_child(UiKit.button(t("ui.common.back"), _close))


func _toggle(key: String, on: bool, set_value: Callable) -> Control:
	var h := UiKit.hbox()
	var l := UiKit.label(t(key), 30)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b := CheckButton.new()
	b.button_pressed = on
	b.text = t("ui.option.on") if on else t("ui.option.off")
	b.add_theme_font_size_override("font_size", 26)
	for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, UiKit.INK)
	b.toggled.connect(func(x: bool) -> void:
		set_value.call(x)
		b.text = t("ui.option.on") if x else t("ui.option.off")
		GameData.settings.save_settings()
		EventBus.settings_changed.emit()
		if x and key == "ui.option.vibration":
			GameData.vibrate())
	h.add_child(b)
	return h


func _slider(value: float, set_value: Callable) -> Control:
	var h := UiKit.hbox()
	h.add_child(UiKit.label(t("ui.option.volume"), 22))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = value
	sl.custom_minimum_size = Vector2(360, 40)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(x: float) -> void:
		set_value.call(x)
		GameData.settings.save_settings()
		EventBus.settings_changed.emit())
	h.add_child(sl)
	return h


func _close() -> void:
	if _back.is_valid():
		_back.call()
	else:
		main.flow.go_title()
