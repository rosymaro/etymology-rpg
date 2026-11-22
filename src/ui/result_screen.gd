class_name ResultScreen
extends Screen
## 얻은 단어, 경험치, 레벨 업, 새 어근, 자동 장비를 보여 준다.


func open(args: Dictionary) -> void:
	UiKit.fill_bg(self, UiKit.PAPER)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var v := UiKit.vbox(12)
	margin.add_child(v)
	v.add_child(UiKit.label(t(args["title"]), 34))
	var list := UiKit.vbox(8)
	v.add_child(UiKit.scroll(list))
	var ups := {}
	var roots: Array[String] = []
	for ev in args["events"]:
		var w := GameData.repo.get_word(ev["word"])
		var line := "%s  %s  %s" % [w.id, w.meaning, t("ui.result.new") if ev["new"] else t("ui.result.dup")]
		if ev["equipped"] > 0:
			line += "  " + t("ui.result.equipped").format({"name": UiKit.unit_name(ev["equipped"])})
		var c := UiKit.card(UiKit.LEAF if ev["new"] else UiKit.SKY)
		c.add_child(UiKit.label(line, 22))
		list.add_child(c)
		for u in ev["level_ups"]:
			ups[u[0]] = u[2]
			EventBus.level_up.emit(u[0], u[2])
		for r in ev["roots"]:
			roots.append(r)
	for u in ups:
		if u in GameData.state.joined:
			list.add_child(UiKit.label(t("ui.result.level_up").format({"name": UiKit.unit_name(u), "level": ups[u]}), 24, UiKit.ACCENT.darkened(0.2)))
	for r in roots:
		list.add_child(UiKit.label(t("ui.result.new_root").format({"root": r}), 24, UiKit.ACCENT.darkened(0.2)))
	var done: Callable = args["done"]
	v.add_child(UiKit.button(t("ui.common.ok"), func() -> void: done.call(), UiKit.LEAF))
