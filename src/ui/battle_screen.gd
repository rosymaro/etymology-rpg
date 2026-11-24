class_name BattleScreen
extends Screen
## 전투 연출. 규칙 층(BattleEngine)이 이미 계산한 기록(log)을 차례로 보여 준다. 화면은 계산하지 않는다.
## 순서: 마법 알림 → 유닛 등장(코인이 돌고, 코인 전→후 능력치가 깜빡임) → 스킬·보스 능력(바뀐 능력치 깜빡임)
## → "1턴" → 공격(깎인 체력이 빨갛게 깜빡이고, 맞은 카드에서 단어 뜻과 피해 숫자가 튀어나온다) → … 단계마다 '다음'을 눌러야 넘어간다.
## 전투를 시작할 때 거는 마법은 코인을 다 던진 뒤에 보여 준다(코인 → 다음 → 마법 → 다음 → 스킬 → 다음 → 1턴 …).
## 마법을 쓰면 왼쪽 아래 마법 버튼에서 마법 카드가 돌며 커져 나와, 공격 마법은 적 카드 위, 방어 마법은 아군 카드 위,
## 효과·순서 마법은 두 카드 가운데에 놓이고 그 마법의 이펙트(MagicFx, data/magic_fx.json)가 터진다.
## 일어난 일은 기록(entries)으로 모아 결과 화면에 턴마다 줄을 그어 보여 준다.

const STEP := 0.7
const TURN_SHOW := 0.6
const FLASH := 0.9
const FLOAT_SEC := 2.6  ## 튀어나온 뜻·피해 숫자가 보이는 시간
const MID_Y := 330.0  ## 세로 화면: 가운데 두 카드의 위쪽(양쪽 목록 아래)
const GROW_SEC := 0.6  ## 등장: 옆 목록의 작은 카드에서 뱅그르르 돌며 커져 나오는 시간
const FALL_SEC := 1.3  ## 쓰러짐: 앞으로 쓰러지며 깜빡이다 사라지는 시간
const MAGIC_FLY := 0.55  ## 마법 카드가 마법 버튼에서 날아와 놓이는 시간

var _ctx: BattleContext
var _result: BattleResult
var _words: Array[String] = []
var _boss := false
var _party: Array[int] = []
var _ally_cards: Array[Label] = []
var _enemy_cards: Array[Control] = []
var _a_box: BattleCard
var _b_box: BattleCard
var _turn: Label
var _banner: Label
var _next_btn: Button
var _tapped := false
var _popup: PanelContainer
var _popup_text: Label
var _end_btn: Button
var _skip := false
var _ended := false
var _cur := {Combatant.ALLY: -1, Combatant.ENEMY: -1}
var _magic_on := {}  ## 적 순번 -> {damage, down}: 이미 알린 시작 마법을 맞은 적(나올 때 효과를 보여 준다)
var _pending_magic := {}  ## 적 순번 -> 마법 기록: 아직 알리지 않은 시작 마법(코인 뒤에 보여 준다)
var _magic_due := {}  ## 적 순번 -> {a0, a1, h0, h1}: 카드에 아직 반영하지 않은 마법 효과
var _magic_btn: Button
var entries: Array[Dictionary] = []  ## 기록 {text, col} 또는 {sep: true}(턴 구분 줄). 결과 화면에 넘긴다
var lines: Array[String] = []  ## 기록의 글만(테스트용)
var _turn_n := 0  ## 전투 처음부터 센 턴 수
var steps_done := 0  ## '다음'을 누른 수(이어 하기에 적는다)
var _resume_to := 0  ## 이어 하기: 이만큼은 연출 없이 건너뛴다
var last_magic_card: Control  ## 마지막으로 놓인 마법 카드(테스트용)


