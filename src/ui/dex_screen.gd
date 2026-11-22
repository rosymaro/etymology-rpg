class_name DexScreen
extends Screen
## 도감: 얻은 단어를 얻은 곳(필드·마을·진화·보스)별로 보여 준다. 누르면 뜻·어원·예문(01-rpg-base '도감').

var _detail: Label


func open(_args: Dictionary) -> void:
	UiKit.fill_bg(self, UiKit.PAPER)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := UiKit.hbox(16)
	margin.add_child(root)
	var left := UiKit.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	root.add_child(left)
	var head := UiKit.hbox()
	var s := GameData.state
	var title := UiKit.label(t("ui.dex.title").format({"count": s.dex_count()}), 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.button(t("ui.common.back"), func() -> void: main.flow.go_field(), UiKit.PAPER, 22))
	left.add_child(head)
	var list := UiKit.vbox(6)
	left.add_child(UiKit.scroll(list))
	var groups := {"field": [], "town": [], "evolved": [], "boss": []}
	var ids := s.dex.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return s.dex[a] < s.dex[b])
	for id in ids:
		var w := GameData.repo.get_word(id)
		if w == null:
			continue
		var g := "evolved" if w.tier >= 2 else ("boss" if w.tier == 0 else w.obtain)
		groups[g].append(w)
	for g in ["field", "town", "evolved", "boss"]:
		if groups[g].is_empty():
			continue
		list.add_child(UiKit.label(t("ui.dex.group." + g) + " (%d)" % groups[g].size(), 24, UiKit.ACCENT.darkened(0.25)))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		list.add_child(flow)
		for w in groups[g]:
			var word: WordData = w
			var b := UiKit.button(word.id, func() -> void: _show(word), UiKit.SKY, 20)
			b.custom_minimum_size = Vector2(0, 50)
			flow.add_child(b)
	var right := UiKit.card()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	_detail = UiKit.wrap(UiKit.label(t("ui.dex.pick"), 24), 420)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(UiKit.scroll(_detail))


func _show(w: WordData) -> void:
	var parts: Array[String] = []
	for e in w.etym:
		parts.append("%s = %s" % [e.get("root", ""), e.get("meaning", "")])
	var ex: Dictionary = w.example
	var attrs: Array[String] = []
	for a in w.attrs:
		attrs.append(t("name.attr.%02d" % a))
	var tier := t("ui.dex.tier_boss") if w.tier == 0 else t("ui.dex.tier").format({"tier": w.tier})
	var gear := "" if w.unit == 0 else t("ui.dex.gear").format({"unit": UiKit.unit_name(w.unit), "slot": t("name.slot." + w.slot)})
	_detail.text = "%s  %s\n%s\n\n%s\n%s\n\n%s\n%s\n\n%s · %s\n%s" % [w.id, w.ipa, w.meaning,
		t("ui.dex.etym"), "\n".join(parts), ex.get("en", ""), ex.get("ko", ""), tier, " / ".join(attrs), gear]
