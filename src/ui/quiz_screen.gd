class_name QuizScreen
extends Screen
## 뜻 고르기 4지선다를 차례로 낸다. 조우·게시판·진화가 함께 쓴다. 다 풀면 done(맞음 목록)을 부른다.
## 조우는 하나라도 틀리면 전투로 간다(01-rpg-base '조우'). 진화는 문제 전에 어원 풀이를 보여 준다(02-rpg-v2).

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


func open(args: Dictionary) -> void:
	_mode = args["mode"]
	_done = args["done"]
	_target = args.get("target", "")
	var ids: Array[String] = args["words"]
	_qs = QuizBuilder.new(GameData.repo, GameData.rng).build(ids)
	UiKit.fill_bg(self, UiKit.SKY if _mode == "encounter" else UiKit.PAPER)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var v := UiKit.vbox(14)
	margin.add_child(v)
	var head := UiKit.hbox()
	v.add_child(head)
	var title := UiKit.label(t("ui.quiz.title_" + _mode), 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_prog = UiKit.label("", 26)
	head.add_child(_prog)
	_word_lbl = UiKit.label("", 54)
	_word_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_word_lbl)
	_info_lbl = UiKit.wrap(UiKit.label("", 22, UiKit.INK.lightened(0.25)))
	_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_info_lbl)
	v.add_child(UiKit.label(t("ui.quiz.pick_meaning"), 24))
	_opts = UiKit.vbox(10)
	_opts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_opts)
	if _mode == "evolve":
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
	for c in _opts.get_children():
		c.queue_free()
	var q := _qs[_i]
	var w := GameData.repo.get_word(q.word_id)
	_prog.text = "%d / %d" % [_i + 1, _qs.size()]
	_word_lbl.text = w.id
	_info_lbl.text = w.ipa
	for k in q.options.size():
		var idx := k
		var b := UiKit.button(q.options[k], func() -> void: _pick(idx), UiKit.PAPER, 26)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 70)
		b.clip_text = true
		_opts.add_child(b)


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
	await get_tree().create_timer(1.1 if ok else 1.8).timeout
	_i += 1
	if _i < _qs.size():
		_show()
	else:
		_done.call(_right)