func open(args: Dictionary) -> void:
	_ctx = args["ctx"]
	_result = args["result"]
	_words = args["words"]
	_boss = args["boss"]
	_party = args["party"]
	_resume_to = int(args.get("resume_step", 0))
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
		var ew := GameData.repo.get_word(e.word_id)
		# 미니게임 단어 카드와 같은 모양: 속성 색, 부위 아이콘, 가진 단어인지 글자색
		var c := WordCard.make(ew, "Lv%d" % e.level, 18)
		c.custom_minimum_size.x = 230
		right.add_child(c)
		_hold_side(c, Combatant.ENEMY, i)
		_enemy_cards.append(c)
	_turn = UiKit.label("", 40, UiKit.ACCENT.darkened(0.3))
	_turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn.custom_minimum_size = Vector2(300, 0)
	add_child(_turn)
	UiKit.pin(_turn, 0.5, 0, 0, MID_Y - 64)
	var mid := UiKit.hbox(28)  # 세로 화면: 양쪽 목록 아래에 두 카드
	add_child(mid)
	UiKit.pin(mid, 0.5, 0, 0, MID_Y)
	_a_box = BattleCard.new()
	mid.add_child(_a_box)
	_b_box = BattleCard.new()
	mid.add_child(_b_box)
	_banner = UiKit.label("", 26, UiKit.ACCENT.darkened(0.25))
	_banner.custom_minimum_size = Vector2(680, 0)
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_banner)
	UiKit.pin(_banner, 0.5, 0, 0, MID_Y + 270)
	_next_btn = UiKit.button(t("ui.battle.next_turn"), func() -> void: _tapped = true, UiKit.ACCENT.lightened(0.35), 26)
	_next_btn.custom_minimum_size = Vector2(260, UiKit.THUMB_H)
	_next_btn.visible = false
	add_child(_next_btn)
	UiKit.thumb(_next_btn)  # 엄지 자리
	# 카드를 누르고 있으면 누른 자리에 처음 모습 창
	_popup = UiKit.card(UiKit.SKY.lightened(0.35))
	_popup.visible = false
	_popup.z_index = 20
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_text = UiKit.wrap(UiKit.label("", 20), 460)
	_popup.add_child(_popup_text)
	add_child(_popup)
	for box in [_a_box, _b_box]:
		var bx: BattleCard = box
		bx.held.connect(func(on: bool, at: Vector2) -> void:
			_show_popup(_info(bx.combatant, bx.base_lines()) if on and bx.combatant else [] as Array[String], at))
	# 내가 쓴 마법: 왼쪽 아래 카드. 누르고 있으면 마법 내용 팝업
	_magic_btn = UiKit.button("✦ " + GameText.magic_name(_ctx.magic_id), func() -> void: pass, UiKit.APRICOT.lightened(0.2), 20)
	_magic_btn.custom_minimum_size = Vector2(220, 54)
	add_child(_magic_btn)
	UiKit.pin(_magic_btn, 0, 1, 20, -96)
	_magic_btn.button_down.connect(func() -> void:
		_show_popup([GameText.magic_name(_ctx.magic_id), GameText.magic_desc(_ctx.magic_id, _ctx.power)] as Array[String],
			_magic_btn.get_global_rect().get_center()))
	_magic_btn.button_up.connect(func() -> void: _show_popup([] as Array[String], Vector2.ZERO))
	var skip := UiKit.button(t("ui.battle.skip"), skip_all, UiKit.PAPER, 22)
	add_child(skip)
	UiKit.pin(skip, 0, 1, 20, -20)
	_end_btn = UiKit.button(t("ui.battle.to_result"), func() -> void:
		main.flow.battle_finished(_result, _words, _boss, entries), UiKit.LEAF)
	_end_btn.visible = false
	_end_btn.custom_minimum_size.x = 260
	add_child(_end_btn)
	UiKit.thumb(_end_btn)  # 엄지 자리
	_play()


