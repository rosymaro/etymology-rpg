class_name CopyView
extends MinigameScreen
## 6 필사: 뜻과 어원을 보고, 섞인 글자 타일을 차례로 눌러 철자를 맞춘다.

var _hint: Label
var _typed: Label
var _tiles: HBoxContainer
var _msg: Label


func build() -> void:
	var v := UiKit.vbox(16)
	v.position = Vector2(40, 10)
	v.custom_minimum_size = Vector2(1200, 0)
	body.add_child(v)
	_hint = UiKit.label("", 28)
	v.add_child(_hint)
	_typed = UiKit.label("", 54)
	v.add_child(_typed)
	_tiles = UiKit.hbox(10)
	v.add_child(_tiles)
	var h := UiKit.hbox()
	h.add_child(UiKit.button(t("ui.mini.copy.undo"), func() -> void:
		(game as AnagramGame).undo()
		changed(), UiKit.PAPER, 22))
	h.add_child(UiKit.button(t("ui.mini.copy.skip"), func() -> void:
		(game as AnagramGame).skip()
		changed(), UiKit.PINK, 22))
	v.add_child(h)
	_msg = UiKit.label("", 24, UiKit.ACCENT.darkened(0.2))
	v.add_child(_msg)


func refresh() -> void:
	var g := game as AnagramGame
	var w := g.current()
	if w == null:
		return
	var parts: Array[String] = []
	for e in w.etym:
		parts.append("%s(%s)" % [e.get("root", ""), e.get("meaning", "")])
	_hint.text = t("ui.mini.copy.hint").format({"meaning": w.meaning, "etym": " + ".join(parts)})
	var s := g.typed()
	_typed.text = s.to_upper() + " _".repeat(g.tiles.size() - s.length())
	for c in _tiles.get_children():
		c.queue_free()
	for i in g.tiles.size():
		var idx := i
		var b := UiKit.button(g.tiles[i].to_upper(), func() -> void:
			var r := g.pick(idx)
			if r == "wrong":
				_msg.text = t("ui.mini.copy.wrong")
				GameData.vibrate()
			elif r == "right":
				_msg.text = t("ui.quiz.right")
			elif r == "skip":
				_msg.text = t("ui.mini.copy.answer").format({"word": w.id})
			changed(), UiKit.APRICOT if not i in g.used else UiKit.GRAY, 32)
		b.disabled = i in g.used
		b.custom_minimum_size = Vector2(84, 96)
		_tiles.add_child(b)
