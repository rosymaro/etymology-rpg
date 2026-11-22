class_name MinigameHubScreen
extends Screen
## 미니게임 메뉴: 10개를 보상 없이 바로 해 본다.


func open(_args: Dictionary) -> void:
	UiKit.fill_bg(self, UiKit.LEAF.lightened(0.4))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var v := UiKit.vbox(12)
	margin.add_child(v)
	var head := UiKit.hbox()
	var title := UiKit.label(t("ui.title.minigames"), 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.button(t("ui.common.back"), func() -> void: main.flow.go_title(), UiKit.PAPER, 22))
	v.add_child(head)
	v.add_child(UiKit.label(t("ui.mini.hub_note"), 20, UiKit.INK.lightened(0.25)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(UiKit.scroll(grid))
	for g in MinigameRegistry.games():
		var id: String = g["id"]
		var b := UiKit.button("%d. %s · %s\n%s" % [int(g["stage"]), t("name.stage.s%02d" % int(g["stage"])),
			t("name.minigame." + id), g["borrow"]], func() -> void: main.flow.play_minigame(id, "free"), UiKit.PAPER, 20)
		b.custom_minimum_size = Vector2(590, 84)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(b)
