class_name SearchView
extends MinigameScreen
## 3 책 읽기: 글자 격자에서 처음 글자부터 끝 글자까지 끌어서 고른다. 오른쪽은 뜻 힌트.

const CELL := 56.0
const ORIGIN := Vector2(40, 10)

var _canvas: Control
var _hints: VBoxContainer
var _drag_from := Vector2i(-1, -1)
var _drag_to := Vector2i(-1, -1)
var _fade: Dictionary = {}  ## 지워지는 중인 칸 -> 남은 투명도(1 → 0)
var _review := false
var _etym_on := false
const FADE_SEC := 1.2


func build() -> void:
	var g := game as WordSearchGame
	_canvas = Control.new()
	_canvas.position = ORIGIN
	_canvas.custom_minimum_size = Vector2(CELL * g.size, CELL * g.size)
	_canvas.size = _canvas.custom_minimum_size
	_canvas.draw.connect(_draw_grid)
	_canvas.gui_input.connect(_input_grid)
	body.add_child(_canvas)
	_hints = UiKit.vbox(8)
	_hints.position = Vector2(ORIGIN.x + CELL * g.size + 40, 10)
	_hints.custom_minimum_size = Vector2(560, 0)
	body.add_child(_hints)


func refresh() -> void:
	var g := game as WordSearchGame
	for c in _hints.get_children():
		c.queue_free()
	_hints.add_child(UiKit.wrap(UiKit.label(t("ui.mini.search.hints"), 22), 560))
	for id in g.hidden_ids():
		var w := word(g._original(id))
		var done := id in g.found
		var text := ("✓ %s  %s" % [w.id, w.meaning]) if done else ("· %s (%d)" % [w.meaning, id.length()])
		if not done and _etym_on and not w.etym.is_empty():  # 1분이 지나면 어원도 힌트로(사용자 의견)
			text += "  " + t("ui.mini.search.etym").format({"etym": _etym(w)})
		var col := UiKit.GOOD.darkened(0.3) if done else UiKit.INK
		if _review and not done:
			text = t("ui.mini.search.answer").format({"word": w.id, "meaning": w.meaning})
			col = UiKit.BAD.darkened(0.2)
		_hints.add_child(UiKit.wrap(UiKit.label(text, 22, col), 560))
	_canvas.queue_redraw()


func tick(delta: float) -> void:
	var g := game as WordSearchGame
	if not _etym_on and float(g.cfg["duration"]) - g.time_left >= float(g.cfg.get("etym_hint_after", 60)):
		_etym_on = true
		refresh()
	for p in g.removed:
		if not _fade.has(p):
			_fade[p] = 1.0
	var moving := false
	for p in _fade:
		if _fade[p] > 0.0:
			_fade[p] = maxf(0.0, _fade[p] - delta / FADE_SEC)
			moving = true
	if moving:
		_canvas.queue_redraw()


## 못 찾은 단어를 판에 표시하고 '다음'을 기다린다.
func show_review() -> bool:
	var g := game as WordSearchGame
	_review = g.found.size() < g.placed.size()
	if _review:
		refresh()
	return _review


func _cell_at(pos: Vector2) -> Vector2i:
	var g := game as WordSearchGame
	var c := Vector2i(int(pos.y / CELL), int(pos.x / CELL))
	return c if c.x >= 0 and c.y >= 0 and c.x < g.size and c.y < g.size else Vector2i(-1, -1)


func _input_grid(ev: InputEvent) -> void:
	if _review:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_drag_from = _cell_at(ev.position)
			_drag_to = _drag_from
		else:
			if _drag_from.x >= 0 and _drag_to.x >= 0:
				var g := game as WordSearchGame
				if g.select(_drag_from, _drag_to) == "":
					GameData.vibrate()
			_drag_from = Vector2i(-1, -1)
			changed()
	elif ev is InputEventMouseMotion and _drag_from.x >= 0:
		var c := _cell_at(ev.position)
		if c.x >= 0:
			_drag_to = c
			_canvas.queue_redraw()


func _draw_grid() -> void:
	var g := game as WordSearchGame
	var font := ThemeDB.fallback_font
	for p in g.placed:
		var a: Vector2i = p["start"]
		var b: Vector2i = a + p["dir"] * (p["len"] - 1)
		if p["id"] in g.found:
			_canvas.draw_line(_center(a), _center(b), Color(UiKit.LEAF, 0.9), CELL * 0.7)
		elif _review:
			_canvas.draw_line(_center(a), _center(b), Color(UiKit.PINK, 0.95), CELL * 0.7)
	if _drag_from.x >= 0:
		_canvas.draw_line(_center(_drag_from), _center(_drag_to), Color(UiKit.ACCENT, 0.5), CELL * 0.7)
	for r in g.size:
		for c in g.size:
			var p := Vector2i(r, c)
			var alpha: float = _fade.get(p, 1.0)
			if alpha <= 0.0:
				continue
			_canvas.draw_string(font, Vector2(c * CELL + 16, r * CELL + 40), g.grid[r][c].to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(UiKit.INK, alpha))


func _center(p: Vector2i) -> Vector2:
	return Vector2(p.y * CELL + CELL / 2, p.x * CELL + CELL / 2)


static func _etym(w: WordData) -> String:
	var parts: Array[String] = []
	for e in w.etym:
		parts.append("%s(%s)" % [e.get("root", ""), e.get("meaning", "")])
	return " + ".join(parts)
