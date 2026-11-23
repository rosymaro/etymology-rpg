class_name PatternView
extends MinigameScreen
## 10 문양 잇기(갈라진 말뿌리 잇기): 왼쪽 단어를 누르고 오른쪽의 어원 풀이를 누르면 선으로 잇는다.

const ROW := 92.0
const LEFT_X := 40.0
const RIGHT_X := 560.0
const LEFT_W := 280.0
const RIGHT_W := 620.0

var _canvas: Control
var _sel := -1
var _wrong := Vector2i(-1, -1)
var _wrong_t := 0.0
var _msg: Label


func build() -> void:
	_canvas = Control.new()
	_canvas.position = Vector2(0, 10)
	_canvas.custom_minimum_size = Vector2(1240, ROW * 5 + 20)
	_canvas.draw.connect(_draw_links)
	_canvas.gui_input.connect(_input)
	body.add_child(_canvas)
	_msg = UiKit.label("", 22, UiKit.BAD.darkened(0.2))
	_msg.position = Vector2(40, ROW * 5 + 40)
	body.add_child(_msg)


func _left_rect(i: int) -> Rect2:
	return Rect2(Vector2(LEFT_X, i * ROW), Vector2(LEFT_W, ROW - 16))


func _right_rect(i: int) -> Rect2:
	return Rect2(Vector2(RIGHT_X, i * ROW), Vector2(RIGHT_W, ROW - 16))


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var g := game as RootLinkGame
	for i in g.left.size():
		if _left_rect(i).has_point(ev.position) and not g.linked.has(i):
			_sel = i
			_canvas.queue_redraw()
			return
	if _sel < 0:
		return
	for j in g.right.size():
		if _right_rect(j).has_point(ev.position):
			if not g.link(_sel, j):
				_wrong = Vector2i(_sel, j)
				_wrong_t = 0.8
				_msg.text = t("ui.mini.pattern.wrong")
				GameData.vibrate()
			else:
				_msg.text = ""
			_sel = -1
			changed()
			return


func tick(delta: float) -> void:
	if _wrong_t > 0.0:
		_wrong_t -= delta
		if _wrong_t <= 0.0:
			_wrong = Vector2i(-1, -1)
		_canvas.queue_redraw()


func refresh() -> void:
	_canvas.queue_redraw()


func _draw_links() -> void:
	var g := game as RootLinkGame
	var font := ThemeDB.fallback_font
	for a in g.linked:
		_canvas.draw_line(_left_rect(a).get_center() + Vector2(LEFT_W / 2, 0), _right_rect(g.linked[a]).get_center() - Vector2(RIGHT_W / 2, 0), UiKit.GOOD, 6)
	if _wrong.x >= 0:
		_canvas.draw_line(_left_rect(_wrong.x).get_center() + Vector2(LEFT_W / 2, 0), _right_rect(_wrong.y).get_center() - Vector2(RIGHT_W / 2, 0), UiKit.BAD, 6)
	for i in g.left.size():
		var bg := UiKit.GOOD.lightened(0.45) if g.linked.has(i) else (UiKit.ACCENT.lightened(0.45) if i == _sel else UiKit.SKY)
		_canvas.draw_style_box(UiKit.box(bg, 24), _left_rect(i))
		_canvas.draw_string(font, _left_rect(i).position + Vector2(0, 48), g.words[g.left[i]].id, HORIZONTAL_ALIGNMENT_CENTER, LEFT_W, 28, UiKit.INK)
	for j in g.right.size():
		var done := j in g.linked.values()
		_canvas.draw_style_box(UiKit.box(UiKit.GOOD.lightened(0.45) if done else UiKit.APRICOT.lightened(0.3), 24), _right_rect(j))
		_canvas.draw_string(font, _right_rect(j).position + Vector2(14, 46), RootLinkGame.etym_text(g.words[g.right[j]]), HORIZONTAL_ALIGNMENT_LEFT, RIGHT_W - 28, 20, UiKit.INK)
