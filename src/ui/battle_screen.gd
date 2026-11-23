class_name BattleScreen
extends Screen
## 전투 연출. 규칙 층(BattleEngine)이 이미 계산한 기록(log)을 차례로 보여 준다. 화면은 계산하지 않는다.
## 순서: 마법 알림 → 유닛 등장(코인이 돌고, 코인 전→후 능력치가 깜빡임) → 스킬·보스 능력(바뀐 능력치 깜빡임)
## → "1턴" → 공격(깎인 체력이 빨갛게 깜빡임) → 둘 다 살아 있으면 "2턴" … 모든 일은 아래 기록 창에 한 줄씩 남는다.

const STEP := 0.7
const TURN_SHOW := 0.6
const FLASH := 0.9

var _ctx: BattleContext
var _result: BattleResult
var _words: Array[String] = []
var _boss := false
var _party: Array[int] = []
var _ally_cards: Array[Label] = []
var _enemy_cards: Array[Label] = []
var _a_box: BattleCard
var _b_box: BattleCard
var _turn: Label
var _banner: Label
var _history: VBoxContainer
var _history_scroll: ScrollContainer
var _end_btn: Button
var _skip := false
var _ended := false
var _cur := {Combatant.ALLY: -1, Combatant.ENEMY: -1}
var _magic_on := {}  ## 적 순번 -> {damage, down}: 시작 마법을 맞은 적(나올 때 효과를 보여 준다)
var lines: Array[String] = []  ## 기록 창의 글(테스트용)


func open(args: Dictionary) -> void:
	_ctx = args["ctx"]
	_result = args["result"]
	_words = args["words"]
	_boss = args["boss"]
	_party = args["party"]
	UiKit.fill_bg(self, Color("e9e2f3"))
	var left := UiKit.vbox(8)
	left.position = Vector2(20, 20)
	add_child(left)
	for i in _party.size():
		var l := UiKit.label(UiKit.unit_name(_party[i]), 18)
		var c := UiKit.card(UiKit.LEAF)
		var row := UiKit.hbox(6)
		var face := Art.rect("unit", "u%02d" % _party[i], Vector2(48, 48))
		if face:
			row.add_child(face)
		row.add_child(l)
		c.add_child(row)
		left.add_child(c)
		_hold_side(c, Combatant.ALLY, i)
		_ally_cards.append(l)
	var right := UiKit.vbox(8)
	add_child(right)
	UiKit.pin(right, 1, 0, -20, 20)
	for i in _ctx.enemies.size():
		var e := _ctx.enemies[i]
		var l := UiKit.label("%s Lv%d" % [e.word_id, e.level], 18)
		var ew := GameData.repo.get_word(e.word_id)
		if ew and not WordCard.is_owned(ew):
			l.add_theme_color_override("font_color", WordCard.FRESH)
		var c := UiKit.card(UiKit.PINK if not e.is_boss else UiKit.ACCENT.lightened(0.5))
		var row := UiKit.hbox(6)
		var face := Art.rect("boss", e.word_id, Vector2(48, 48)) if e.is_boss else Art.rect("enemy", "attr_%02d" % GameData.repo.get_word(e.word_id).primary_attr(), Vector2(48, 48))
		if face:
			row.add_child(face)
		row.add_child(l)
		c.add_child(row)
		right.add_child(c)
		_hold_side(c, Combatant.ENEMY, i)
		_enemy_cards.append(l)
	_turn = UiKit.label("", 40, UiKit.ACCENT.darkened(0.3))
	_turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn.custom_minimum_size = Vector2(300, 0)
	add_child(_turn)
	UiKit.pin(_turn, 0.5, 0, 0, 14)
	var mid := UiKit.hbox(60)
	add_child(mid)
	UiKit.pin(mid, 0.5, 0, 0, 70)
	_a_box = BattleCard.new()
	mid.add_child(_a_box)
	_b_box = BattleCard.new()
	mid.add_child(_b_box)
	_banner = UiKit.label("", 26, UiKit.ACCENT.darkened(0.25))
	_banner.custom_minimum_size = Vector2(900, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_banner)
	UiKit.pin(_banner, 0.5, 0, 0, 345)
	# 기록 창: 일어난 일을 한 줄씩(끝난 뒤에도 올려 볼 수 있다)
	var hist_card := UiKit.card(Color(1, 1, 1, 0.75))
	add_child(hist_card)
	UiKit.pin(hist_card, 0.5, 0, 0, 385)
	_history_scroll = ScrollContainer.new()
	_history_scroll.custom_minimum_size = Vector2(840, 220)
	_history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hist_card.add_child(_history_scroll)
	_history = UiKit.vbox(2)
	_history.custom_minimum_size = Vector2(820, 0)
	_history_scroll.add_child(_history)
	var skip := UiKit.button(t("ui.battle.skip"), skip_all, UiKit.PAPER, 22)
	add_child(skip)
	UiKit.pin(skip, 0, 1, 20, -20)
	_end_btn = UiKit.button(t("ui.battle.to_result"), func() -> void:
		main.flow.battle_finished(_result, _words, _boss), UiKit.LEAF)
	_end_btn.visible = false
	add_child(_end_btn)
	UiKit.pin(_end_btn, 1, 1, -20, -20)
	_play()


