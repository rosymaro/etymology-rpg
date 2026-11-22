class_name PatternView
extends MinigameScreen
## 10 문양 잇기: 같은 문양 조각에서 끌어 다른 조각까지 선을 잇는다. 모든 칸을 채우면 끝. '그만하기'면 이은 선만큼.

const CELL := 100.0
const COLORS := ["f4a6a6", "a8d8ea", "b5e5b5", "ffd59e", "c9b6e4", "f2b5d4", "aec6f0"]

var _canvas: Control
var _drawing := false


func build() -> void:
	var g := game as FlowGame
	_canvas = Control.new()
	_canvas.position = Vector2(60, 10)
	_canvas.custom_minimum_size = Vector2(CELL * g.size, CELL * g.size)
	_canvas.size = _canvas.custom_minimum_size
	_canvas.draw.connect(_draw_board)
	_canvas.gui_input.connect(_input)
	body.add_child(_canvas)
	var side := UiKit.vbox(10)
	side.position = Vector2(CELL * g.size + 120, 10)
	side.custom_minimum_size = Vector2(500, 0)
	body.add_child(side)
	for k in g.pairs:
		side.add_child(UiKit.label("●  " + g.words[k].id, 22, Color(COLORS[k % COLORS.size()]).darkened(0.35)))
	side.add_child(UiKit.button(t("ui.mini.pattern.stop"), func() -> void:
		g.give_up()
		changed(), UiKit.PINK, 22))


func _cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.y / CELL), int(pos.x / CELL))


func _input(ev: InputEvent) -> void:
	var g := game as FlowGame
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_drawing = g.begin(_cell(ev.position))
		elif _drawing:
			_drawing = false
			g.end_stroke()
		changed()
	elif ev is InputEventMouseMotion and _drawing:
		var c := _cell(ev.position)
		var path: Array = g.paths[g._active] if g._active >= 0 else []
		if not path.is_empty() and c != path[-1]:
			g.extend(c)
			_canvas.queue_redraw()


func refresh() -> void:
	_canvas.queue_redraw()


func _draw_board() -> void:
	var g := game as FlowGame
	var font := ThemeDB.fallback_font
	for r in g.size:
		for c in g.size:
			_canvas.draw_rect(Rect2(Vector2(c * CELL + 2, r * CELL + 2), Vector2(CELL - 4, CELL - 4)), UiKit.PAPER.darkened(0.04))
	for k in g.pairs:
		var col := Color(COLORS[k % COLORS.size()])
		var path: Array = g.paths[k]
		for i in range(1, path.size()):
			_canvas.draw_line(_ctr(path[i - 1]), _ctr(path[i]), col, 26)
		for e in g.ends[k]:
			_canvas.draw_circle(_ctr(e), 32, col)
			_canvas.draw_arc(_ctr(e), 32, 0, TAU, 24, UiKit.INK, 3)
			_canvas.draw_string(font, _ctr(e) + Vector2(-8, 9), str(k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiKit.INK)


func _ctr(p: Vector2i) -> Vector2:
	return Vector2(p.y * CELL + CELL / 2, p.x * CELL + CELL / 2)