func _play() -> void:
	if _resume_to > 0:  # 이어 하기: 보던 단계까지 연출 없이 지나간다
		_skip = true
		_a_box.skip = true
		_b_box.skip = true
	var log := _ctx.log
	# 첫 격돌 전에 건 마법은 코인을 다 던진 뒤에 알린다(기록 순번으로 가린다)
	var deferred_at: Array[int] = []
	for k in log.size():
		if log[k]["t"] == "clash":
			break
		if log[k]["t"] == "magic":
			_pending_magic[log[k]["target"]] = log[k]
			deferred_at.append(k)
	var deferred: Array = _pending_magic.values()
	var k := -1
	while k + 1 < log.size():
		k += 1
		var ev: Dictionary = log[k]
		if k in deferred_at:
			continue
		if ev["t"] == "enter":  # 잇달아 나오는 유닛(처음엔 아군·적 둘 다)은 함께 나오고 코인도 함께 돈다
			var group: Array[Dictionary] = [ev]
			while k + 1 < log.size() and log[k + 1]["t"] == "enter":
				k += 1
				group.append(log[k])
			await _enter_group(group)
		var next: String = log[k + 1]["t"] if k + 1 < log.size() else ""
		if ev["t"] != "enter":
			await _step(ev)
		if ev["t"] == "enter" and next != "enter":
			await _wait_tap()  # 코인을 다 보고 나서
			for m in deferred:
				await _play_magic(m)
				await _wait_tap()
			deferred.clear()
		elif ev["t"] in ["skill", "skill_copy", "boss_ability", "magic"]:
			await _wait_tap()
		elif ev["t"] == "round" and next != "down":
			await _wait_tap()  # 둘 다 살아 있으면 다음 턴으로
		elif ev["t"] == "down" and not next in ["down", "end"]:
			await _wait_tap()  # 체력이 0이 되자마자 쓰러지고, 그다음에 '다음'을 누른다
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
	entries.append({"text": text, "col": col.to_html()})


## 기록에 턴(또는 새 격돌)이 바뀌었다는 가로줄
func _sep() -> void:
	if not entries.is_empty() and not entries[-1].get("sep", false):
		entries.append({"sep": true})


## '다음'을 누를 때까지 기다린다(빨리 보기면 기다리지 않는다).
func _wait_tap() -> void:
	if _resume_to > 0 and steps_done < _resume_to:
		steps_done += 1  # 전에 이미 누른 '다음'
		if steps_done >= _resume_to:
			# 보던 단계에 닿았다: 다음 단계부터 다시 연출해서 보여 준다
			_resume_to = 0
			_skip = false
			_a_box.skip = false
			_b_box.skip = false
		return
	if _skip:
		return
	_tapped = false
	_next_btn.visible = true
	while not _tapped and not _skip:
		await get_tree().process_frame
	_next_btn.visible = false
	steps_done += 1
	GameData.patch_route("battle", {"step": steps_done})


## 맞은 카드에서 글자가 튀어나와 날아가며 사라진다(게임의 피해 숫자처럼).
func _float(text: String, from: Vector2, dir: Vector2, col: Color, size: int = 30) -> void:
	if _skip:
		return
	var l := UiKit.label(text, size, col)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 8)
	l.z_index = 15
	add_child(l)
	l.position = from - Vector2(40, 20)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position", l.position + dir, FLOAT_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, FLOAT_SEC * 0.4).set_delay(FLOAT_SEC * 0.6)  # 오래 보이다가 끝에만 흐려진다
	tw.chain().tween_callback(l.queue_free)


