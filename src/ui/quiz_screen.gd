class_name QuizScreen
extends Screen
## 뜻 고르기 4지선다를 차례로 낸다. 조우·게시판·진화가 함께 쓴다. 다 풀면 done(맞음 목록)을 부른다.
## 조우는 맞힌 단어는 잡고, 틀린 단어만 전투로 간다(01-rpg-base '조우'). 진화는 문제 전에 어원 풀이를 보여 준다(02-rpg-v2).
## 조우는 유추 문제다(06-learning.md): 이긴 보스에 따라 조각을 뜻과 함께 / 뜻은 ?로 / 나누지 않고 보여 주고,
## 고른 뒤에는 언제나 풀이(조각 뜻 → 단어 뜻)를 보여 준다. 조각마다 맞힌 수를 남긴다.

var _qs: Array[QuizQuestion] = []
var _i := 0
var _right: Array[bool] = []
var _done: Callable
var _mode := ""
var _target := ""
var _word_lbl: Label
var _info_lbl: Label
var _prog: Label
var _opts: VBoxContainer
var _locked := false
var _parts_row: HBoxContainer  ## 조각 칩(단어를 조각으로 나눠 보여 줄 때)
var _hint_lbl: Label
var _next_btn: Button  ## 풀이 뒤 다음(사용자 의견: 다 읽고 누를 때 넘어간다)
var _ask_ms := 0  ## 이 시각 전에는 보기를 누를 수 없다


func open(args: Dictionary) -> void:
	_mode = args["mode"]
	_done = args["done"]
	_target = args.get("target", "")
	var ids: Array[String] = args["words"]
	if _mode == "encounter":  # 유추 문제
		var iq := InferenceQuiz.new(GameData.repo, GameData.curriculum, GameData.learning, GameData.rng)
		for id in ids:
			_qs.append(iq.question(id, GameFlow.cur(), GameData.state.flags, int(args.get("step_bonus", 0))))
	else:
		_qs = QuizBuilder.new(GameData.repo, GameData.rng).build(ids)
	# 이어 하기: 풀던 문제부터(앞에서 맞고 틀린 것은 그대로)
	_i = mini(int(args.get("resume_i", 0)), _qs.size())
	for x in args.get("resume_right", []):
		_right.append(bool(x))
	var popup: bool = args.get("popup", false)
	if popup:  # 사용자 의견: 필드 위 아래쪽 반 화면 창(몹 자리가 그대로, 끊기지 않게)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var panel := Panel.new()
		var st := UiKit.box(UiKit.SKY, 28, 3)
		st.corner_radius_bottom_left = 0
		st.corner_radius_bottom_right = 0
		st.shadow_size = 10
		st.shadow_offset = Vector2(0, -4)
		panel.add_theme_stylebox_override("panel", st)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.offset_bottom = UiKit.BG_BLEED  # 화면 아래 여백까지
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
	else:
		UiKit.fill_bg(self, UiKit.SKY if _mode == "encounter" else UiKit.PAPER)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20 if popup and side == "top" else 32)
	add_child(margin)
	var v := UiKit.vbox(14)
	margin.add_child(v)
	var head := UiKit.hbox()
	v.add_child(head)
	var title := UiKit.wrap(UiKit.label(t("ui.quiz.title_" + _mode), 28))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_prog = UiKit.label("", 26)
	head.add_child(_prog)
	var gap := Control.new()  # 세로 화면: 단어와 보기는 엄지가 닿는 아래쪽에
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.size_flags_stretch_ratio = 0.6
	v.add_child(gap)
	_word_lbl = UiKit.label("", 46 if popup else 54)
	_word_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_word_lbl)
	_parts_row = UiKit.hbox(6)
	_parts_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_parts_row)
	_hint_lbl = UiKit.wrap(UiKit.label("", 22, UiKit.ACCENT.darkened(0.3)))
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_hint_lbl)
	_info_lbl = UiKit.wrap(UiKit.label("", 22, UiKit.INK.lightened(0.25)))
	_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_info_lbl)
	v.add_child(UiKit.label(t("ui.quiz.pick_meaning"), 24))
	_opts = UiKit.vbox(10)
	v.add_child(_opts)
	# 4번째 보기 가운데가 엄지 자리(UiKit.THUMB_ROW)에 오게: 아래 여백 32, 줄 간격 14를 빼고 남는 만큼 띄운다
	# 그 아래 남는 자리에 풀이 뒤 '다음' 버튼(보기와 겹치지 않게)
	var gap2 := CenterContainer.new()
	gap2.custom_minimum_size.y = UiKit.THUMB_ROW - UiKit.THUMB_H / 2.0 - 32.0 - 14.0
	v.add_child(gap2)
	_next_btn = UiKit.button(t("ui.quiz.next"), _next, UiKit.ACCENT.lightened(0.35), 26)
	_next_btn.custom_minimum_size = Vector2(260, UiKit.THUMB_H)
	_next_btn.visible = false
	gap2.add_child(_next_btn)
	if _mode == "encounter":
		_tutorial.call_deferred()
	if _i >= _qs.size():
		_done.call_deferred(_right)
	elif _mode == "evolve" and _i == 0:
		_intro_evolve()
	else:
		_show()


