class_name EvolveScreen
extends Screen
## 대장간 용광로: 진화할 수 있는 단어 목록. 고르면 진화 퀴즈(02-rpg-v2 '진화'). 다시 잡을 단어도 보여 준다.

const MAX_TIER_STAGE1 := 2  ## 스테이지 1 범위는 2차까지(04-meta.md 6절)


func open(_args: Dictionary) -> void:
	UiKit.fill_bg(self, UiKit.APRICOT.lightened(0.5))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var v := UiKit.vbox(12)
	margin.add_child(v)
	var head := UiKit.hbox()
	var title := UiKit.label(t("ui.evolve.title"), 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.button(t("ui.common.back"), func() -> void: main.flow.go_field(), UiKit.PAPER, 22))
	v.add_child(head)
	var list := UiKit.vbox(8)
	v.add_child(UiKit.scroll(list))
	var s := GameData.state
	var avail := GameData.evolution.available(s, MAX_TIER_STAGE1)
	if avail.is_empty():
		list.add_child(UiKit.label(t("ui.evolve.none"), 24))
	for w in avail:
		var id := w.id
		var row := UiKit.hbox()
		row.add_child(WordCard.make(w, "", 22))
		var info := UiKit.label(t("ui.evolve.row").format({"word": w.id, "mats": " + ".join(w.mats),
			"unit": UiKit.unit_name(w.unit), "slot": t("name.slot." + w.slot)}), 22)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.clip_text = true
		row.add_child(info)
		row.add_child(UiKit.button(t("ui.evolve.go"), func() -> void: main.flow.evolve_quiz(id), UiKit.ACCENT.lightened(0.35), 22))
		var c := UiKit.card()
		c.add_child(row)
		list.add_child(c)
	for evo in s.recapture:
		list.add_child(UiKit.label(t("ui.evolve.recapture").format({"word": evo, "target": s.recapture[evo]}), 22, UiKit.BAD.darkened(0.2)))
