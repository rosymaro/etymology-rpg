class_name TrapView
extends MinigameScreen
## 2 덫 놓기: 덤불에 숨어 단어들의 움직임을 지켜본다. 아래 덫(뜻)을 끌어 땅에 놓으면 캐릭터가 나가고 단어들은 숨는다.
## '숨어서 기다리기'를 누르면 단어들이 다시 똑같이 움직이고, 뜻이 맞는 덫에 걸린다.

const TRAY_H := 86.0
const TRAP := Vector2(150, 44)

var _canvas: Control
var _msg: Label
var _hide_btn: Button
var _drag := -1  ## 끌고 있는 tray 칸
var _drag_pos := Vector2.ZERO
var _pops: Array[Dictionary] = []


func build() -> void:
	_canvas = Control.new()
	_canvas.anchor_right = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.offset_left = 16
	_canvas.offset_right = -16
	_canvas.offset_bottom = -10
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_ground)
	_canvas.gui_input.connect(_on_canvas_input)
	body.add_child(_canvas)
	_msg = UiKit.wrap(UiKit.label("", 22, UiKit.INK), 760)
	_msg.position = Vector2(30, 6)
	body.add_child(_msg)
	_hide_btn = UiKit.button(t("ui.mini.trap.hide"), _on_hide, UiKit.LEAF, 22)
	_hide_btn.custom_minimum_size = Vector2(240, 60)
	body.add_child(_hide_btn)
	UiKit.pin(_hide_btn, 1, 0, -30, 4)


func _field_h() -> float:
	return _canvas.size.y - TRAY_H


func _px(p: Vector2) -> Vector2:
	return p * Vector2(_canvas.size.x, _field_h())


func _norm(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x / _canvas.size.x, 0.03, 0.97), clampf(p.y / _field_h(), 0.05, 0.95))


func _tray_rect(k: int) -> Rect2:
	var g := game as TrapGame
	var n := maxi(1, g.tray.size())
	var w := minf(TRAP.x + 20, (_canvas.size.x - 40) / n)
	return Rect2(Vector2(20 + k * w, _field_h() + 20), Vector2(w - 12, TRAP.y + 4))


func _trap_rect(p: Vector2) -> Rect2:
	return Rect2(_px(p) - TRAP / 2, TRAP)


func _on_canvas_input(ev: InputEvent) -> void:
	var g := game as TrapGame
	if g.finished or g.phase == "hunt":
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			for k in g.tray.size():
				if _tray_rect(k).has_point(ev.position):
					_drag = k
					_drag_pos = ev.position
					return
			for i in range(g.traps.size() - 1, -1, -1):
				if _trap_rect(g.traps[i]["pos"]).has_point(ev.position):
					g.pick_trap(i)
					changed()
					return
			if ev.position.y < _field_h():
				g.move_hero(_norm(ev.position))
				changed()
		elif _drag >= 0:
			if ev.position.y < _field_h():
				g.place_trap(_drag, _norm(ev.position))
			_drag = -1
			changed()
	elif ev is InputEventMouseMotion and _drag >= 0:
		_drag_pos = ev.position
		if g.phase == "watch" and ev.position.y < _field_h():
			g.move_hero(_norm(ev.position))  # 덤불에서 나가면 단어들이 숨는다
			changed()


func _on_hide() -> void:
	if (game as TrapGame).hide():
		changed()


func refresh() -> void:
	var g := game as TrapGame
	_hide_btn.visible = g.phase == "place"
	_msg.text = t("ui.mini.trap." + g.phase)


func tick(delta: float) -> void:
	var g := game as TrapGame
	for e in g.events:
		var w := g.words[e["w"]]
		_pops.append({"text": "✓ %s = %s" % [w.id, w.meaning], "pos": e["pos"], "t": 2.0})
		GameData.vibrate(true)
	g.events.clear()
	for p_ in _pops:
		p_["t"] -= delta
	_pops = _pops.filter(func(p_: Dictionary) -> bool: return p_["t"] > 0.0)
	_canvas.queue_redraw()


func show_review() -> bool:
	return false


func _draw_word(c: Vector2, text: String, col: Color) -> void:
	var font := ThemeDB.fallback_font
	if not Art.draw(_canvas, "mini", "trap_critter", c, Vector2(130, 56)):
		_canvas.draw_circle(c + Vector2(-44, -10), 10, col.darkened(0.1))  # 귀
		_canvas.draw_circle(c + Vector2(44, -10), 10, col.darkened(0.1))
		_canvas.draw_style_box(UiKit.box(col, 22, 3), Rect2(c - Vector2(62, 22), Vector2(124, 44)))
	_canvas.draw_string(font, c + Vector2(-60, 8), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 20, UiKit.INK)