func _play() -> void:
	for ev in _ctx.log:
		await _step(ev)
	_end_btn.visible = true
	_ended = true
	_a_box.hold_enabled = true
	_b_box.hold_enabled = true
	_turn.text = ""
	var hint := UiKit.label(t("ui.battle.hold_hint"), 18, UiKit.INK.lightened(0.2))
	add_child(hint)
	UiKit.pin(hint, 0.5, 1, 0, -60)


## 빨리 보기: 남은 연출을 기다리지 않고 끝까지 보여 준다(기록은 그대로 남는다).
func skip_all() -> void:
	_skip = true
	_a_box.skip = true
	_b_box.skip = true


## 기다린다. 빨리 보기를 누르면 기다리던 것도 바로 끝난다.
func _wait(sec: float) -> void:
	var t := sec
	while t > 0.0 and not _skip:
		await get_tree().process_frame
		t -= get_process_delta_time()


func _log(text: String, col: Color = UiKit.INK) -> void:
	lines.append(text)
	_history.add_child(UiKit.wrap(UiKit.label(text, 18, col), 820))
	await get_tree().process_frame
	if is_instance_valid(_history_scroll):
		_history_scroll.scroll_vertical = int(_history_scroll.get_v_scroll_bar().max_value)


func _who(side: int, idx: int) -> String:
	if side == Combatant.ALLY:
		return UiKit.unit_name(_party[idx])
	return _ctx.enemies[idx].word_id


func _side_list(side: int) -> Array:
	return _ctx.allies if side == Combatant.ALLY else _ctx.enemies


func _box(side: int) -> BattleCard:
	return _a_box if side == Combatant.ALLY else _b_box


func _coin_text(flips: Array) -> String:
	var s := ""
	for f in flips:
		s += "H" if f else "T"
	return s


