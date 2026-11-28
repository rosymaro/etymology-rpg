class_name PartyScreen
extends Screen
## 파티(사용자 의견): 왼쪽에 주인공과 유닛 12마리를 세로로, 오른쪽에 고른 인물.
## - 주인공: 필드 마법 2칸, 전투 마법 4칸(세로). 누르면 마법과 설명을 함께 보는 팝업. 다른 칸에 이미 넣은 마법은 회색(못 고름).
##   그 아래 동행 유닛 이름과 장착한 어근.
## - 유닛: 레벨·능력치, 동행 켜기, 어근(팝업), '장비' 버튼 → 몸 모양 장비 페이지(부위를 누르면 단어 고르기 팝업, 아래에 지금 능력치).
## 마법·어근·동행은 마을에서만 바꾼다(장비는 어디서나).

const LIST_W := 196.0

var _detail: VBoxContainer
var _list: VBoxContainer
var _body: HBoxContainer
var _sel := 0  ## 0 = 주인공, 1~12 = 유닛
var _start: Array[int] = []  ## 이 화면을 열 때의 동행(닫을 때 바뀌었으면 레벨을 이어 주고 말을 한다)
var _gear_unit := 0  ## 장비 페이지를 보고 있는 유닛(0이면 보통 화면)
var _popup: Control

var _first_root_btn: Button
var _comp_lbl: Label
var _loadout_card: Control


func open(_args: Dictionary) -> void:
	_start = Loadout.companions(GameData.state)
	UiKit.fill_bg(self, UiKit.LEAF.lightened(0.4))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var v := UiKit.vbox(10)
	margin.add_child(v)
	var head := UiKit.hbox()
	var title := UiKit.label(t("ui.party.title"), 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.button(t("ui.common.back"), _back, UiKit.PAPER, 22))
	v.add_child(head)
	_body = UiKit.hbox(12)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	_list = UiKit.vbox(8)
	var ls := UiKit.scroll(_list)
	ls.custom_minimum_size.x = LIST_W
	ls.size_flags_horizontal = Control.SIZE_FILL
	_body.add_child(ls)
	_detail = UiKit.vbox(10)
	var ds := UiKit.scroll(_detail)
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(ds)
	_refresh()
	_tutorial.call_deferred()


## 처음 유닛 창(08-tutorial.md): 장착 칸 → (유닛을 고르면) 어근 버튼.
func _tutorial() -> void:
	await get_tree().process_frame
	var steps: Array[Dictionary] = [{"target": _loadout_card, "text": "tut.party.loadout", "mode": "any"}]
	if _first_root_btn and is_instance_valid(_first_root_btn) and not _first_root_btn.disabled:
		steps.append({"target": _first_root_btn, "text": "tut.party.root", "mode": "tap"})
	elif not _in_town():
		steps.append({"target": _loadout_card, "text": "tut.party.town", "mode": "any"})
	TutorialOverlay.run(self, "party", steps)


func _back() -> void:
	if _popup and is_instance_valid(_popup):
		_close_popup()
		return
	if _gear_unit > 0:
		_gear_unit = 0
		_refresh()
		return
	_leave()


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


static func unit_short(u: int) -> String:
	return TranslationServer.translate("name.char." + GameData.UNIT_CHARS[u - 1])


func _refresh() -> void:
	_build_list()
	for c in _detail.get_children():
		c.queue_free()
	if _gear_unit > 0:
		_build_gear(_gear_unit)
	elif _sel == 0:
		_build_hero()
	else:
		_build_unit(_sel)


# ----- 왼쪽 목록: 주인공 + 유닛 12 -----

