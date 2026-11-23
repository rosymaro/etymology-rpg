class_name KiteView
extends MinigameScreen
## 4 연날리기: 바람길 타일을 눌러 돌린다. 오른쪽의 뜻 5개에 맞는 단어를 모두 지나고, 함정 단어는 피해서 하늘까지 잇는다.

const CELL := 96.0

var _canvas: Control
var _side: VBoxContainer
var _msg: Label


func build() -> void:
	var g := game as PipeGame
	_canvas = Control.new()
	_canvas.position = Vector2(20, 10)
	_canvas.custom_minimum_size = Vector2(CELL * g.cols + 200, CELL * g.rows)
	_canvas.size = _canvas.custom_minimum_size
	_canvas.draw.connect(_draw_board)
	_canvas.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var c := Vector2i(int(ev.position.y / CELL), int((ev.position.x - 100) / CELL))
			if ev.position.x >= 100 and c.x >= 0 and c.y >= 0 and c.x < g.rows and c.y < g.cols:
				g.turn(c)
				if g.last_judge == "trap" or g.last_judge == "missing":
					GameData.vibrate()
				changed())
	body.add_child(_canvas)
	_side = UiKit.vbox(8)
	_side.position = Vector2(CELL * g.cols + 240, 10)
	_side.custom_minimum_size = Vector2(360, 0)
	body.add_child(_side)
	_side.add_child(UiKit.wrap(UiKit.label(t("ui.mini.kite.goal"), 22), 360))
	for k in g.targets:
		_side.add_child(UiKit.wrap(UiKit.label("· " + g.words[k].meaning, 20), 360))
	_msg = UiKit.wrap(UiKit.label("", 22, UiKit.BAD.darkened(0.2)), 360)
	_side.add_child(_msg)


func refresh() -> void:
	var g := game as PipeGame
	_msg.text = "" if g.last_judge in ["", "ok"] else t("ui.mini.kite." + g.last_judge)
	_canvas.queue_redraw()


func _draw_board() -> void:
	var g := game as PipeGame
	var on := g.connected()
	var font := ThemeDB.fallback_font
	var off := Vector2(100, 0)
	for r in g.rows:
		for c in g.cols:
			var p := Vector2i(r, c)
			var o := off + Vector2(c * CELL, r * CELL)
			_canvas.draw_rect(Rect2(o + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), UiKit.SKY.lightened(0.3))
			var m: int = g.tiles[r][c]
			var ctr := o + Vector2(CELL, CELL) / 2
			var col := UiKit.ACCENT if p in on else UiKit.INK.lightened(0.4)
			for pair in [[PipeGame.N, Vector2(0, -1)], [PipeGame.E, Vector2(1, 0)], [PipeGame.S, Vector2(0, 1)], [PipeGame.W, Vector2(-1, 0)]]:
				if m & pair[0]:
					_canvas.draw_line(ctr, ctr + pair[1] * CELL / 2, col, 14)
			_canvas.draw_circle(ctr, 8, col)
			if g.word_at_cell.has(p):
				var w := g.words[g.word_at_cell[p]]
				# 정답과 함정은 같은 모양으로 그린다(뜻을 보고 가려야 한다)
				_canvas.draw_rect(Rect2(o + Vector2(6, 6), Vector2(CELL - 12, 26)), Color(UiKit.PAPER, 0.92))
				_canvas.draw_string(font, o + Vector2(8, 25), w.id, HORIZONTAL_ALIGNMENT_CENTER, CELL - 16, 16, UiKit.INK)
	_canvas.draw_circle(Vector2(50, g.start_row * CELL + CELL / 2), 30, UiKit.PINK)
	_canvas.draw_string(font, Vector2(14, g.start_row * CELL + CELL / 2 + 50), t("ui.mini.kite.kite"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiKit.INK)
	var sx := 100 + g.cols * CELL + 50
	_canvas.draw_circle(Vector2(sx, g.end_row * CELL + CELL / 2), 30, UiKit.LEAF)
	_canvas.draw_string(font, Vector2(sx - 30, g.end_row * CELL + CELL / 2 + 50), t("ui.mini.kite.sky"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiKit.INK)