func _step(ev: Dictionary) -> void:
	match ev["t"]:
		"magic":
			var target: String = _ctx.enemies[ev["target"]].word_id
			var text := t("ui.battle.magic_cast").format({"magic": t("sys.magic.%s.name" % ev["id"]), "target": target,
				"damage": ev["damage"], "down": ev.get("atk_down", 0)})
			_banner.text = text
			_log("✦ " + text, UiKit.ACCENT.darkened(0.3))
			_magic_on[ev["target"]] = {"damage": ev["damage"], "down": ev.get("atk_down", 0)}
			await _wait(STEP * 1.5)
		"enter":
			await _enter(ev)
		"skill", "skill_copy", "boss_ability":
			await _effect(ev)
		"clash":
			# 기록과 화면 값을 맞춘다(바뀐 것은 앞에서 이미 깜빡였다)
			_a_box.set_values(ev["a_atk"], ev["a_def"], ev["a_hp"])
			_b_box.set_values(ev["b_atk"], ev["b_def"], ev["b_hp"])
		"round":
			await _round(ev)
		"down":
			var cards := _ally_cards if ev["side"] == Combatant.ALLY else _enemy_cards
			cards[ev["idx"]].add_theme_color_override("font_color", UiKit.GRAY)
			cards[ev["idx"]].text += "  ✕"
			var who := _who(ev["side"], ev["idx"])
			_banner.text = t("ui.battle.down").format({"who": who})
			_log("✕ " + _banner.text, UiKit.BAD.darkened(0.2))
			if ev["side"] == Combatant.ALLY:
				GameData.vibrate()
			await _wait(STEP)
		"end":
			_banner.text = t("ui.battle.end").format({"kills": ev["kills"], "total": ev["total"]})
			_log("■ " + _banner.text, UiKit.ACCENT.darkened(0.3))


## 유닛이 나온다: 코인 전 값으로 카드를 펴고 → (마법을 맞았으면 그 효과) → 코인이 돈 뒤 코인 전→후 값이 깜빡인다.
func _enter(ev: Dictionary) -> void:
	var side: int = ev["side"]
	var idx: int = ev["idx"]
	_cur[side] = idx
	_turn.text = ""
	var c: Combatant = _side_list(side)[idx]
	var who := _who(side, idx)
	var box := _box(side)
	var magic: Dictionary = _magic_on.get(idx, {}) if side == Combatant.ENEMY else {}
	var atk0: int = int(ev["pre_atk"]) + int(magic.get("down", 0))
	var hp0: int = int(ev["pre_hp"])
	box.show_now(c, who, atk0, ev["def"], hp0, _ctx.formula, not _skip)
	_banner.text = t("ui.battle.enter").format({"who": who})
	await _wait(BattleCard.SPIN_SEC + 0.15)
	if not magic.is_empty():
		_banner.text = t("ui.battle.magic_hit").format({"who": who})
		_log("  " + t("ui.battle.h_magic_hit").format({"who": who, "h0": hp0, "h1": hp0 - int(ev["magic_hit"]),
			"a0": atk0, "a1": atk0 - int(magic["down"])}), UiKit.BAD.darkened(0.2))
		box.flash("atk", atk0, atk0 - int(magic["down"]), UiKit.BAD, FLASH, _skip)
		await box.flash("hp", hp0, hp0 - int(ev["magic_hit"]), UiKit.BAD, FLASH, _skip)
		atk0 -= int(magic["down"])
		hp0 -= int(ev["magic_hit"])
	var parts: Array[String] = []
	if int(ev["gain_atk"]) != 0:
		parts.append(t("ui.battle.atk") + " %d→%d" % [atk0, ev["atk"]])
	if int(ev["gain_hp"]) != 0:
		parts.append(t("ui.battle.hp") + " %d→%d" % [hp0, ev["hp"]])
	_log(t("ui.battle.h_enter").format({"who": who, "coins": _coin_text(ev["flips"]),
		"change": ", ".join(parts) if not parts.is_empty() else t("ui.battle.h_no_change")}))
	if not parts.is_empty():
		_banner.text = t("ui.battle.coin_change").format({"who": who})
		if int(ev["gain_atk"]) != 0:
			box.flash("atk", atk0, ev["atk"], UiKit.ACCENT.darkened(0.2), FLASH, _skip)
		if int(ev["gain_hp"]) != 0:
			box.flash("hp", hp0, ev["hp"], UiKit.ACCENT.darkened(0.2), FLASH, _skip)
		await _wait(FLASH + 0.1)
	box.set_values(ev["atk"], ev["def"], ev["hp"])


