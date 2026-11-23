class_name BattleScreen
extends Screen
## 전투 연출. 규칙 층(BattleEngine)이 이미 계산한 기록(log)을 차례로 보여 준다. 화면은 계산하지 않는다.

const STEP := 0.55
const ROUND_STEP := 0.3

var _ctx: BattleContext
var _result: BattleResult
var _words: Array[String] = []
var _boss := false
var _party: Array[int] = []
var _ally_cards: Array[Label] = []
var _enemy_cards: Array[Label] = []
var _a_box: Label
var _b_box: Label
var _banner: Label
var _end_btn: Button
var _skip := false
var _cur := {Combatant.ALLY: -1, Combatant.ENEMY: -1}


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
		_ally_cards.append(l)
	var right := UiKit.vbox(8)
	add_child(right)
	UiKit.pin(right, 1, 0, -20, 20)
	for i in _ctx.enemies.size():
		var e := _ctx.enemies[i]
		var l := UiKit.label("%s Lv%d" % [e.word_id, e.level], 18)
		var c := UiKit.card(UiKit.PINK if not e.is_boss else UiKit.ACCENT.lightened(0.5))
		var row := UiKit.hbox(6)
		var face := Art.rect("boss", e.word_id, Vector2(48, 48)) if e.is_boss else Art.rect("enemy", "attr_%02d" % GameData.repo.get_word(e.word_id).primary_attr(), Vector2(48, 48))
		if face:
			row.add_child(face)
		row.add_child(l)
		c.add_child(row)
		right.add_child(c)
		_enemy_cards.append(l)
	var mid := UiKit.hbox(60)
	add_child(mid)
	UiKit.pin(mid, 0.5, 0.5, 0, -30)
	_a_box = UiKit.label("", 26)
	_a_box.custom_minimum_size = Vector2(380, 260)
	var ac := UiKit.card(UiKit.PAPER)
	ac.add_child(_a_box)
	mid.add_child(ac)
	_b_box = UiKit.label("", 26)
	_b_box.custom_minimum_size = Vector2(380, 260)
	var bc := UiKit.card(UiKit.PAPER)
	bc.add_child(_b_box)
	mid.add_child(bc)
	_banner = UiKit.label("", 30, UiKit.ACCENT.darkened(0.25))
	_banner.custom_minimum_size = Vector2(900, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_banner)
	UiKit.pin(_banner, 0.5, 1, 0, -130)
	var skip := UiKit.button(t("ui.battle.skip"), func() -> void: _skip = true, UiKit.PAPER, 22)
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
		_apply(ev)
		if not _skip:
			await get_tree().create_timer(ROUND_STEP if ev["t"] == "round" else STEP).timeout
	_end_btn.visible = true


func _who(side: int, idx: int) -> String:
	if side == Combatant.ALLY:
		return UiKit.unit_name(_party[idx])
	return _ctx.enemies[idx].word_id


func _coins(flips: Array) -> String:
	var s := ""
	for f in flips:
		s += "● " if f else "○ "
	return s


func _apply(ev: Dictionary) -> void:
	match ev["t"]:
		"magic":
			_banner.text = t("ui.battle.magic_cast").format({"magic": t("sys.magic.%s.name" % ev["id"]),
				"target": _ctx.enemies[ev["target"]].word_id, "damage": ev["damage"]})
		"enter":
			_cur[ev["side"]] = ev["idx"]
			var box := _a_box if ev["side"] == Combatant.ALLY else _b_box
			box.text = "%s\n%s %s\n%s" % [_who(ev["side"], ev["idx"]), t("ui.battle.coins"), _coins(ev["flips"]),
				t("ui.battle.stats").format({"atk": ev["atk"], "def": ev["def"], "hp": ev["hp"]})]
		"skill":
			var who := _who(ev["side"], _cur[ev["side"]])
			_banner.text = t("ui.battle.skill").format({"who": who, "root": ev["root"]})
		"skill_copy":
			_banner.text = t("ui.battle.skill_copy").format({"root": ev["root"]})
		"boss_ability":
			_banner.text = t("ui.battle.boss_ability").format({"count": ev.get("count", 0)})
			GameData.vibrate()
		"clash":
			_a_box.text = _stat_text(Combatant.ALLY, ev["a"], ev["a_atk"], ev["a_def"], ev["a_hp"])
			_b_box.text = _stat_text(Combatant.ENEMY, ev["b"], ev["b_atk"], ev["b_def"], ev["b_hp"])
		"round":
			_a_box.text = _replace_hp(_a_box.text, ev["a_hp"])
			_b_box.text = _replace_hp(_b_box.text, ev["b_hp"])
			_banner.text = t("ui.battle.round").format({"n": ev["n"], "to_a": ev["to_a"], "to_b": ev["to_b"]})
		"down":
			var cards := _ally_cards if ev["side"] == Combatant.ALLY else _enemy_cards
			cards[ev["idx"]].add_theme_color_override("font_color", UiKit.GRAY)
			cards[ev["idx"]].text += "  ✕"
			if ev["side"] == Combatant.ALLY:
				GameData.vibrate()
		"end":
			_banner.text = t("ui.battle.end").format({"kills": ev["kills"], "total": ev["total"]})


func _stat_text(side: int, idx: int, a: int, d: int, h: int) -> String:
	var c: Combatant = (_ctx.allies if side == Combatant.ALLY else _ctx.enemies)[idx]
	return "%s\n%s %s\n%s" % [_who(side, idx), t("ui.battle.coins"), _coins(c.flips),
		t("ui.battle.stats").format({"atk": a, "def": d, "hp": h})]


func _replace_hp(text: String, hp: int) -> String:
	var lines := text.split("\n")
	var last := lines.size() - 1
	var parts := lines[last].rsplit(" ", true, 1)
	lines[last] = parts[0] + " " + str(hp)
	return "\n".join(lines)
