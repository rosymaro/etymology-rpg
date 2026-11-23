class_name GuardView
extends MinigameScreen
## 8 보초 서기: 성문으로 단어와 뜻이 하나씩 온다. 맞는 짝이면 통과, 틀린 짝이면 막기.

var _word: Label
var _meaning: Label
var _msg: Label
var _left: Label


func build() -> void:
	var c := CenterContainer.new()
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	body.add_child(c)
	var v := UiKit.vbox(16)
	c.add_child(v)
	var gate := UiKit.card(UiKit.PAPER)
	gate.custom_minimum_size = Vector2(760, 0)
	var gv := UiKit.vbox(8)
	gate.add_child(gv)
	gv.add_child(UiKit.label(t("ui.mini.guard.ask"), 22))
	_word = UiKit.label("", 52)
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(_word)
	_meaning = UiKit.wrap(UiKit.label("", 30), 700)
	_meaning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(_meaning)
	v.add_child(gate)
	var h := UiKit.hbox(40)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var pass_b := UiKit.button(t("ui.mini.guard.pass"), func() -> void: _judge(true), UiKit.LEAF, 30)
	pass_b.custom_minimum_size = Vector2(300, 100)
	var stop_b := UiKit.button(t("ui.mini.guard.stop"), func() -> void: _judge(false), UiKit.PINK, 30)
	stop_b.custom_minimum_size = Vector2(300, 100)
	h.add_child(pass_b)
	h.add_child(stop_b)
	v.add_child(h)
	_msg = UiKit.wrap(UiKit.label("", 24, UiKit.ACCENT.darkened(0.2)), 760)
	v.add_child(_msg)
	_left = UiKit.label("", 20)
	v.add_child(_left)


func _judge(pass_gate: bool) -> void:
	var g := game as GuardGame
	var ok := g.judge(pass_gate)
	var tr_: Dictionary = g.last.get("traveler", {})
	if tr_.is_empty():
		return
	var w := g.words[tr_["w"]]
	if ok:
		_msg.text = t("ui.quiz.right")
	else:
		_msg.text = t("ui.mini.guard.wrong").format({"word": w.id, "meaning": w.meaning})
		GameData.vibrate()
	changed()


func refresh() -> void:
	var g := game as GuardGame
	var cur := g.current()
	if cur.is_empty():
		return
	_word.text = g.words[cur["w"]].id
	_meaning.text = cur["shown"]
	_left.text = t("ui.mini.guard.left").format({"n": g.travelers.size() - g.index, "miss": g.misses, "max": int(g.cfg["max_miss"])})
