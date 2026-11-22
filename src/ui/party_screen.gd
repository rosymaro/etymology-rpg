class_name PartyScreen
extends Screen
## 파티: 합류한 유닛의 레벨·능력치·장비 5칸. 칸을 누르면 그 유닛·부위의 가진 단어로 바꿔 입는다.

var _detail: VBoxContainer


func open(_args: Dictionary) -> void:
	UiKit.fill_bg(self, UiKit.LEAF.lightened(0.4))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var v := UiKit.vbox(10)
	margin.add_child(v)
	var head := UiKit.hbox()
	var title := UiKit.label(t("ui.party.title"), 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.button(t("ui.common.back"), func() -> void: main.flow.go_field(), UiKit.PAPER, 22))
	v.add_child(head)
	_detail = UiKit.vbox(10)
	v.add_child(UiKit.scroll(_detail))
	_refresh()


func _refresh() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var s := GameData.state
	for u in s.joined:
		var unit: int = u
		var lv := GameData.rules.level(s, u)
		var f := GameData.setup.factory
		var a := f.ally(s, u, "")
		var card := UiKit.card()
		var col := UiKit.vbox(6)
		card.add_child(col)
		var attr := AttributeResolver.new().resolve(s.eq(u), GameData.repo)
		var attr_text := t("ui.party.attr_off") if attr["tier"] == 0 else t("ui.party.attr").format(
			{"attr": t("name.attr.%02d" % attr["attr"]), "count": attr["count"]})
		col.add_child(UiKit.wrap(UiKit.label(t("ui.party.unit").format({"name": UiKit.unit_name(u), "level": lv,
			"exp": s.unit_exp[u - 1], "atk": a.base.atk, "def": a.base.def, "hp": a.base.hp,
			"coins": a.coins, "attr": attr_text}), 22), 1100))
		var slots := UiKit.hbox(8)
		for sl in Equipment.SLOTS:
			var slot: String = sl
			var cur := s.eq(u).get_in(sl)
			var b := UiKit.button("%s\n%s" % [t("name.slot." + sl), cur if cur != "" else "-"],
				func() -> void: _choose(unit, slot), UiKit.SKY, 18)
			b.custom_minimum_size = Vector2(170, 70)
			slots.add_child(b)
		col.add_child(slots)
		_detail.add_child(card)


func _choose(unit: int, slot: String) -> void:
	var s := GameData.state
	var opts: Array[WordData] = []
	for id in s.dex:
		var w := GameData.repo.get_word(id)
		if w and w.unit == unit and w.slot == slot:
			opts.append(w)
	opts.sort_custom(func(a: WordData, b: WordData) -> bool: return a.tier > b.tier)
	for c in _detail.get_children():
		c.queue_free()
	_detail.add_child(UiKit.label(t("ui.party.choose").format({"name": UiKit.unit_name(unit), "slot": t("name.slot." + slot)}), 24))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	_detail.add_child(flow)
	for w in opts:
		var id := w.id
		flow.add_child(UiKit.button("%s (%s)" % [w.id, t("ui.dex.tier").format({"tier": w.tier})], func() -> void:
			s.eq(unit).put(slot, id)
			GameData.save()
			_refresh(), UiKit.APRICOT, 20))
	flow.add_child(UiKit.button(t("ui.common.back"), _refresh, UiKit.PAPER, 20))
