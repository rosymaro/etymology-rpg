class_name MoatView
extends MinigameScreen
## 7 물레방아(해자 지키기): 위에서 단어 병사가 내려온다. 아래 물레방아 셋의 수문을 눌러 열고 닫는다.
## 하나만 열면 그 활이 빠르게, 여럿 열면 나눠서 쏜다. 100마리를 잡으면 단어를 모두 얻는다.

var _canvas: Control


func build() -> void:
	_canvas = Control.new()
	_canvas.anchor_right = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.offset_left = 16
	_canvas.offset_right = -16
	_canvas.offset_bottom = -10
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_moat)
	_canvas.gui_input.connect(_input)
	body.add_child(_canvas)


func _px(p: Vector2) -> Vector2:
	return p * _canvas.size


func _gate_rect(i: int) -> Rect2:
	return Rect2(_px((game as MoatGame).wheel_pos(i)) - Vector2(90, 70), Vector2(180, 150))


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var g := game as MoatGame
		for i in 3:
			if _gate_rect(i).has_point(ev.position):
				g.toggle(i)
				return


func tick(_d: float) -> void:
	_canvas.queue_redraw()


func _draw_moat() -> void:
	var g := game as MoatGame
	var font := ThemeDB.fallback_font
	var S := _canvas.size
	_canvas.draw_style_box(UiKit.box(Color("cfe6b0"), 20, 3), Rect2(Vector2.ZERO, S))
	# 성벽과 해자(아래)
	var wy := _px(Vector2(0, MoatGame.WHEEL_Y + 0.08)).y
	_canvas.draw_rect(Rect2(0, wy, S.x, S.y - wy), Color("c9bba4"))
	_canvas.draw_rect(Rect2(0, wy - 18, S.x, 18), Color("8fcbe3"))
	# 물길: 위쪽 물줄기에서 물레방아로
	for i in 3:
		var w := _px(g.wheel_pos(i))
		var col := Color("5fa8d3") if g.gates[i] else Color(0.6, 0.6, 0.6, 0.5)
		_canvas.draw_line(Vector2(w.x, S.y), w + Vector2(0, 46), col, 14 if g.gates[i] else 6)
	# 사정거리
	for i in 3:
		var w2 := _px(g.wheel_pos(i))
		# 거리는 0~1 비율로 재므로 화면에서는 타원이다
		var pts := PackedVector2Array()
		for k in 41:
			var a := PI + PI * k / 40.0
			pts.append(w2 + Vector2(cos(a), sin(a)) * float(g.cfg["range"]) * S)
		_canvas.draw_polyline(pts, Color(UiKit.INK, 0.22 if g.gates[i] else 0.07), 2)
	# 적(단어 병사)
	for e in g.enemies:
		var p := _px(e["pos"])
		var w3 := g.words[e["w"]]
		var r := Rect2(p - Vector2(70, 22), Vector2(140, 44))
		if not Art.draw(_canvas, "mini", "moat_soldier", p, Vector2(150, 60)):
			_canvas.draw_style_box(UiKit.box(UiKit.PINK if e["max"] < 2 else UiKit.BAD.lightened(0.35), 14, 3), r)
		_canvas.draw_string(font, r.position + Vector2(4, 20), w3.id, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 18, UiKit.INK)
		_canvas.draw_string(font, r.position + Vector2(4, 38), w3.meaning, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 13, UiKit.INK.lightened(0.2))
		if e["max"] >= 2:
			_canvas.draw_rect(Rect2(r.position + Vector2(10, -6), Vector2((r.size.x - 20) * e["hp"] / e["max"], 4)), UiKit.BAD)
	# 화살
	for a in g.arrows:
		var p2 := _px(a["pos"])
		var d := (a["vel"] as Vector2).normalized()
		_canvas.draw_line(p2 - d * 22, p2, UiKit.INK, 3)
	# 물레방아와 수문
	for i in 3:
		var c := _px(g.wheel_pos(i))
		var open: bool = g.gates[i]
		if not Art.draw(_canvas, "mini", "waterwheel", c, Vector2(110, 110)):
			_canvas.draw_circle(c, 46, Color("b08960"))
			for k in 8:
				var a2: float = g.spin[i] + TAU * k / 8.0
				_canvas.draw_line(c, c + Vector2(cos(a2), sin(a2)) * 50, Color("6b4a2f"), 5)
			_canvas.draw_circle(c, 12, Color("6b4a2f"))
		_canvas.draw_line(c + Vector2(-26, -50), c + Vector2(26, -50), UiKit.INK, 4)  # 활
		var gate := Rect2(c + Vector2(-70, 54), Vector2(140, 34))
		_canvas.draw_style_box(UiKit.box(UiKit.LEAF if open else UiKit.GRAY, 12, 3), gate)
		var label := t("ui.mini.moat.open") if open else t("ui.mini.moat.closed")
		if open:
			label += " ×%.1f" % (g.fire_rate(i) / (float(g.cfg["total_fire"]) / 3.0))
		_canvas.draw_string(font, gate.position + Vector2(0, 24), label, HORIZONTAL_ALIGNMENT_CENTER, gate.size.x, 18, UiKit.INK)
	_canvas.draw_style_box(UiKit.box(Color(UiKit.PAPER, 0.92), 14, 2), Rect2(10, 6, 420, 40))
	_canvas.draw_string(font, Vector2(22, 34), t("ui.mini.moat.kills").format({"n": g.kills, "goal": int(g.cfg["goal"]), "leak": g.leaks}),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiKit.INK)
