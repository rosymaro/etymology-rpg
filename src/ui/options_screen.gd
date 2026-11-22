class_name OptionsScreen
extends Screen
## 옵션(04-meta.md 2절): 진동 켜기/끄기, 효과음·배경음악 켜기/끄기 + 음량.

var _back: Callable


func open(args: Dictionary) -> void:
	_back = args.get("back", Callable())
	UiKit.fill_bg(self, UiKit.PAPER)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var card := UiKit.card()
	card.custom_minimum_size = Vector2(720, 0)
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
	b.add_theme_color_override("font_color", UiKit.INK)
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