func _show_popup(text_lines: Array[String], at: Vector2) -> void:
	if text_lines.is_empty():
		_popup.visible = false
		return
	_popup_text.text = "\n".join(text_lines)
	_popup.visible = true
	_popup.reset_size()
	var vp := get_viewport_rect().size
	var p := at + Vector2(16, -_popup.size.y - 16)  # 손가락에 가리지 않게 위쪽
	_popup.position = Vector2(clampf(p.x, 8, vp.x - _popup.size.x - 8), clampf(p.y, 8, vp.y - _popup.size.y - 8))


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
			if ev.has("before"):  # 스킬로 전투 중에 다시 건 마법: 바뀐 능력치를 깜빡인다
				await _effect(ev)
			else:
				await _play_magic(ev)
		"enter":
			await _enter_group([ev] as Array[Dictionary])
		"skill", "skill_copy", "boss_ability":
			await _effect(ev)
		"clash":
			# 기록과 화면 값을 맞춘다(바뀐 것은 앞에서 이미 깜빡였다)
			_a_box.set_values(ev["a_atk"], ev["a_def"], ev["a_hp"])
			_b_box.set_values(ev["b_atk"], ev["b_def"], ev["b_hp"])
		"round":
			await _round(ev)
		"down":
			_fall_fx(_box(ev["side"]), ev["side"])
			if ev["side"] == Combatant.ALLY:
				_ally_cards[ev["idx"]].add_theme_color_override("font_color", UiKit.GRAY)
				_ally_cards[ev["idx"]].text += "  ✕"
			else:
				_enemy_cards[ev["idx"]].modulate = Color(1, 1, 1, 0.35)
			var who := _who(ev["side"], ev["idx"])
			_banner.text = t("ui.battle.down").format({"who": who})
			_log("✕ " + _banner.text, UiKit.BAD.darkened(0.2))
			if ev["side"] == Combatant.ALLY:
				GameData.vibrate()
			await _wait(maxf(STEP, FALL_SEC))
		"end":
			_banner.text = t("ui.battle.end").format({"kills": ev["kills"], "total": ev["total"]})
			_log("■ " + _banner.text, UiKit.ACCENT.darkened(0.3))


## 시작 마법을 알린다. 맞은 적이 이미 카드에 있으면 그 자리에서 효과를 깜빡인다(아니면 나올 때).
func _play_magic(ev: Dictionary) -> void:
	var idx: int = ev["target"]
	var target: String = _ctx.enemies[idx].word_id
	var text := t("ui.battle.magic_cast").format({"magic": GameText.magic_name(ev["id"]), "target": target,
		"damage": ev["damage"], "down": ev.get("atk_down", 0)})
	_banner.text = text
	_log("✦ " + text, UiKit.ACCENT.darkened(0.3))
	await _magic_card(String(ev["id"]))
	_pending_magic.erase(idx)
	if _magic_due.has(idx):
		var d: Dictionary = _magic_due[idx]
		_magic_due.erase(idx)
		_log("  " + t("ui.battle.h_magic_hit").format({"who": target, "h0": d["h0"], "h1": d["h1"], "a0": d["a0"], "a1": d["a1"]}), UiKit.BAD.darkened(0.2))
		_b_box.flash("atk", d["a0"], d["a1"], UiKit.BAD, FLASH, _skip)
		_float("-%d" % (int(d["h0"]) - int(d["h1"])), _b_box.card_center(), Vector2(-120, -170), UiKit.BAD, 40)
		await _b_box.flash("hp", d["h0"], d["h1"], UiKit.BAD, FLASH, _skip)
	elif not ev.get("live", false):
		_magic_on[idx] = {"damage": ev["damage"], "down": ev.get("atk_down", 0)}
	await _wait(STEP)


