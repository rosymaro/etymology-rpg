class_name PatternView
extends MinigameScreen
## 10 문양 잇기(갈라진 말뿌리 되찾기): 돌아다니는 어원을 화살로 맞혀 쓰러뜨리고, 끌어서 단어 아래 뿌리 자리에 놓는다.
## 뿌리 선은 어원을 놓을 때 생긴다(어원 수를 미리 알 수 없다). 끌고 있는 어원이 단어 위에 오면 그 단어가 빛난다.
## 단어의 어원이 정확히 모두 자리 잡으면 새싹이 오른다. 시간이 다 되면 새싹이 안 오른 단어의 정답 어원을 보여 준다.

const CARD := Vector2(210, 66)
const ROOT := Vector2(164, 50)
const ROOT_DROP := 44.0  ## 카드 아래에서 뿌리 끝까지

var _canvas: Control
var _msg: Label
var _drag := -1
var _drag_pos := Vector2.ZERO
var _hover := -1  ## 끌고 있는 어원이 올라간 단어
var _review := false
var _seen_sprouts := 0


func build() -> void:
	_canvas = Control.new()
	_canvas.anchor_right = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.offset_left = 16
	_canvas.offset_right = -16
	_canvas.offset_bottom = -10
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_board)
	_canvas.gui_input.connect(_on_canvas_input)
	body.add_child(_canvas)
	_msg = UiKit.wrap(UiKit.label("", 22, UiKit.ACCENT.darkened(0.25)), 900)
	body.add_child(_msg)
	_msg.position = Vector2(28, 4)


func _px(p: Vector2) -> Vector2:
	return p * _canvas.size


func _norm(p: Vector2) -> Vector2:
	return p / _canvas.size


func _card_rect(k: int) -> Rect2:
	var g := game as RootLinkGame
	var c := _px(g.word_pos[k])
	c.x = clampf(c.x, CARD.x / 2 + 4, _canvas.size.x - CARD.x / 2 - 4)
	return Rect2(c - CARD / 2, CARD)


## 단어 칸 k의 뿌리 끝 s번 자리(화면 좌표). n = 지금 뿌리 수(-1이면 놓인 수)
func _slot_pos(k: int, s: int, n: int = -1) -> Vector2:
	var g := game as RootLinkGame
	if n < 0:
		n = g.placed_at(k).size()
	var r := _card_rect(k)
	var spread := 0.0 if n == 1 else (s - (n - 1) / 2.0) * (ROOT.x + 8.0)
	return Vector2(r.get_center().x + spread, r.end.y + ROOT_DROP)


func _root_pos(i: int) -> Vector2:
	var g := game as RootLinkGame
	var r: Dictionary = g.roots[i]
	if i == _drag:
		return _drag_pos
	if r["state"] == "placed":
		return _slot_pos(r["at"], r["slot"])
	return _px(r["pos"])


func _root_under(p: Vector2) -> int:
	var g := game as RootLinkGame
	for i in range(g.roots.size() - 1, -1, -1):
		if g.roots[i]["state"] in ["down", "placed"] and Rect2(_root_pos(i) - ROOT / 2, ROOT).grow(8).has_point(p):
			return i
	return -1


func _word_under(p: Vector2) -> int:
	var g := game as RootLinkGame
	for k in g.targets.size():
		var r := _card_rect(k)
		r = r.expand(Vector2(r.get_center().x, r.end.y + ROOT_DROP + ROOT.y / 2)).grow(20)
		if r.has_point(p):
			return k
	return -1


func _on_canvas_input(ev: InputEvent) -> void:
	var g := game as RootLinkGame
	if g.finished:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			var i := _root_under(ev.position)
			if i >= 0:
				_drag = i
				_drag_pos = ev.position
			else:
				g.shoot(_norm(ev.position))
		elif _drag >= 0:
			var i := _drag
			_drag = -1
			_hover = -1
			var k := _word_under(ev.position)
			var drop := _norm(ev.position)
			drop.y = minf(drop.y, RootLinkGame.ROAM_BOTTOM)
			if not g.place(i, k, drop):
				g.place(i, -1, drop)
			changed()
	elif ev is InputEventMouseMotion and _drag >= 0:
		_drag_pos = ev.position
		_hover = _word_under(ev.position)


func tick(_d: float) -> void:
	var g := game as RootLinkGame
	var n := g.sprouted.count(true)
	if n > _seen_sprouts:
		_seen_sprouts = n
		_msg.text = t("ui.mini.pattern.sprout").format({"n": n, "max": g.targets.size()})
		GameData.vibrate(true)
	_canvas.queue_redraw()


func show_review() -> bool:
	var g := game as RootLinkGame
	_drag = -1
	if g.complete():
		return false
	_review = true
	_msg.text = t("ui.mini.pattern.review")
	_canvas.queue_redraw()
	return true


func _draw_root_card(c: Vector2, root: String, meaning: String, bg: Color, alpha := 1.0) -> void:
	var font := ThemeDB.fallback_font
	var r := Rect2(c - ROOT / 2, ROOT)
	_canvas.draw_style_box(UiKit.box(Color(bg, alpha), 20, 3), r)
	_canvas.draw_string(font, r.position + Vector2(4, 22), root, HORIZONTAL_ALIGNMENT_CENTER, ROOT.x - 8, 18, Color(UiKit.INK, alpha))
	_canvas.draw_string(font, r.position + Vector2(4, 42), meaning, HORIZONTAL_ALIGNMENT_CENTER, ROOT.x - 8, 15, Color(UiKit.INK.lightened(0.2), alpha))


