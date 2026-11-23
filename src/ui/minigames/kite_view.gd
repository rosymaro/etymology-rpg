class_name KiteView
extends MinigameScreen
## 4 연날리기: 바람길 타일을 눌러 돌린다. 단어 칸은 돌릴 때마다 뜻이 바뀐다. 단어와 뜻이 맞는 방향이 바른 길이다.

const CELL := 84.0

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
				if g.last_judge == "meaning" or g.last_judge == "missing":
					GameData.vibrate()
				changed())
	body.add_child(_canvas)
	_side = UiKit.vbox(8)
	_side.position = Vector2(CELL * g.cols + 240, 10)
	_side.custom_minimum_size = Vector2(360, 0)
	body.add_child(_side)
	_side.add_child(UiKit.wrap(UiKit.label(t("ui.mini.kite.goal"), 22), 360))
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
			if g.arrows.has(p) and g.is_straight(p):  # 일자 타일의 방향 >>>
				var d := {PipeGame.N: Vector2(0, -1), PipeGame.E: Vector2(1, 0), PipeGame.S: Vector2(0, 1), PipeGame.W: Vector2(-1, 0)}[g.arrows[p]] as Vector2
				for k in [-1, 0, 1]:
					var tip: Vector2 = ctr + d * (k * 16 + 8)
					_canvas.draw_polyline([tip - d * 9 + d.orthogonal() * 9, tip, tip - d * 9 - d.orthogonal() * 9], Color.WHITE, 4)
			if g.word_at_cell.has(p):
				var w := g.words[g.word_at_cell[p]]
				# 단어와 지금 방향의 뜻. 뜻이 맞는지는 색으로 알려 주지 않는다(스스로 가린다)
				_canvas.draw_rect(Rect2(o + Vector2(4, 4), Vector2(CELL - 8, 24)), Color(UiKit.PAPER, 0.95))
				_canvas.draw_string(font, o + Vector2(6, 22), w.id, HORIZONTAL_ALIGNMENT_CENTER, CELL - 12, 15 if w.id.length() <= 8 else 12, UiKit.INK)
				_canvas.draw_rect(Rect2(o + Vector2(4, CELL - 28), Vector2(CELL - 8, 24)), Color(UiKit.APRICOT, 0.95))
				_canvas.draw_string(font, o + Vector2(6, CELL - 10), g.shown_meaning(p), HORIZONTAL_ALIGNMENT_CENTER, CELL - 12, 13, UiKit.INK)
	_canvas.draw_circle(Vector2(50, g.start_row * CELL + CELL / 2), 30, UiKit.PINK)
	_canvas.draw_string(font, Vector2(14, g.start_row * CELL + CELL / 2 + 50), t("ui.mini.kite.kite"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiKit.INK)
	var sx := 100 + g.cols * CELL + 50
	_canvas.draw_circle(Vector2(sx, g.end_row * CELL + CELL / 2), 30, UiKit.LEAF)
	_canvas.draw_string(font, Vector2(sx - 30, g.end_row * CELL + CELL / 2 + 50), t("ui.mini.kite.sky"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiKit.INK)