## 유닛이 나온다(잇달아 나오는 유닛은 함께): 코인 전 값으로 카드를 펴고 옆 목록에서 돌며 커져 나온다 →
## 함께 코인을 약 1초 돌려 앞뒤를 정한다 → (마법을 맞았으면 그 효과) → 코인 전→후 값이 함께 깜빡인다.
func _enter_group(evs: Array[Dictionary]) -> void:
	_turn.text = ""
	_sep()
	var ps: Array[Dictionary] = []
	var names: Array[String] = []
	for ev in evs:
		var side: int = ev["side"]
		var idx: int = ev["idx"]
		_cur[side] = idx
		var c: Combatant = _side_list(side)[idx]
		var who := _who(side, idx)
		var box := _box(side)
		var magic: Dictionary = _magic_on.get(idx, {}) if side == Combatant.ENEMY else {}
		var due: Dictionary = _pending_magic.get(idx, {}) if side == Combatant.ENEMY else {}
		var down := int(magic.get("down", 0)) + int(due.get("atk_down", 0))
		var atk0: int = int(ev["pre_atk"]) + down
		var hp0: int = int(ev["pre_hp"])
		# 마법을 아직 알리기 전이면, 카드에는 마법 전 값(코인까지)만 보여 주고 마법 효과는 알릴 때 깜빡인다
		var show_atk: int = int(ev["atk"]) + int(due.get("atk_down", 0))
		var show_hp: int = int(ev["hp"]) + (int(ev["magic_hit"]) if not due.is_empty() else 0)
		if not due.is_empty():
			_magic_due[idx] = {"a0": show_atk, "a1": ev["atk"], "h0": show_hp, "h1": ev["hp"]}
		box.show_now(c, who, atk0, ev["def"], hp0, _ctx.formula, false)
		box.coins.pending = not _skip  # 나오는 동안은 아직 던지지 않은 코인
		_grow_fx(box, side, idx)  # 함께 나온다(기다리지 않는다)
		names.append(who)
		ps.append({"ev": ev, "box": box, "who": who, "magic": magic, "atk0": atk0, "hp0": hp0,
			"show_atk": show_atk, "show_hp": show_hp})
	_banner.text = t("ui.battle.enter").format({"who": " · ".join(names)})
	await _wait(GROW_SEC + 0.1)
	# 코인: 다 같이 약 1초 돌다가 앞뒤가 정해진다
	for p in ps:
		var box: BattleCard = p["box"]
		box.coins.pending = false
		box.coins.set_flips(box.coins.flips, not _skip)
	await _wait(BattleCard.SPIN_SEC + 0.15)
	# 마법을 맞고 나온 적이면 그 효과
	var hit := false
	for p in ps:
		var magic: Dictionary = p["magic"]
		if magic.is_empty():
			continue
		hit = true
		var ev: Dictionary = p["ev"]
		var box: BattleCard = p["box"]
		var atk0: int = p["atk0"]
		var hp0: int = p["hp0"]
		_banner.text = t("ui.battle.magic_hit").format({"who": p["who"]})
		_log("  " + t("ui.battle.h_magic_hit").format({"who": p["who"], "h0": hp0, "h1": hp0 - int(ev["magic_hit"]),
			"a0": atk0, "a1": atk0 - int(magic["down"])}), UiKit.BAD.darkened(0.2))
		box.flash("atk", atk0, atk0 - int(magic["down"]), UiKit.BAD, FLASH, _skip)
		box.flash("hp", hp0, hp0 - int(ev["magic_hit"]), UiKit.BAD, FLASH, _skip)
		p["atk0"] = atk0 - int(magic["down"])
		p["hp0"] = hp0 - int(ev["magic_hit"])
	if hit:
		await _wait(FLASH + 0.05)
	# 코인 전→후 값이 함께 깜빡인다
	var changed: Array[String] = []
	for p in ps:
		var ev: Dictionary = p["ev"]
		var box: BattleCard = p["box"]
		var parts: Array[String] = []
		if int(ev["gain_atk"]) != 0:
			parts.append(t("ui.battle.atk") + " %d→%d" % [p["atk0"], p["show_atk"]])
			box.flash("atk", p["atk0"], p["show_atk"], UiKit.ACCENT.darkened(0.2), FLASH, _skip)
		if int(ev["gain_hp"]) != 0:
			parts.append(t("ui.battle.hp") + " %d→%d" % [p["hp0"], p["show_hp"]])
			box.flash("hp", p["hp0"], p["show_hp"], UiKit.ACCENT.darkened(0.2), FLASH, _skip)
		_log(t("ui.battle.h_enter").format({"who": p["who"], "coins": _coin_text(ev["flips"]),
			"change": ", ".join(parts) if not parts.is_empty() else t("ui.battle.h_no_change")}))
		if not parts.is_empty():
			changed.append(p["who"])
	if not changed.is_empty():
		_banner.text = t("ui.battle.coin_change").format({"who": " · ".join(changed)})
		await _wait(FLASH + 0.1)
	for p in ps:
		var ev: Dictionary = p["ev"]
		(p["box"] as BattleCard).set_values(p["show_atk"], ev["def"], p["show_hp"])