func _intro_evolve() -> void:
	var w := GameData.repo.get_word(_target)
	var parts: Array[String] = []
	for e in w.etym:
		parts.append("%s(%s)" % [e.get("root", ""), e.get("meaning", "")])
	main.notice(t("ui.evolve.intro").format({"word": w.id, "mats": " + ".join(w.mats),
		"etym": " + ".join(parts)}), _show)


func _show() -> void:
	_locked = false
	_next_btn.visible = false
	for c in _opts.get_children():
		c.queue_free()
	var q := _qs[_i]
	var w := GameData.repo.get_word(q.word_id)
	_prog.text = "%d / %d" % [_i + 1, _qs.size()]
	_word_lbl.text = w.id
	_word_lbl.add_theme_color_override("font_color", WordCard.OWNED if WordCard.is_owned(w) else WordCard.FRESH)
	_info_lbl.text = w.ipa
	_show_parts(q, false)
	for k in q.options.size():
		var idx := k
		var b := UiKit.button(q.options[k], func() -> void:
			if Time.get_ticks_msec() >= _ask_ms:
				_pick(idx), UiKit.PAPER, 26)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, UiKit.THUMB_H)
		b.clip_text = true
		b.disabled = true  # 잠깐 뒤에 누를 수 있다(흐리게 보였다가 또렷해진다)
		_opts.add_child(b)
	var delay := float(GameData.learning.get("answer_delay_sec", 0.7))
	_ask_ms = Time.get_ticks_msec() + int(delay * 1000.0)
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		for c in _opts.get_children():
			if c is Button and not _locked:
				(c as Button).disabled = false)


## 조각 칩: 나눠 보여 줄 때(단계 A·B)나 풀이 때. 그 위에 원래 단어, 칩마다 위에 단어 조각, 아래에 조각 뜻(B는 "?").
## 단계 C는 영어 단어만 보인다.
func _show_parts(q: QuizQuestion, reveal: bool) -> void:
	for c in _parts_row.get_children():
		c.queue_free()
	_hint_lbl.text = ""
	if not q is InferenceQuestion:
		return
	var iq := q as InferenceQuestion
	var split := reveal or iq.show_split
	# 나눠 보일 때도 위에 원래 단어를 보인다(사용자 의견: 조각만 있으면 무슨 단어였는지 모른다). 조각이 주인공이니 조금 작게
	_word_lbl.visible = true
	_word_lbl.add_theme_font_size_override("font_size", 40 if split else 54)
	if not split:  # 단계 C: 영어 단어만(사용자 의견)
		return
	for p in iq.parts:
		var piece := String(p["piece"]) != ""
		var col: Color = UiKit.PAPER
		if piece:
			col = UiKit.ACCENT.lightened(0.55) if p["learned"] else UiKit.SKY.lightened(0.3)
		var card := UiKit.card(col)
		var box := UiKit.vbox(2)
		card.add_child(box)
		var top := UiKit.label(String(p["text"]), 44 if piece else 36, UiKit.INK if piece else UiKit.INK.lightened(0.35))
		top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(top)
		var m := ""
		if piece:
			m = String(p["meaning"]) if (reveal or p["shown"]) else "?"
		var bottom := UiKit.label(m, 20, UiKit.LEAF.darkened(0.35) if reveal and p["learned"] else UiKit.INK.lightened(0.2))
		bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(bottom)
		if not piece:
			card.self_modulate = Color(1, 1, 1, 0.6)
		_parts_row.add_child(card)
		if reveal and not _skip_anim():
			card.pivot_offset = Vector2(40, 40)
			card.scale = Vector2(0.8, 0.8)
			create_tween().tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	if reveal:
		_hint_lbl.text = iq.explain(GameData.repo.get_word(iq.word_id).meaning)
	else:
		_hint_lbl.text = t("ui.quiz.infer_hint")


