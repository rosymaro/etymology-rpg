class_name PartyScreen
extends Screen
## 파티: 장착(07-fun 2절: 필드 마법 2, 전투 마법 덱 4, 유닛 어근)과 합류한 유닛의 레벨·능력치·장비 5칸.
## 칸을 누르면 고를 것이 나온다. 마법·어근 장착은 마을에서만 바꾼다(장비는 어디서나).

var _detail: VBoxContainer
var _start: Array[int] = []  ## 이 화면을 열 때의 동행(닫을 때 바뀌었으면 레벨을 이어 주고 말을 한다)


func open(_args: Dictionary) -> void:
	_start = Loadout.companions(GameData.state)
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
	head.add_child(UiKit.button(t("ui.common.back"), _leave, UiKit.PAPER, 22))
	v.add_child(head)
	_detail = UiKit.vbox(10)
	v.add_child(UiKit.scroll(_detail))
	_refresh()
	_tutorial.call_deferred()


var _first_root_btn: Button
var _comp_lbl: Label
var _loadout_card: Control


## 처음 유닛 창(08-tutorial.md): 장착 칸 → 유닛 어근 버튼 누르기 → (고르는 화면에서) 어근 하나 고르기.
func _tutorial() -> void:
	await get_tree().process_frame
	var steps: Array[Dictionary] = [{"target": _loadout_card, "text": "tut.party.loadout", "mode": "any"}]
	if _first_root_btn and not _first_root_btn.disabled:
		steps.append({"target": _first_root_btn, "text": "tut.party.root", "mode": "tap"})
	elif not _in_town():
		steps.append({"target": _loadout_card, "text": "tut.party.town", "mode": "any"})
	TutorialOverlay.run(self, "party", steps)


## 나갈 때: 동행이 바뀌었으면(마을 여관에서만) 빠진 동행의 사냥 레벨을 새 동행이 이어받고, 주인공이 말한다.
func _leave() -> void:
	var now := Loadout.companions(GameData.state)
	if now == _start:
		main.flow.go_field()
		return
	var gone := _start.filter(func(u: int) -> bool: return not u in now)
	var came := now.filter(func(u: int) -> bool: return not u in _start)
	var got := GameData.hunt_run().swap_units(now)
	GameData.save()
	main.flow.go_field()
	if not gone.is_empty() or not came.is_empty():
		main.notice(GameText.companion_swap(gone, came, got))


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
		var head := UiKit.hbox(10)  # 이름 왼쪽에 동행 버튼
		var on := unit in Loadout.companions(s)
		var cb := UiKit.button(t("ui.party.with_on" if on else "ui.party.with_off"), func() -> void:
			if Loadout.toggle_companion(s, unit):
				GameData.save()
				_refresh()
			else:
				main.notice(t("ui.party.companions_one" if unit in Loadout.companions(s) else "ui.party.companions_full").format({"n": Loadout.max_companions()})),
			UiKit.ACCENT.lightened(0.3) if on else UiKit.PAPER, 18)
		cb.custom_minimum_size = Vector2(110, 52)
		cb.disabled = not _in_town()
		head.add_child(cb)
		head.add_child(UiKit.wrap(UiKit.label(t("ui.party.unit").format({"name": t("name.char." + GameData.UNIT_CHARS[u - 1]), "level": lv,
			"exp": s.unit_exp[u - 1], "atk": a.base.atk, "def": a.base.def, "hp": a.base.hp,
			"coins": a.coins, "attr": attr_text}), 22)))
		col.add_child(head)
		var wid := GameData.hunt_run().weapon_of(unit)  # 필드에서 무엇으로 공격하는지
		col.add_child(UiKit.wrap(UiKit.label(t("ui.party.field_attack").format({"w": t("ui.hunt.weapon." + wid)}), 18, PalArt.color(unit).darkened(0.45))))
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
		if _first_root_btn == null or not is_instance_valid(_first_root_btn) or (_first_root_btn.disabled and not rb.disabled):
			_first_root_btn = rb
		_detail.add_child(card)


## 장착: 필드 마법 2칸, 전투 마법 덱 4칸.
func _build_loadout() -> void:
	var s := GameData.state
	var card := UiKit.card(UiKit.APRICOT.lightened(0.5))
	_loadout_card = card
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
	# 동행(07-fun 1절): 유닛 카드의 '동행' 버튼으로 고르고, 여기(주인공 쪽)에는 이름만 보인다
	var names: Array[String] = []
	for u in Loadout.companions(s):
		names.append(t("name.char." + GameData.UNIT_CHARS[u - 1]))
	_comp_lbl = UiKit.wrap(UiKit.label(t("ui.party.companions").format({"names": ", ".join(names), "have": names.size(), "n": Loadout.max_companions()}), 20))
	col.add_child(_comp_lbl)
	col.add_child(UiKit.label(t("ui.trait.title"), 20, UiKit.ACCENT.darkened(0.3)))
	col.add_child(UiKit.wrap(UiKit.label(_trait_text(), 18)))
	_detail.add_child(card)


## 필드 특성 목록(데리고 다니는 유닛의 장비 속성, FieldTraits)
func _trait_text() -> String:
	var ft := FieldTraits.from_state(GameData.state, GameData.repo, GameData.field_traits)
	var lines: Array[String] = []
	for e in ft.summary():
		var v := float(e["value"])
		var shown := ("%.1f" % v) if String(e["id"]) == "execute" else str(roundi(v * 100.0))
		lines.append("%s: %s" % [t("name.attr.%02d" % int(e["attr"])), t("ui.trait." + String(e["id"])).format({"v": shown})])
	if ft.shields > 0:
		lines.append(t("ui.trait.shields").format({"n": ft.shields}))
	return "\n".join(lines) if not lines.is_empty() else t("ui.trait.none")


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
	var first := true
	for r in GameData.rules.equippable_roots(s, unit):
		var root := String(r)
		var b := UiKit.button("%s — %s" % [root, GameText.root_desc(root)], func() -> void:
			Loadout.set_unit_root(s, GameData.rules, unit, root)
			GameData.save()
			_refresh(), UiKit.SKY, 18)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_detail.add_child(b)
		if first:
			first = false
			var fb := b
			(func() -> void:
				await get_tree().process_frame
				TutorialOverlay.run(self, "party_root", [{"target": fb, "text": "tut.party.pick", "mode": "tap"}] as Array[Dictionary])).call()
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