func _draw_trap(r: Rect2, meaning: String, used: bool) -> void:
	var font := ThemeDB.fallback_font
	if not Art.draw(_canvas, "mini", "trap_snare", r.get_center(), r.size + Vector2(20, 16)):
		_canvas.draw_style_box(UiKit.box(UiKit.GRAY.lightened(0.2) if used else Color("e7c9a0"), 10, 3), r)
		for i in 5:  # 덫 이빨
			var x := r.position.x + 12 + i * (r.size.x - 24) / 4.0
			_canvas.draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y - 7), UiKit.INK, 2)
	_canvas.draw_string(font, r.position + Vector2(4, 29), meaning, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 16, UiKit.INK)


func _draw_ground() -> void:
	var g := game as TrapGame
	var font := ThemeDB.fallback_font
	var S := _canvas.size
	var fh := _field_h()
	_canvas.draw_style_box(UiKit.box(Color("d9c49a"), 20, 3), Rect2(0, 0, S.x, fh))
	for i in 18:  # 풀 포기
		var p := Vector2(fmod(i * 197.0, S.x - 40) + 20, fmod(i * 131.0, fh - 40) + 20)
		_canvas.draw_line(p, p + Vector2(-5, -12), Color("8fae6a"), 3)
		_canvas.draw_line(p, p + Vector2(5, -12), Color("8fae6a"), 3)
	# 덤불(숨는 곳)
	var bush := _px(TrapGame.HIDE)
	for o in [Vector2(-40, 0), Vector2(0, -16), Vector2(40, 0)]:
		_canvas.draw_circle(bush + o, 34, Color("7fae6b"))
	# 덫
	for tr in g.traps:
		_draw_trap(_trap_rect(tr["pos"]), g.words[tr["w"]].meaning, tr["used"])
	# 단어들(덫 놓는 동안에는 숨는다)
	if g.visible():
		for i in g.paths.size():
			if g.caught[i]:
				continue
			_draw_word(_px(g.pos(i, g.t)), g.words[g.paths[i]["w"]].id, Color("f4e3b5"))
	for i in g.paths.size():
		if g.caught[i]:
			for tr in g.traps:
				if tr["used"] and g.words[tr["w"]].meaning == g.words[i].meaning:
					_draw_word(_px(tr["pos"]) + Vector2(0, -30), g.words[i].id, UiKit.GOOD.lightened(0.4))
					break
	# 내 캐릭터
	var h := _px(g.hero)
	var hidden := g.hero.distance_to(TrapGame.HIDE) < 0.02
	if not Art.draw(_canvas, "mini", "trap_hunter", h, Vector2(56, 56)):
		_canvas.draw_circle(h, 20, Color(UiKit.ACCENT, 0.45 if hidden else 1.0))
		_canvas.draw_circle(h + Vector2(-7, -4), 3, UiKit.INK)
		_canvas.draw_circle(h + Vector2(7, -4), 3, UiKit.INK)
	# 잡힘 말풍선
	for p_ in _pops:
		var c := _px(p_["pos"]) + Vector2(0, -78)
		var r := Rect2(c - Vector2(150, 20), Vector2(300, 36))
		_canvas.draw_style_box(UiKit.box(Color(UiKit.GOOD.lightened(0.55), clampf(p_["t"], 0, 1)), 14, 3), r)
		_canvas.draw_string(font, r.position + Vector2(6, 25), p_["text"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12, 18, UiKit.INK)
	# 덫 상자(아래)
	_canvas.draw_rect(Rect2(0, fh + 6, S.x, TRAY_H - 6), Color("efe4cf"))
	for k in g.tray.size():
		if k != _drag:
			_draw_trap(_tray_rect(k), g.words[g.tray[k]].meaning, false)
	if _drag >= 0 and _drag < g.tray.size():
		_draw_trap(Rect2(_drag_pos - TRAP / 2, TRAP), g.words[g.tray[_drag]].meaning, false)
	if g.phase == "hunt":
		var left := maxf(0.0, g.period() - g.t)
		_canvas.draw_string(font, Vector2(S.x - 330, fh - 14), t("ui.mini.trap.caught").format({"n": g.caught.count(true), "max": g.paths.size(), "s": int(ceil(left))}),
			HORIZONTAL_ALIGNMENT_RIGHT, 320, 20, UiKit.INK)