func _draw_board() -> void:
	var g := game as RootLinkGame
	var font := ThemeDB.fallback_font
	var S := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(S.x, S.y * (RootLinkGame.ROAM_BOTTOM + 0.04))), Color("e9e1f2"))
	_canvas.draw_rect(Rect2(0, S.y * (RootLinkGame.ROAM_BOTTOM + 0.04), S.x, S.y), Color("efe4cf"))
	# 단어, 뿌리 선, 새싹
	for k in g.targets.size():
		var w := g.words[g.targets[k]]
		var r := _card_rect(k)
		var root_col := Color("8a6a40")
		var a := Vector2(r.get_center().x, r.end.y)
		var n := g.slots(k) if _review and not g.sprouted[k] else g.placed_at(k).size()
		for s in n:  # 뿌리 선은 놓인 어원에만(정답 보기에서는 정답 수만큼)
			var e := _slot_pos(k, s, n)
			_canvas.draw_polyline([a, a.lerp(e, 0.5) + Vector2(0, 8), e - Vector2(0, ROOT.y / 2)], root_col, 4)
		if k == _hover and _drag >= 0:  # 끌고 있는 어원이 여기 놓일 자리 미리 보기
			var full: bool = g.placed_at(k).size() >= g.cap() and g.roots[_drag]["at"] != k
			var e2 := _slot_pos(k, 0, 1) if g.placed_at(k).is_empty() else _drag_pos
			_canvas.draw_dashed_line(a, e2, Color(UiKit.BAD if full else UiKit.ACCENT, 0.8), 3, 8)
		if g.sprouted[k]:
			var top := Vector2(r.get_center().x, r.position.y)
			if not Art.draw(_canvas, "mini", "sprout", top - Vector2(0, 26), Vector2(60, 60)):
				_canvas.draw_line(top, top - Vector2(0, 34), UiKit.GOOD.darkened(0.2), 4)
				_canvas.draw_circle(top + Vector2(-12, -34), 11, UiKit.GOOD)
				_canvas.draw_circle(top + Vector2(12, -38), 11, UiKit.GOOD)
		var bg := UiKit.GOOD.lightened(0.45) if g.sprouted[k] else (UiKit.PINK.lightened(0.3) if _review else UiKit.SKY)
		if k == _hover and _drag >= 0:  # 놓을 단어가 골라졌음을 보여 준다
			_canvas.draw_style_box(UiKit.box(Color(UiKit.ACCENT, 0.35), 26, 0), r.grow(10))
			bg = UiKit.ACCENT.lightened(0.55)
		_canvas.draw_style_box(UiKit.box(bg, 20, 5 if k == _hover and _drag >= 0 else 3), r)
		_canvas.draw_string(font, r.position + Vector2(4, 30), w.id, HORIZONTAL_ALIGNMENT_CENTER, CARD.x - 8, 26, UiKit.INK)
		_canvas.draw_string(font, r.position + Vector2(4, 56), w.meaning, HORIZONTAL_ALIGNMENT_CENTER, CARD.x - 8, 16, UiKit.INK.lightened(0.2))
		if _review and not g.sprouted[k]:  # 정답 어원을 뿌리 끝에 보여 준다
			for s in w.etym.size():
				var e2 := _slot_pos(k, s, w.etym.size())
				_draw_root_card(e2, "✔ " + String(w.etym[s].get("root", "")), String(w.etym[s].get("meaning", "")), UiKit.PINK.lightened(0.2))
	# 어원
	for i in g.roots.size():
		var ro: Dictionary = g.roots[i]
		var c := _root_pos(i)
		if ro["state"] == "roam":
			if not Art.draw(_canvas, "mini", "root_wisp", c, ROOT + Vector2(30, 20)):
				_draw_root_card(c, ro["root"], ro["meaning"], UiKit.APRICOT.lightened(0.3))
			else:
				_canvas.draw_string(font, c + Vector2(-ROOT.x / 2, 0), ro["root"], HORIZONTAL_ALIGNMENT_CENTER, ROOT.x, 20, UiKit.INK)
		elif ro["state"] == "down":
			_draw_root_card(c, "💫 " + String(ro["root"]), ro["meaning"], Color("d8d2c8"), 0.95)
		else:
			if _review and not g.sprouted[ro["at"]]:
				continue  # 정답 어원이 그 자리에 대신 나온다
			var bad: bool = _review and ro["owner"] != g.targets[ro["at"]]
			_draw_root_card(c, ro["root"], ro["meaning"], UiKit.BAD.lightened(0.4) if bad else Color("f6e7c8"))
	# 활과 화살
	var bow := _px(RootLinkGame.BOW)
	_canvas.draw_arc(bow, 34, PI / 2, PI * 1.5, 16, Color("6b4a2f"), 5)
	_canvas.draw_line(bow + Vector2(0, -34), bow + Vector2(0, 34), UiKit.INK, 1)
	for a in g.arrows:
		var p := _px(a["pos"])
		var d := (_px(a["to"]) - _px(RootLinkGame.BOW)).normalized()
		_canvas.draw_line(p - d * 30, p, UiKit.INK, 3)
		_canvas.draw_colored_polygon([p + d * 10, p + d.orthogonal() * 6, p - d.orthogonal() * 6], UiKit.INK)
	if _review:
		return
	_canvas.draw_string(font, Vector2(S.x - 330, S.y - 8), t("ui.mini.pattern.left").format({"n": g.sprouted.count(true), "max": g.targets.size()}),
		HORIZONTAL_ALIGNMENT_RIGHT, 320, 20, UiKit.INK)