## 처음 조우 퀴즈(08-tutorial.md): 조각 칩 → 보기.
func _tutorial() -> void:
	await get_tree().process_frame
	var steps: Array[Dictionary] = []
	if _parts_row.get_child_count() > 0:
		steps.append({"target": _parts_row, "text": "tut.quiz.parts", "mode": "any", "args": {"ex": _parts_example()}})
	steps.append({"target": _word_lbl if _word_lbl.visible else _parts_row, "text": "tut.quiz.word", "mode": "any"})
	steps.append({"target": _opts, "text": "tut.quiz.pick", "mode": "any"})
	TutorialOverlay.run(self, "quiz", steps)


## 튜토리얼 예: 지금 문제 단어의 조각과 뜻(예: "in(안에) + form(모양)"). 몹의 단어와 같은 단어로 설명한다.
func _parts_example() -> String:
	if _i >= _qs.size() or not _qs[_i] is InferenceQuestion:
		return ""
	var bits: Array[String] = []
	for p in (_qs[_i] as InferenceQuestion).parts:
		if String(p["piece"]) == "":
			continue
		bits.append("%s(%s)" % [p["text"], p["meaning"]] if p["shown"] else String(p["text"]))
	return " + ".join(bits)


func _skip_anim() -> bool:
	return false


func _pick(k: int) -> void:
	if _locked:
		return
	_locked = true
	var q := _qs[_i]
	var ok := q.is_correct(k)
	_right.append(ok)
	var btns := _opts.get_children()
	(btns[q.answer] as Button).add_theme_stylebox_override("normal", UiKit.box(UiKit.GOOD.lightened(0.4), 30))
	(btns[q.answer] as Button).add_theme_stylebox_override("disabled", UiKit.box(UiKit.GOOD.lightened(0.4), 30))
	if not ok:
		(btns[k] as Button).add_theme_stylebox_override("normal", UiKit.box(UiKit.BAD.lightened(0.3), 30))
		GameData.vibrate()
	var w := GameData.repo.get_word(q.word_id)
	var ex: Dictionary = w.example
	_info_lbl.text = t("ui.quiz.right" if ok else "ui.quiz.wrong") + "  " + w.meaning + ("\n" + str(ex.get("en", "")) if ex.has("en") else "")
	for c in btns:  # 고른 뒤에는 보기를 누를 수 없다(색은 그대로)
		var bb := c as Button
		bb.add_theme_stylebox_override("disabled", bb.get_theme_stylebox("normal"))
		bb.add_theme_color_override("font_disabled_color", UiKit.INK)
		bb.disabled = true
	if q is InferenceQuestion:  # 풀이: 조각 뜻이 이어져 단어 뜻이 된다
		var iq := q as InferenceQuestion
		_show_parts(iq, true)
		if iq.kind == "infer":
			InferenceQuiz.record(GameData.state.pieces, iq, ok)
	GameData.patch_route("evolve_quiz" if _mode == "evolve" else "quiz", {"i": _i + 1, "right": _right})
	_next_btn.visible = true
	_next_btn.disabled = true
	get_tree().create_timer(float(GameData.learning.get("next_delay_sec", 0.4))).timeout.connect(func() -> void:
		_next_btn.disabled = false)


## 풀이를 다 읽고 다음 문제로(마지막이면 끝)
func _next() -> void:
	if not _locked:
		return
	_next_btn.visible = false
	_i += 1
	if _i < _qs.size():
		_show()
	else:
		_done.call(_right)
