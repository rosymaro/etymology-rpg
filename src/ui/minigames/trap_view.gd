class_name TrapView
extends MinigameScreen
## 2 덫 놓기: 칸을 눌러 살피거나(숫자) 덫을 놓는다. 위의 버튼으로 바꾼다.

const CELL := 74

var _trap_mode := false
var _mode_btn: Button
var _cells: Dictionary = {}


func build() -> void:
	var g := game as TrapGame
	var grid := GridContainer.new()
	grid.columns = g.cols
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.position = Vector2(40, 10)
	body.add_child(grid)
	for r in g.rows:
		for c in g.cols:
			var p := Vector2i(r, c)
			var b := UiKit.button("", func() -> void: _press(p), UiKit.LEAF, 24)
			b.custom_minimum_size = Vector2(CELL, CELL)
			grid.add_child(b)
			_cells[p] = b
	_mode_btn = UiKit.button("", func() -> void:
		_trap_mode = not _trap_mode
		refresh(), UiKit.APRICOT, 24)
	_mode_btn.custom_minimum_size = Vector2(300, 90)
	body.add_child(_mode_btn)
	UiKit.pin(_mode_btn, 1, 0, -40, 20)


func _press(p: Vector2i) -> void:
	var g := game as TrapGame
	if _trap_mode:
		g.trap(p)
	else:
		g.reveal(p)
	changed()


func refresh() -> void:
	var g := game as TrapGame
	_mode_btn.text = t("ui.mini.trap.mode_trap") if _trap_mode else t("ui.mini.trap.mode_look")
	for p in _cells:
		var b: Button = _cells[p]
		if g.trapped.has(p):
			b.text = t("ui.mini.trap.caught") if g.hidden.has(p) else "✕"
			b.add_theme_stylebox_override("normal", UiKit.box(UiKit.ACCENT.lightened(0.4) if g.hidden.has(p) else UiKit.BAD.lightened(0.3), 30))
		elif g.revealed.has(p):
			var n := g.number(p)
			b.text = "" if n == 0 else str(n)
			b.add_theme_stylebox_override("normal", UiKit.box(UiKit.PAPER, 30))
		elif g.finished and g.hidden.has(p):
			b.text = "?"
			b.add_theme_stylebox_override("normal", UiKit.box(UiKit.PINK, 30))
