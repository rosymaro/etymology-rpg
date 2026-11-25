class_name PartyScreen
extends Screen
## 파티: 장착(07-fun 2절: 필드 마법 2, 전투 마법 덱 4, 유닛 어근)과 합류한 유닛의 레벨·능력치·장비 5칸.
## 칸을 누르면 고를 것이 나온다. 마법·어근 장착은 마을에서만 바꾼다(장비는 어디서나).

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


func _in_town() -> bool:
	return GameData.state.place == "town"


func _refresh() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var s := GameData.state
	_build_loadout()
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
			"coins": a.coins, "attr": attr_text}), 22)))
		var slots := HFlowContainer.new()  # 세로 화면: 넘치면 다음 줄
		slots.add_theme_constant_override("h_separation", 8)
		slots.add_theme_constant_override("v_separation", 8)
		for sl in Equipment.SLOTS:
			var slot: String = sl
			var cur := s.eq(u).get_in(sl)
			var b := UiKit.button("%s\n%s" % [t("name.slot." + sl), cur if cur != "" else "-"],
				func() -> void: _choose(unit, slot), UiKit.SKY, 18)
			b.custom_minimum_size = Vector2(196, 70)
			slots.add_child(b)
		col.add_child(slots)
		var root := Loadout.unit_root(s, GameData.rules, u)
		var rb := UiKit.button(t("ui.party.root").format({"root": root if root != "" else "-"}),
			func() -> void: _choose_root(unit), UiKit.ACCENT.lightened(0.5), 20)
		rb.disabled = not _in_town() or GameData.rules.equippable_roots(s, u).is_empty()
		col.add_child(rb)
		_detail.add_child(card)


## 장착: 필드 마법 2칸, 전투 마법 덱 4칸.
func _build_loadout() -> void:
	var s := GameData.state
	var card := UiKit.card(UiKit.APRICOT.lightened(0.5))
	var col := UiKit.vbox(6)
	card.add_child(col)
	col.add_child(UiKit.label(t("ui.party.loadout"), 24))
	if not _in_town():
		col.add_child(UiKit.label(t("ui.party.town_only"), 18, UiKit.BAD.darkened(0.2)))
	for kind in ["field", "deck"]:
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		row.add_child(UiKit.label(t("ui.party." + kind), 20))
		var slots: Array[String] = Loadout.field(s) if kind == "field" else Loadout.deck(s, GameData.rules)
		for i in slots.size():
			var k: int = i
			var kd: String = kind
			var id := slots[i]
			var b := UiKit.button(GameText.magic_name(id) if id != "" else t("ui.party.empty"),
				func() -> void: _choose_magic(kd, k), UiKit.PAPER, 18)
			b.custom_minimum_size = Vector2(150, 56)
			b.disabled = not _in_town()
			row.add_child(b)
		col.add_child(row)
	_detail.add_child(card)


func _choose_magic(kind: String, i: int) -> void:
	var s := GameData.state
	var owned: Array = s.magics if kind == "field" else GameData.rules.battle_magics(s)
	for c in _detail.get_children():
		c.queue_free()
	_detail.add_child(UiKit.label(t("ui.party.pick_" + kind), 24))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	_detail.add_child(flow)
	for m in owned:
		var id := String(m)
		var name := GameText.magic_name(id) if kind == "deck" else GameText.field_magic_name(id)
		flow.add_child(UiKit.button(name, func() -> void:
			if kind == "field":
				Loadout.set_field(s, i, id)
			else:
				Loadout.set_deck(s, GameData.rules, i, id)
			GameData.save()
			_refresh(), UiKit.SKY, 20))
	flow.add_child(UiKit.button(t("ui.party.empty"), func() -> void:
		if kind == "field":
			Loadout.set_field(s, i, "")
		else:
			Loadout.set_deck(s, GameData.rules, i, "")
		GameData.save()
		_refresh(), UiKit.PAPER, 20))
	flow.add_child(UiKit.button(t("ui.common.back"), _refresh, UiKit.PAPER, 20))


func _choose_root(unit: int) -> void:
	var s := GameData.state
	for c in _detail.get_children():
		c.queue_free()
	_detail.add_child(UiKit.label(t("ui.party.pick_root").format({"name": UiKit.unit_name(unit)}), 24))
	for r in GameData.rules.equippable_roots(s, unit):
		var root := String(r)
		var b := UiKit.button("%s — %s" % [root, GameText.root_desc(root)], func() -> void:
			Loadout.set_unit_root(s, GameData.rules, unit, root)
			GameData.save()
			_refresh(), UiKit.SKY, 18)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_detail.add_child(b)
	_detail.add_child(UiKit.button(t("ui.common.back"), _refresh, UiKit.PAPER, 20))


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
		flow.add_child(WordCard.make(w, t("ui.dex.tier").format({"tier": w.tier}), 20, func() -> void:
			s.eq(unit).put(slot, id)
			GameData.save()
			_refresh()))
	flow.add_child(UiKit.button(t("ui.common.back"), _refresh, UiKit.PAPER, 20))