## 등장: 옆(아군은 왼쪽, 적은 오른쪽) 목록의 작은 카드 자리에서 한 바퀴 돌며 점점 커져 가운데 자리로 나온다.
## 기다리지 않고 바로 돌아온다(코인이 도는 동안 함께 움직인다). 쓰러졌던 모습도 여기서 되돌린다.
func _grow_fx(box: BattleCard, side: int, idx: int) -> void:
	box.rotation_degrees = 0.0
	box.scale = Vector2.ONE
	if _skip:
		box.modulate = Color.WHITE
		return
	# 내용이 바뀐 카드는 상자(HBox)가 다음 프레임에 자리를 다시 잡는다: 그동안 숨겨 두고 기다린다
	box.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	box.modulate = Color.WHITE
	if _skip:
		return
	var src: Control = _ally_cards[idx].get_parent().get_parent() if side == Combatant.ALLY else _enemy_cards[idx]
	var rest := box.position
	box.pivot_offset = box.size / 2.0
	var from := src.get_global_rect().get_center() - box.get_global_rect().get_center()
	var small := clampf(src.size.y / maxf(1.0, box.size.y), 0.15, 0.5)
	box.position = rest + from
	box.scale = Vector2(small, small)
	box.modulate.a = 0.4
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "position", rest, GROW_SEC)
	tw.tween_property(box, "scale", Vector2.ONE, GROW_SEC)
	tw.tween_property(box, "modulate:a", 1.0, GROW_SEC * 0.6)
	box.rotation_degrees = -360.0 if side == Combatant.ALLY else 360.0  # 뱅그르르 돌며 나온다
	tw.tween_property(box, "rotation_degrees", 0.0, GROW_SEC).set_trans(Tween.TRANS_CUBIC)


## 마법 카드: 왼쪽 아래 마법 버튼 자리에서 돌며 커져 나와(유닛 카드 등장과 같은 모양) 종류에 맞는 자리에 놓이고,
## 그 마법의 이펙트가 대상 카드 위(가운데 마법은 두 카드 사이)에서 터진 뒤 카드가 흐려져 사라진다.
func _magic_card(id: String) -> void:
	var kind := String(GameData.bal.magic_def(id).get("kind", "effect"))
	var d := MagicFx.def_of(id)
	var col := Color(String(d["color"]))
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.lightened(0.55)
	sb.border_color = col.darkened(0.3)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 15
	var l := UiKit.label("✦ " + GameText.magic_name(id), 26, UiKit.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(l)
	add_child(card)
	card.set_meta("kind", kind)
	last_magic_card = card
	await get_tree().process_frame  # 크기가 잡힌 뒤
	if not is_instance_valid(card):
		return
	var a_rect := _a_box.get_global_rect()
	var b_rect := _b_box.get_global_rect()
	var at := MagicFx.anchor(kind, a_rect, b_rect)
	var fx_at: Vector2 = b_rect.get_center() if kind == "attack" else (a_rect.get_center() if kind == "defense" else (a_rect.get_center() + b_rect.get_center()) / 2.0)
	card.pivot_offset = card.size / 2.0
	var rest := at - card.size / 2.0
	card.set_meta("rest", rest + card.size / 2.0)
	if _skip:
		card.global_position = rest
		card.queue_free()
		return
	card.global_position = _magic_btn.get_global_rect().get_center() - card.size / 2.0
	card.scale = Vector2(0.3, 0.3)
	card.rotation_degrees = -360.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "global_position", rest, MAGIC_FLY)
	tw.tween_property(card, "scale", Vector2.ONE, MAGIC_FLY)
	tw.tween_property(card, "rotation_degrees", 0.0, MAGIC_FLY).set_trans(Tween.TRANS_CUBIC)
	await _wait(MAGIC_FLY)
	var fx := MagicFx.new()
	fx.id = id
	fx.style = String(d["style"])
	fx.col = col
	add_child(fx)
	fx.global_position = fx_at
	GameData.vibrate()
	await _wait(MagicFx.LIFE * 0.8)
	if is_instance_valid(card):
		var out := create_tween()
		out.tween_property(card, "modulate:a", 0.0, 0.35)
		out.tween_callback(card.queue_free)


