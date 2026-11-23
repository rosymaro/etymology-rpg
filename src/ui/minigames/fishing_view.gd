class_name FishingView
extends MinigameScreen
## 5 낚시: 위의 낚싯줄에 영어 단어, 물속에는 뜻이 적힌 물고기가 헤엄친다. 그 단어의 뜻인 물고기를 누르면 낚는다.

var _canvas: Control
var _word: Label
var _msg: Label


func build() -> void:
	var top := UiKit.hbox(20)
	top.position = Vector2(40, 0)
	body.add_child(top)
	top.add_child(UiKit.label(t("ui.mini.fishing.hook"), 24))
	_word = UiKit.label("", 44)
	top.add_child(_word)
	_msg = UiKit.label("", 22, UiKit.ACCENT.darkened(0.2))
	top.add_child(_msg)
	_canvas = Control.new()
	_canvas.position = Vector2(40, 70)
	_canvas.custom_minimum_size = FishingGame.AREA + Vector2(160, 40)
	_canvas.draw.connect(_draw_sea)
	_canvas.gui_input.connect(_input)
	body.add_child(_canvas)


func _scale() -> Vector2:
	return (_canvas.size - Vector2(0, 40)) / FishingGame.AREA


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var g := game as FishingGame
	var s := _scale()
	for i in g.fish.size():
		if _fish_rect(g.fish[i], s).has_point(ev.position):
			var right_word := g.current()
			if g.catch(i):
				_msg.text = t("ui.quiz.right")
				GameData.vibrate(true)
			else:
				_msg.text = t("ui.mini.fishing.wrong").format({"word": right_word.id, "meaning": right_word.meaning})
				GameData.vibrate()
			changed()
			return


func _fish_rect(f: Dictionary, s: Vector2) -> Rect2:
	var p: Vector2 = f["pos"] * s + Vector2(0, 40)
	return Rect2(p - Vector2(130, 30), Vector2(260, 60))


func refresh() -> void:
	var g := game as FishingGame
	_word.text = g.current().id if g.current() else ""


func tick(_d: float) -> void:
	_canvas.queue_redraw()


func _draw_sea() -> void:
	var g := game as FishingGame
	var s := _scale()
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2(0, 40), _canvas.size - Vector2(0, 40)), Color("bfe3f0"))
	_canvas.draw_line(Vector2(_canvas.size.x / 2, 0), Vector2(_canvas.size.x / 2, 40), UiKit.INK, 3)
	for f in g.fish:
		var r := _fish_rect(f, s)
		var w := g.words[f["w"]]
		if not Art.draw(_canvas, "mini", "fish_meaning", r.get_center(), r.size + Vector2(40, 20)):
			_canvas.draw_style_box(UiKit.box(Color("fff3c4"), 30, 3), r)
			var tail := r.position + Vector2(r.size.x if f["vx"] < 0 else 0, r.size.y / 2)
			var d := 1.0 if f["vx"] < 0 else -1.0
			_canvas.draw_colored_polygon([tail, tail + Vector2(22 * d, -16), tail + Vector2(22 * d, 16)], Color("ffd59e"))
		_canvas.draw_string(font, r.position + Vector2(8, 38), w.meaning, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16, 20, UiKit.INK)