## 스킬·보스 능력: 무엇이 발동했는지 알리고, 바뀐 능력치를 전→후로 깜빡인다.
func _effect(ev: Dictionary) -> void:
	var text := ""
	match ev["t"]:
		"skill":
			text = t("ui.battle.skill").format({"who": _who(ev["side"], _cur[ev["side"]]), "root": ev["root"]})
		"skill_copy":
			text = t("ui.battle.skill_copy").format({"root": ev["root"]})
		"boss_ability":
			text = t("ui.battle.boss_ability").format({"count": ev.get("count", 0)})
			GameData.vibrate()
	_banner.text = text
	var changes: Array[String] = []
	var b4: Dictionary = ev.get("before", {})
	var af: Dictionary = ev.get("after", {})
	var keys := ["atk", "def", "hp"]
	for pair in [["a", Combatant.ALLY], ["b", Combatant.ENEMY]]:
		if not b4.has(pair[0]):
			continue
		var side: int = pair[1]
		for k in 3:
			var x: int = b4[pair[0]][k]
			var y: int = af[pair[0]][k]
			if x != y:
				changes.append("%s %s %d→%d" % [_who(side, _cur[side]), t("ui.battle." + keys[k]), x, y])
				_box(side).flash(keys[k], x, y, UiKit.ACCENT.darkened(0.2) if y > x else UiKit.BAD, FLASH, _skip)
		if b4.get(pair[0] + "_flips", []) != af.get(pair[0] + "_flips", []):
			_box(side).coins.set_flips(af[pair[0] + "_flips"], false)
			changes.append("%s %s %s→%s" % [_who(side, _cur[side]), t("ui.battle.coins_word"),
				_coin_text(b4[pair[0] + "_flips"]), _coin_text(af[pair[0] + "_flips"])])
	_log("✦ " + text + ("  " + ", ".join(changes) if not changes.is_empty() else ""), UiKit.ACCENT.darkened(0.3))
	await _wait(maxf(STEP, FLASH + 0.1) if not changes.is_empty() else STEP)


## 한 턴: 가운데 "N턴"을 띄우고, 서로 공격해 깎인 체력을 빨갛게 깜빡인다.
func _round(ev: Dictionary) -> void:
	_turn.text = t("ui.battle.turn").format({"n": ev["n"]})
	_turn.pivot_offset = _turn.size / 2
	if not _skip:
		_turn.scale = Vector2(1.4, 1.4)
		create_tween().tween_property(_turn, "scale", Vector2.ONE, 0.25)
	await _wait(TURN_SHOW)
	var a := _who(Combatant.ALLY, _cur[Combatant.ALLY])
	var b := _who(Combatant.ENEMY, _cur[Combatant.ENEMY])
	var ah0 := _a_box.value("hp")
	var bh0 := _b_box.value("hp")
	_banner.text = t("ui.battle.attack").format({"a": a, "b": b, "to_b": ev["to_b"], "to_a": ev["to_a"]})
	var first := ""
	if int(ev.get("first", -1)) >= 0:
		first = "  " + t("ui.battle.first").format({"who": a if ev["first"] == Combatant.ALLY else b})
	_log(t("ui.battle.h_round").format({"n": ev["n"], "a": a, "b": b, "to_b": ev["to_b"], "to_a": ev["to_a"],
		"bh0": bh0, "bh": ev["b_hp"], "ah0": ah0, "ah": ev["a_hp"]}) + first)
	_b_box.flash("hp", bh0, ev["b_hp"], UiKit.BAD, FLASH, _skip)
	_a_box.flash("hp", ah0, ev["a_hp"], UiKit.BAD, FLASH, _skip)
	await _wait(FLASH + 0.15)


## 전투가 끝난 뒤 옆 목록의 카드를 누르고 있으면, 가운데 카드에 그 유닛의 처음 모습을 보여 준다.
func _hold_side(card: Control, side: int, idx: int) -> void:
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if not _ended or not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
			return
		var box := _box(side)
		if ev.pressed:
			var c: Combatant = _side_list(side)[idx]
			box.show_now(c, _who(side, idx), c.atk, c.def, maxi(0, c.hp), _ctx.formula)
			box.show_base(true)
		else:
			box.show_base(false))