## 쓰러짐: 카드 밑을 축으로 상대 쪽(앞)으로 기울며 납작해지고, 깜빡깜빡하다가 흐려져 사라진다.
func _fall_fx(box: BattleCard, side: int) -> void:
	var lean := 16.0 if side == Combatant.ALLY else -16.0
	if _skip:
		box.rotation_degrees = lean
		box.scale = Vector2(1.0, 0.55)
		box.modulate.a = 0.0
		return
	box.pivot_offset = Vector2(box.size.x / 2.0, box.size.y)
	var fall := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(box, "rotation_degrees", lean, FALL_SEC * 0.45)
	fall.tween_property(box, "scale", Vector2(1.0, 0.55), FALL_SEC * 0.45)  # 앞으로 눕듯 납작해진다
	var blink := create_tween()
	for k in 3:  # 깜빡깜빡
		blink.tween_property(box, "modulate:a", 0.25, 0.1)
		blink.tween_property(box, "modulate:a", 1.0, 0.1)
	blink.tween_property(box, "modulate:a", 0.0, FALL_SEC - 0.6)  # 그리고 서서히 사라진다


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
		"magic":
			text = t("ui.battle.magic_cast").format({"magic": GameText.magic_name(ev["id"]), "target": _ctx.enemies[ev["target"]].word_id,
				"damage": ev["damage"], "down": ev.get("atk_down", 0)})
	_banner.text = text
	if ev["t"] == "magic":
		await _magic_card(String(ev["id"]))
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
	_log("✦ " + text + "  " + (", ".join(changes) if not changes.is_empty() else t("ui.battle.h_nothing")), UiKit.ACCENT.darkened(0.3))
	await _wait(maxf(STEP, FLASH + 0.1) if not changes.is_empty() else STEP)


## 한 턴: 가운데 "N턴"을 띄우고, 서로 공격해 깎인 체력을 빨갛게 깜빡인다.
func _round(ev: Dictionary) -> void:
	_sep()
	_turn_n += 1  # 적이 바뀌어도 전투 처음부터 이어서 센다
	_turn.text = t("ui.battle.turn").format({"n": _turn_n})
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
	_log(t("ui.battle.h_round").format({"n": _turn_n, "a": a, "b": b, "to_b": ev["to_b"], "to_a": ev["to_a"],
		"bh0": bh0, "bh": ev["b_hp"], "ah0": ah0, "ah": ev["a_hp"]}) + first)
	await _clash_fx(ev, ah0, bh0)


