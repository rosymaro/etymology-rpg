class_name FishingView
extends MinigameScreen
## 5 낚시: 물고기를 하나 누르고 이웃한 물고기를 누르면 바꾼다. 게이지가 차면 단어 1개.

const CELL := 76.0
const FISH := ["a8d8ea", "f4a6a6", "ffd59e", "b5e5b5", "c9b6e4", "f2b5d4"]

var _canvas: Control
var _sel := Vector2i(-1, -1)
var _info: Label


func build() -> void:
	var g := game as Match3Game
	_canvas = Control.new()
	_canvas.position = Vector2(60, 10)
	_canvas.custom_minimum_size = Vector2(CELL * g.size, CELL * g.size)
	_canvas.size = _canvas.custom_minimum_size
	_canvas.draw.connect(_draw_board)
	_canvas.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_tap(Vector2i(int(ev.position.y / CELL), int(ev.position.x / CELL))))
	body.add_child(_canvas)
	_info = UiKit.label("", 26)
	_info.position = Vector2(CELL * g.size + 120, 30)
	_info.custom_minimum_size = Vector2(500, 0)
	body.add_child(_info)


func _tap(p: Vector2i) -> void:
	var g := game as Match3Game
	if p.x < 0 or p.y < 0 or p.x >= g.size or p.y >= g.size:
		return
	if _sel.x < 0:
		_sel = p
	elif _sel == p:
		_sel = Vector2i(-1, -1)
	else:
		if not g.swap(_sel, p):
			GameData.vibrate()
		_sel = Vector2i(-1, -1)
	changed()


func refresh() -> void:
	var g := game as Match3Game
	_info.text = t("ui.mini.fishing.info").format({"moves": g.moves_left, "gauge": g.gauge, "per": int(g.cfg["gauge_per_word"])})
	_canvas.queue_redraw()


func _draw_board() -> void:
	var g := game as Match3Game
	for r in g.size:
		for c in g.size:
			var ctr := Vector2(c * CELL + CELL / 2, r * CELL + CELL / 2)
			var k: int = g.board[r][c]
			if not Art.draw(_canvas, "mini", "fish_%d" % k, ctr, Vector2(CELL, CELL) * 0.9):
				_canvas.draw_circle(ctr, CELL * 0.4, Color(FISH[k % FISH.size()]))
				_canvas.draw_circle(ctr + Vector2(10, -6), 4, UiKit.INK)
			_canvas.draw_arc(ctr, CELL * 0.4, 0, TAU, 24, UiKit.INK if Vector2i(r, c) != _sel else UiKit.ACCENT, 3 if Vector2i(r, c) != _sel else 7)
