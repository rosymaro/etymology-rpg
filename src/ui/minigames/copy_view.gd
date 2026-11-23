class_name CopyView
extends MinigameScreen
## 6 필사: 뜻과 어원을 보고, 얼음에 갇힌 글자를 두드려 깬 뒤 끌어서 칸에 놓아 철자를 맞춘다.

const TILE := Vector2(80, 92)
const GAP := 12.0

var _canvas: Control
var _hint: Label
var _msg: Label
var _drag := -1
var _drag_pos := Vector2.ZERO
var _press_pos := Vector2.ZERO
var _shake: Dictionary = {}  ## 타일 -> 남은 흔들림 시간


func build() -> void:
	var v := UiKit.vbox(10)
	v.position = Vector2(40, 6)
	body.add_child(v)
	_hint = UiKit.wrap(UiKit.label("", 26), 1150)
	v.add_child(_hint)
	_canvas = Control.new()
	_canvas.anchor_right = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.offset_top = 90
	_canvas.offset_bottom = -90
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_desk)
	_canvas.gui_input.connect(_on_canvas_input)
	body.add_child(_canvas)
	var h := UiKit.hbox()
	body.add_child(h)
	UiKit.pin(h, 0, 1, 40, -80)
	h.add_child(UiKit.button(t("ui.mini.copy.skip"), func() -> void:
		(game as AnagramGame).skip()
		_after(), UiKit.PINK, 22))
	_msg = UiKit.label("", 24, UiKit.ACCENT.darkened(0.2))
	h.add_child(_msg)


func _row_x(n: int, k: int) -> float:
	var total := n * TILE.x + (n - 1) * GAP
	return (_canvas.size.x - total) / 2.0 + k * (TILE.x + GAP)


func _slot_rect(k: int) -> Rect2:
	return Rect2(Vector2(_row_x((game as AnagramGame).slots.size(), k), 30), TILE)


## 아래 줄(얼음 칸)의 타일 자리
func _tray_rect(i: int) -> Rect2:
	return Rect2(Vector2(_row_x((game as AnagramGame).tiles.size(), i), 230), TILE)


func _tile_rect(i: int) -> Rect2:
	var g := game as AnagramGame
	if i == _drag:
		return Rect2(_drag_pos - TILE / 2, TILE)
	var k := g.slot_of(i)
	return _slot_rect(k) if k >= 0 else _tray_rect(i)


func _on_canvas_input(ev: InputEvent) -> void:
	var g := game as AnagramGame
	if g.finished:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			for i in g.tiles.size():
				if _tile_rect(i).has_point(ev.position):
					if g.ice[i] > 0:  # 얼음은 두드려 깬다
						g.hit(i)
						_shake[i] = 0.2
						GameData.vibrate(g.ice[i] == 0)
					else:
						_drag = i
						_drag_pos = ev.position
						_press_pos = ev.position
					return
		elif _drag >= 0:
			var i := _drag
			_drag = -1
			var placed := false
			for k in g.slots.size():
				if _slot_rect(k).grow(10).has_point(ev.position):
					g.put(i, k)
					placed = true
					break
			if not placed and g.slot_of(i) >= 0:
				g.take(g.slot_of(i))  # 칸 밖에 놓으면 아래로 돌아간다
			_after()
	elif ev is InputEventMouseMotion and _drag >= 0:
		_drag_pos = ev.position


func _after() -> void:
	var g := game as AnagramGame
	match g.last:
		"right":
			_msg.text = t("ui.quiz.right")
		"wrong":
			_msg.text = t("ui.mini.copy.wrong")
			GameData.vibrate()
		"skip":
			_msg.text = t("ui.mini.copy.answer").format({"word": g.last_word})
	g.last = ""
	changed()


func refresh() -> void:
	var g := game as AnagramGame
	var w := g.current()
	if w == null:
		return
	var parts: Array[String] = []
	for e in w.etym:
		parts.append("%s(%s)" % [e.get("root", ""), e.get("meaning", "")])
	_hint.text = t("ui.mini.copy.hint").format({"meaning": w.meaning, "etym": " + ".join(parts)})
	_canvas.queue_redraw()


func tick(delta: float) -> void:
	for i in _shake.keys():
		_shake[i] -= delta
		if _shake[i] <= 0.0:
			_shake.erase(i)
	_canvas.queue_redraw()


func _draw_desk() -> void:
	var g := game as AnagramGame
	if g.current() == null:
		return
	var font := ThemeDB.fallback_font
	for k in g.slots.size():
		var r := _slot_rect(k)
		_canvas.draw_style_box(UiKit.box(Color("fbf3e0"), 12, 3), r)
		_canvas.draw_line(r.position + Vector2(10, r.size.y - 14), r.end - Vector2(10, 14), UiKit.INK.lightened(0.4), 2)
	_canvas.draw_string(font, Vector2(40, 210), t("ui.mini.copy.ice") if g.ice.any(func(x: int) -> bool: return x > 0) else t("ui.mini.copy.drag"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiKit.INK.lightened(0.2))
	var order: Array = range(g.tiles.size())
	if _drag >= 0:  # 끄는 글자를 맨 위에
		order.erase(_drag)
		order.append(_drag)
	for i in order:
		var r := _tile_rect(i)
		if _shake.has(i):
			r.position.x += sin(_shake[i] * 80.0) * 4.0
		_canvas.draw_style_box(UiKit.box(UiKit.APRICOT, 14, 3), r)
		_canvas.draw_string(font, r.position + Vector2(0, 62), g.tiles[i].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 44, UiKit.INK)
		if g.ice[i] > 0:  # 얼음: 두 번 남으면 두껍게, 한 번 남으면 금이 간다
			if not Art.draw(_canvas, "mini", "ice_%d" % g.ice[i], r.get_center(), r.size + Vector2(10, 10)):
				_canvas.draw_style_box(UiKit.box(Color(0.75, 0.9, 1.0, 0.8 if g.ice[i] >= 2 else 0.55), 14, 3), r.grow(4))
				_canvas.draw_line(r.position + Vector2(12, 14), r.position + Vector2(30, 30), Color.WHITE, 3)
				if g.ice[i] == 1:
					var c := r.get_center()
					for a in [0.3, 1.9, 3.6, 5.0]:
						_canvas.draw_line(c, c + Vector2(cos(a), sin(a)) * 40, Color(1, 1, 1, 0.9), 2)