func _build_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var s := GameData.state
	for k in 13:
		var u: int = k
		var joined := u == 0 or u in s.joined
		var name := (s.hero_name if s.hero_name != "" else t("ui.party.hero")) if u == 0 else (unit_short(u) if joined else t("ui.party.not_joined"))
		var on := u > 0 and u in Loadout.companions(s)
		var col := UiKit.APRICOT.lightened(0.2) if u == _sel and _gear_unit == 0 or u == _gear_unit else UiKit.PAPER
		var b := UiKit.button("", func() -> void:
			_sel = u
			_gear_unit = 0
			_refresh(), col, 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(LIST_W, 74)
		b.disabled = not joined
		var face := Portrait.new()
		face.unit = u
		face.look = s.hero_look
		face.dim = not joined
		face.position = Vector2(6, 4)
		face.size = Vector2(56, 66)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(face)
		b.text = "          " + name + ("  ♥" if on else "")  # 왼쪽은 얼굴 자리, ♥ = 동행 중
		_list.add_child(b)


# ----- 주인공: 필드 마법 2, 전투 마법 4(세로), 동행과 어근 -----

func _build_hero() -> void:
	var s := GameData.state
	var card := UiKit.card(UiKit.APRICOT.lightened(0.5))
	_loadout_card = card
	var col := UiKit.vbox(8)
	card.add_child(col)
	var top := UiKit.hbox(10)
	var face := Portrait.new()
	face.unit = 0
	face.look = s.hero_look
	face.custom_minimum_size = Vector2(110, 130)
	top.add_child(face)
	var nm := UiKit.label(s.hero_name if s.hero_name != "" else t("ui.party.hero"), 28)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(nm)
	col.add_child(top)
	if not _in_town():
		col.add_child(UiKit.wrap(UiKit.label(t("ui.party.town_only"), 18, UiKit.BAD.darkened(0.2))))
	for kind in ["field", "deck"]:
		col.add_child(UiKit.label(t("ui.party." + kind), 22, UiKit.ACCENT.darkened(0.3)))
		var slots: Array[String] = Loadout.field(s) if kind == "field" else Loadout.deck(s, GameData.rules)
		for i in slots.size():
			var k: int = i
			var kd: String = kind
			var id := slots[i]
			var name := (GameText.field_magic_name(id) if kind == "field" else GameText.magic_name(id)) if id != "" else t("ui.party.empty")
			var b := UiKit.button(name, func() -> void: _magic_popup(kd, k), UiKit.PAPER, 20)
			b.custom_minimum_size = Vector2(0, 56)
			b.disabled = not _in_town()
			col.add_child(b)
	_detail.add_child(card)
	# 동행과 장착 어근(사용자 의견: 캐릭터 아래에 동행할 유닛 이름과 장착된 어원)
	var cc := UiKit.card()
	var cv := UiKit.vbox(6)
	cc.add_child(cv)
	var comps := Loadout.companions(s)
	_comp_lbl = UiKit.label(t("ui.party.companions").format({"names": "", "have": comps.size(), "n": Loadout.max_companions()}).trim_suffix(": "), 22, UiKit.ACCENT.darkened(0.3))
	cv.add_child(_comp_lbl)
	for u in comps:
		var root := Loadout.unit_root(s, GameData.rules, u)
		cv.add_child(UiKit.label(t("ui.party.comp_row").format({"name": unit_short(u), "root": root if root != "" else "-"}), 20))
	cv.add_child(UiKit.label(t("ui.trait.title"), 20, UiKit.ACCENT.darkened(0.3)))
	cv.add_child(UiKit.wrap(UiKit.label(_trait_text(), 18)))
	_detail.add_child(cc)


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


static func field_magic_desc(id: String) -> String:
	var key := "sys.field_magic.%s.desc" % id
	var s := TranslationServer.translate(key)
	return s if s != key else TranslationServer.translate("ui.field.magic_soon")


## 마법 고르기 팝업: 이름과 설명. 같은 종류의 다른 칸에 이미 넣은 마법은 회색(못 고른다).
func _magic_popup(kind: String, i: int) -> void:
	var s := GameData.state
	var owned: Array = s.magics if kind == "field" else GameData.rules.battle_magics(s)
	var slots: Array[String] = Loadout.field(s) if kind == "field" else Loadout.deck(s, GameData.rules)
	var rows: Array[Control] = []
	var power := GameData.bal.magic_power(GameData.rules.level(s, s.joined[0] if not s.joined.is_empty() else 1))
	for m in owned:
		var id := String(m)
		var used := id in slots and slots.find(id) != i
		var name := GameText.field_magic_name(id) if kind == "field" else GameText.magic_name(id)
		var desc := field_magic_desc(id) if kind == "field" else GameText.magic_desc(id, power)
		var b := UiKit.button("%s\n%s" % [name, desc], func() -> void: _put_magic(kind, i, id), UiKit.PAPER if not used else UiKit.GRAY, 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.disabled = used
		if used:
			b.text = "%s  (%s)\n%s" % [name, t("ui.party.in_use"), desc]
		rows.append(b)
	var clear := UiKit.button(t("ui.party.empty"), func() -> void: _put_magic(kind, i, ""), UiKit.PAPER, 18)
	rows.append(clear)
	_open_popup(t("ui.party.pick_" + kind), rows)


func _put_magic(kind: String, i: int, id: String) -> void:
	var s := GameData.state
	if kind == "field":
		Loadout.set_field(s, i, id)
	else:
		Loadout.set_deck(s, GameData.rules, i, id)
	GameData.save()
	_close_popup()
	_refresh()


# ----- 유닛 -----

func _build_unit(u: int) -> void:
	var s := GameData.state
	var lv := GameData.rules.level(s, u)
	var a := GameData.setup.factory.ally(s, u, "")
	var card := UiKit.card()
	var col := UiKit.vbox(8)
	card.add_child(col)
	var top := UiKit.hbox(10)
	var face := Portrait.new()
	face.unit = u
	face.custom_minimum_size = Vector2(110, 130)
	top.add_child(face)
	var tv := UiKit.vbox(4)
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_child(UiKit.label(UiKit.unit_name(u), 24))
	tv.add_child(UiKit.label(t("ui.party.lv_exp").format({"level": lv, "exp": s.unit_exp[u - 1]}), 20))
	top.add_child(tv)
	col.add_child(top)
	col.add_child(UiKit.label(_stats_line(u, a), 20))
	var wid := GameData.hunt_run().weapon_of(u)
	col.add_child(UiKit.wrap(UiKit.label(t("ui.party.field_attack").format({"w": t("ui.hunt.weapon." + wid)}), 18, PalArt.color(u).darkened(0.45))))
	var on := u in Loadout.companions(s)
	var cb := UiKit.button(t("ui.party.with_on" if on else "ui.party.with_off"), func() -> void:
		if Loadout.toggle_companion(s, u):
			GameData.save()
			_refresh()
		else:
			main.notice(t("ui.party.companions_one" if u in Loadout.companions(s) else "ui.party.companions_full").format({"n": Loadout.max_companions()})),
		UiKit.ACCENT.lightened(0.3) if on else UiKit.PAPER, 20)
	cb.custom_minimum_size = Vector2(0, 56)
	cb.disabled = not _in_town()
	col.add_child(cb)
	var root := Loadout.unit_root(s, GameData.rules, u)
	var rb := UiKit.button(t("ui.party.root").format({"root": root if root != "" else "-"}),
		func() -> void: _root_popup(u), UiKit.ACCENT.lightened(0.5), 20)
	rb.custom_minimum_size = Vector2(0, 56)
	rb.disabled = not _in_town() or GameData.rules.equippable_roots(s, u).is_empty()
	col.add_child(rb)
	_first_root_btn = rb
	var gb := UiKit.button(t("ui.party.gear"), func() -> void:
		_gear_unit = u
		_refresh(), UiKit.SKY, 22)
	gb.custom_minimum_size = Vector2(0, 64)
	col.add_child(gb)
	_detail.add_child(card)


func _stats_line(u: int, a: Combatant) -> String:
	var attr := AttributeResolver.new().resolve(GameData.state.eq(u), GameData.repo)
	var attr_text := t("ui.party.attr_off") if attr["tier"] == 0 else t("ui.party.attr").format(
		{"attr": t("name.attr.%02d" % attr["attr"]), "count": attr["count"]})
	return t("ui.party.stats").format({"atk": a.base.atk, "def": a.base.def, "hp": a.base.hp, "coins": a.coins, "attr": attr_text})


func _root_popup(u: int) -> void:
	var s := GameData.state
	var rows: Array[Control] = []
	var cur := Loadout.unit_root(s, GameData.rules, u)
	for r in GameData.rules.equippable_roots(s, u):
		var root := String(r)
		var b := UiKit.button(GameText.root_desc(root), func() -> void:
			Loadout.set_unit_root(s, GameData.rules, u, root)
			GameData.save()
			_close_popup()
			_refresh(), UiKit.APRICOT.lightened(0.3) if root == cur else UiKit.PAPER, 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.append(b)
	_open_popup(t("ui.party.pick_root").format({"name": unit_short(u)}), rows)
	if not rows.is_empty():
		var fb := rows[0]
		(func() -> void:
			await get_tree().process_frame
			TutorialOverlay.run(self, "party_root", [{"target": fb, "text": "tut.party.pick", "mode": "tap"}] as Array[Dictionary])).call()


# ----- 장비 페이지: 몸 모양 -----

func _build_gear(u: int) -> void:
	var s := GameData.state
	var head := UiKit.hbox(8)
	head.add_child(UiKit.label(t("ui.party.gear_title").format({"name": unit_short(u)}), 24))
	_detail.add_child(head)
	var fig := GearBody.new()
	fig.unit = u
	fig.custom_minimum_size = Vector2(0, 640)
	_detail.add_child(fig)
	await get_tree().process_frame  # 크기가 정해진 뒤 부위 단추를 놓는다
	if not is_instance_valid(fig):
		return
	for sl in Equipment.SLOTS:
		var slot: String = sl
		var cur := s.eq(u).get_in(sl)
		var b := UiKit.button("%s\n%s" % [t("name.slot." + sl), cur if cur != "" else "-"], func() -> void: _gear_popup(u, slot), UiKit.SKY if cur != "" else UiKit.PAPER, 18)
		b.custom_minimum_size = Vector2(150, 64)
		fig.add_child(b)
		b.position = fig.slot_pos(slot, fig.size) - b.custom_minimum_size / 2.0
	var a := GameData.setup.factory.ally(s, u, "")
	var st := UiKit.card(UiKit.PAPER)
	var sv := UiKit.vbox(4)
	st.add_child(sv)
	sv.add_child(UiKit.label(t("ui.party.now_stats"), 20, UiKit.ACCENT.darkened(0.3)))
	sv.add_child(UiKit.label(t("ui.party.lv_exp").format({"level": GameData.rules.level(s, u), "exp": s.unit_exp[u - 1]}), 20))
	sv.add_child(UiKit.label(_stats_line(u, a), 20))
	_detail.add_child(st)


func _gear_popup(u: int, slot: String) -> void:
	var s := GameData.state
	var opts: Array[WordData] = []
	for id in s.dex:
		var w := GameData.repo.get_word(id)
		if w and w.unit == u and w.slot == slot:
			opts.append(w)
	opts.sort_custom(func(a: WordData, b: WordData) -> bool: return a.tier > b.tier)
	var rows: Array[Control] = []
	var cur := s.eq(u).get_in(slot)
	for w in opts:
		var id := w.id
		var b := UiKit.button("%s  %s\n%s" % [w.id, t("ui.dex.tier").format({"tier": w.tier}), w.meaning], func() -> void:
			s.eq(u).put(slot, id)
			GameData.save()
			_close_popup()
			_refresh(), UiKit.APRICOT.lightened(0.3) if id == cur else UiKit.PAPER, 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.append(b)
	if rows.is_empty():
		rows.append(UiKit.wrap(UiKit.label(t("ui.party.no_gear"), 20)))
	_open_popup(t("ui.party.choose").format({"name": unit_short(u), "slot": t("name.slot." + slot)}), rows)


# ----- 팝업 -----

func _open_popup(title: String, rows: Array[Control]) -> void:
	_close_popup()
	var p := Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	_popup = p
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.12, 0.06, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = -UiKit.BG_BLEED
	dim.offset_right = UiKit.BG_BLEED
	dim.offset_top = -UiKit.BG_BLEED
	dim.offset_bottom = UiKit.BG_BLEED
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close_popup())
	p.add_child(dim)
	var card := UiKit.card(UiKit.PAPER)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 40
	card.offset_right = -40
	card.offset_top = 160
	card.offset_bottom = -160
	p.add_child(card)
	var v := UiKit.vbox(10)
	card.add_child(v)
	v.add_child(UiKit.label(title, 24, UiKit.ACCENT.darkened(0.3)))
	var list := UiKit.vbox(8)
	var sc := UiKit.scroll(list)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	for r in rows:
		list.add_child(r)
	var close := UiKit.button(t("ui.common.close"), _close_popup, UiKit.APRICOT, 22)
	close.custom_minimum_size = Vector2(0, 60)
	v.add_child(close)


func _close_popup() -> void:
	if _popup and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


## 얼굴 그림: 0 = 주인공(사용자가 준 그림), 1~12 = 유닛.
class Portrait extends Control:
	var unit := 0
	var look := "m"
	var dim := false

	func _draw() -> void:
		var foot := Vector2(size.x / 2.0, size.y * 0.92)
		var h := size.y * 0.95
		modulate = Color(0.35, 0.35, 0.4, 0.55) if dim else Color.WHITE
		draw_set_transform(foot, 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, size.x * 0.32, Color(0.2, 0.12, 0.06, 0.18))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if unit == 0:
			if not Art.draw_anim(self, "hero", look, "idle", foot, h, false, 4.0):
				draw_circle(foot - Vector2(0, h * 0.45), size.x * 0.3, Color("fff3c4"))
			return
		if not Art.draw_anim(self, "pal", "%02d" % unit, "idle", foot, h * 0.9, false, 4.0):
			PalArt.draw(self, unit, Vector2(size.x / 2.0, size.y * 0.5), Vector2.RIGHT)

	func _process(_d: float) -> void:
		queue_redraw()


## 장비 페이지의 몸: 유닛 색 실루엣(머리·몸통·팔·다리)과 부위 자리. 단추는 화면이 slot_pos에 놓는다.
class GearBody extends Control:
	var unit := 1

	func slot_pos(slot: String, sz: Vector2) -> Vector2:
		var c := Vector2(sz.x / 2.0, 0)
		match slot:
			"head":
				return c + Vector2(0, 80)
			"chest":
				return c + Vector2(0, 250)
			"hands":
				return c + Vector2(-sz.x * 0.3, 330)
			"weapon":
				return c + Vector2(sz.x * 0.3, 330)
			"feet":
				return c + Vector2(0, 560)
		return c

	func _draw() -> void:
		var col := PalArt.color(unit).lightened(0.25)
		var ink := UiKit.INK
		var c := Vector2(size.x / 2.0, 0)
		# 바닥 그림자
		draw_set_transform(c + Vector2(0, 610), 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, 120, Color(0.2, 0.12, 0.06, 0.16))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 다리
		for sx in [-1.0, 1.0]:
			var leg := PackedVector2Array([c + Vector2(sx * 18, 380), c + Vector2(sx * 62, 380), c + Vector2(sx * 58, 560), c + Vector2(sx * 22, 560)])
			draw_colored_polygon(leg, col.darkened(0.08))
			draw_polyline(leg + PackedVector2Array([leg[0]]), ink, 4, true)
		# 팔
		for sx in [-1.0, 1.0]:
			var arm := PackedVector2Array([c + Vector2(sx * 78, 190), c + Vector2(sx * 112, 200), c + Vector2(sx * 178, 320), c + Vector2(sx * 150, 336)])
			draw_colored_polygon(arm, col.darkened(0.04))
			draw_polyline(arm + PackedVector2Array([arm[0]]), ink, 4, true)
		# 몸통
		var body := PackedVector2Array([c + Vector2(-84, 180), c + Vector2(84, 180), c + Vector2(70, 390), c + Vector2(-70, 390)])
		draw_colored_polygon(body, col)
		draw_polyline(body + PackedVector2Array([body[0]]), ink, 4, true)
		# 머리
		draw_circle(c + Vector2(0, 100), 70, col.lightened(0.15))
		draw_arc(c + Vector2(0, 100), 70, 0, TAU, 48, ink, 4, true)
		draw_circle(c + Vector2(-22, 96), 6, ink)
		draw_circle(c + Vector2(22, 96), 6, ink)
		draw_arc(c + Vector2(0, 112), 14, 0.3, PI - 0.3, 12, ink, 3, true)