## 부딪히기: 두 카드가 서로 기울며 다가가 가운데서 부딪힌다 → 충격 이펙트, 카드 흔들림, 깎인 체력 빨간 깜빡임,
## 맞은 카드에서 단어 뜻과 피해 숫자가 튀어나온다 → 카드는 제자리로 돌아온다.
func _clash_fx(ev: Dictionary, ah0: int, bh0: int) -> void:
	var a0 := _a_box.position
	var b0 := _b_box.position
	if not _skip:
		_a_box.pivot_offset = _a_box.size / 2.0
		_b_box.pivot_offset = _b_box.size / 2.0
		var gap := (_b_box.global_position.x - (_a_box.global_position.x + _a_box.size.x)) / 2.0
		var go := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		go.tween_property(_a_box, "position", a0 + Vector2(gap + 10, 0), 0.25)
		go.tween_property(_a_box, "rotation_degrees", 9.0, 0.25)
		go.tween_property(_b_box, "position", b0 - Vector2(gap + 10, 0), 0.25)
		go.tween_property(_b_box, "rotation_degrees", -9.0, 0.25)
		await go.finished
		# 부딪힌 자리(두 카드 사이)에 충격 이펙트
		var fx := ImpactFx.new()
		add_child(fx)
		fx.global_position = (_a_box.card_center() + _b_box.card_center()) / 2.0
		GameData.vibrate()
		var shake := create_tween()
		for k in 4:  # 부딪혀서 흔들린다
			var d := Vector2(8 if k % 2 == 0 else -8, 3 if k % 2 == 0 else -3)
			shake.tween_property(_a_box, "position", a0 + Vector2(gap + 10, 0) - d, 0.05)
			shake.parallel().tween_property(_b_box, "position", b0 - Vector2(gap + 10, 0) + d, 0.05)
	_b_box.flash("hp", bh0, ev["b_hp"], UiKit.BAD, FLASH, _skip)
	_a_box.flash("hp", ah0, ev["a_hp"], UiKit.BAD, FLASH, _skip)
	# 맞은 카드에서: 한쪽으로는 단어 뜻이, 다른 쪽으로는 깎인 체력이 튀어나온다
	var ew := GameData.repo.get_word(_ctx.enemies[_cur[Combatant.ENEMY]].word_id)
	if int(ev["to_b"]) > 0:
		if ew:
			_float(ew.meaning, _b_box.card_center(), Vector2(150, -150), UiKit.ACCENT.darkened(0.35), 26)
		_float("-%d" % ev["to_b"], _b_box.card_center(), Vector2(60, 190), UiKit.BAD, 40)
	if int(ev["to_a"]) > 0:
		_float("-%d" % ev["to_a"], _a_box.card_center(), Vector2(-120, -170), UiKit.BAD, 40)
	await _wait(FLASH + 0.15)
	if not _skip:
		var back := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		back.tween_property(_a_box, "position", a0, 0.3)
		back.tween_property(_a_box, "rotation_degrees", 0.0, 0.3)
		back.tween_property(_b_box, "position", b0, 0.3)
		back.tween_property(_b_box, "rotation_degrees", 0.0, 0.3)
		await back.finished
	else:
		_a_box.position = a0
		_b_box.position = b0
		_a_box.rotation_degrees = 0.0
		_b_box.rotation_degrees = 0.0


## 옆 목록의 카드를 누르고 있으면, 누른 자리에 그 유닛의 정보 창을 띄운다(전투 중에도).
func _hold_side(card: Control, side: int, idx: int) -> void:
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
			return
		if ev.pressed:
			var c: Combatant = _side_list(side)[idx]
			var tmp := BattleCard.new()
			tmp.show_now(c, _who(side, idx), c.atk, c.def, maxi(0, c.hp), _ctx.formula)
			_show_popup(_info(c, tmp.base_lines()), card.get_global_transform_with_canvas() * ev.position)
			tmp.free()
		else:
			_show_popup([] as Array[String], Vector2.ZERO))


## 정보 창의 글: 처음 능력치 + (적) 뜻·속성·어원·스킬 / (아군) 착용한 스킬과 설명.
func _info(c: Combatant, base: Array[String]) -> Array[String]:
	var out: Array[String] = base.duplicate()
	if c.side == Combatant.ENEMY:
		var w := GameData.repo.get_word(c.word_id)
		if w:
			out.append(t("ui.battle.info_meaning").format({"v": w.meaning}))
			out.append(t("ui.battle.info_attr").format({"v": GameText.attrs_text(w)}))
			out.append(t("ui.battle.info_etym").format({"v": GameText.etym_text(w)}))
	var skill := GameText.root_desc(c.skill_root) if c.skill_root != "" else t("ui.battle.info_no_skill")
	out.append(t("ui.battle.info_skill").format({"v": skill}))
	if c.boss_ability:
		var key := "sys.boss.%s.desc" % c.word_id
		var desc := t(key)
		out.append(t("ui.battle.info_boss_v").format({"v": desc.format(c.boss_ability.params) if desc != key else t("ui.battle.info_boss")}))
	return out
