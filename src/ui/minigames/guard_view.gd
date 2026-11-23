class_name GuardView
extends MinigameScreen
## 8 보초 서기: 성문 바깥에서 성문을 바라본다. 성벽 앞의 내 유닛을 손가락으로 좌우로 옮긴다.
## 뜻이 맞는 손님은 비켜서 통과시키고, 뜻이 틀린 손님과 담 넘는 단어는 막아선다.

const WALL_TOP := 30.0
const WALL_H := 190.0
const LINE_GAP := 40.0  ## 성벽 아래에서 막는 선까지

var _canvas: Control
var _flash := 0.0
var _pops: Array[Dictionary] = []  ## 보초 위 말풍선 {text, ok, x, y, t, max}
var _marks: Array[Dictionary] = []  ## 판정 자리의 큰 ○/✕ {ok, x, t}


func build() -> void:
	_canvas = Control.new()
	_canvas.anchor_right = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.offset_left = 16
	_canvas.offset_right = -16
	_canvas.offset_bottom = -50
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_field)
	_canvas.gui_input.connect(_on_canvas_input)
	body.add_child(_canvas)


func _on_canvas_input(ev: InputEvent) -> void:
	var press: bool = ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT
	var drag: bool = ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if press or drag:
		(game as GuardGame).move_to(ev.position.x / maxf(1.0, _canvas.size.x))


func _line_y() -> float:
	return WALL_TOP + WALL_H + LINE_GAP


## 0(들판 아래쪽) → 1(막는 선)
func _walk_y(t_: float) -> float:
	return lerpf(_canvas.size.y - 30, _line_y(), t_)


func tick(delta: float) -> void:
	var g := game as GuardGame
	var ly := _line_y()
	for e in g.events:
		var w := g.words[e["w"]]
		var x: float = clampf(g.unit_x * _canvas.size.x, 170, _canvas.size.x - 170)
		var text := ""
		if e["kind"] == "climb":
			text = t("ui.mini.guard.climb_ok" if e["ok"] else "ui.mini.guard.climb_miss").format({"word": e["name"]})
			if not e["ok"]:
				x = clampf(float(e["x"]) * _canvas.size.x, 170, _canvas.size.x - 170)
		elif e["ok"]:
			text = t("ui.mini.guard.ok").format({"word": w.id, "meaning": w.meaning})
		elif e["true"]:  # 맞는 짝을 막았다
			text = t("ui.mini.guard.wrong_blocked").format({"word": w.id, "meaning": w.meaning})
		else:  # 틀린 짝을 통과시켰다
			text = t("ui.mini.guard.wrong_passed").format({"word": w.id, "shown": e["shown"], "meaning": w.meaning})
		# 보초(내 유닛) 위에 말풍선으로 띄운다. 틀린 것은 더 오래 보여 준다
		text = text.replace("\\n", "\n")
		_pops.append({"text": text, "ok": e["ok"], "x": x, "y": ly - 64, "t": 1.4 if e["ok"] else 3.0, "max": 1.4 if e["ok"] else 3.0})
		_marks.append({"ok": e["ok"], "x": float(e["x"]) * _canvas.size.x, "t": 0.9})
		if not e["ok"]:
			_flash = 0.5
			GameData.vibrate()
	g.events.clear()
	_flash = maxf(0.0, _flash - delta)
	for p_ in _pops:
		p_["t"] -= delta
	_pops = _pops.filter(func(p_: Dictionary) -> bool: return p_["t"] > 0.0)
	if _pops.size() > 2:
		_pops = _pops.slice(_pops.size() - 2)
	for m in _marks:
		m["t"] -= delta
	_marks = _marks.filter(func(m: Dictionary) -> bool: return m["t"] > 0.0)
	_canvas.queue_redraw()


func _draw_field() -> void:
	var g := game as GuardGame
	var W := _canvas.size.x
	var font := ThemeDB.fallback_font
	# 하늘, 들판
	_canvas.draw_rect(Rect2(0, 0, W, WALL_TOP + WALL_H), Color("cfe8f5"))
	_canvas.draw_rect(Rect2(0, WALL_TOP + WALL_H, W, _canvas.size.y - WALL_TOP - WALL_H), Color("cfe6b0"))
	# 성벽과 성문(바깥에서 본 모습)
	var gate_w := float(g.cfg["gate_w"]) * W
	var gx := g.gate_x * W
	if not Art.draw(_canvas, "mini", "guard_wall", Vector2(W / 2, WALL_TOP + WALL_H / 2), Vector2(W, WALL_H)):
		_canvas.draw_rect(Rect2(0, WALL_TOP + 20, W, WALL_H - 20), Color("c9bba4"))
		for i in int(W / 60) + 1:
			_canvas.draw_rect(Rect2(i * 60, WALL_TOP, 36, 24), Color("c9bba4"))
		for r in 4:
			_canvas.draw_line(Vector2(0, WALL_TOP + 60 + r * 40), Vector2(W, WALL_TOP + 60 + r * 40), Color("a8987f"), 2)
		var gate := Rect2(gx - gate_w / 2, WALL_TOP + 60, gate_w, WALL_H - 60)
		_canvas.draw_rect(gate, Color("6b4a2f"))
		_canvas.draw_circle(Vector2(gx, gate.position.y), gate_w / 2, Color("6b4a2f"))
	_canvas.draw_string(font, Vector2(gx - 60, WALL_TOP + 110), t("ui.mini.guard.gate"), HORIZONTAL_ALIGNMENT_CENTER, 120, 20, Color.WHITE)
	# 손님과 담 넘는 단어
	for w in g.walkers:
		var word := g.words[w["w"]]
		var x: float = w["x"] * W
		if w["kind"] == "gate":
			var p := Vector2(x, _walk_y(w["y"]))
			var r := Rect2(p - Vector2(110, 50), Vector2(220, 74))
			if not Art.draw(_canvas, "mini", "guard_traveler", p, Vector2(240, 110)):
				_canvas.draw_style_box(UiKit.box(Color("fff8e8"), 14, 3), r)
			_canvas.draw_string(font, r.position + Vector2(6, 30), word.id, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12, 26, UiKit.INK)
			_canvas.draw_string(font, r.position + Vector2(6, 60), w["shown"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12, 18, UiKit.INK.lightened(0.2))
		else:
			# 담 아래까지 와서 벽을 오른다: 앞 절반은 들판, 뒤 절반은 사다리
			var y: float = _walk_y(minf(1.0, w["y"]))
			var p := Vector2(x, y)
			_canvas.draw_line(Vector2(x + 50, WALL_TOP + 30), Vector2(x + 50, _line_y() + 10), Color("8a6a40"), 4)
			var r := Rect2(p - Vector2(80, 26), Vector2(160, 48))
			if not Art.draw(_canvas, "mini", "guard_climber", p, Vector2(180, 70)):
				_canvas.draw_style_box(UiKit.box(Color("f4a6a6"), 14, 3), r)
			var cw := GameData.repo.get_word(w["name"]) if GameData.repo else null
			_canvas.draw_string(font, r.position + Vector2(4, 22), "⚠ " + String(w["name"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 20, UiKit.INK)
			if cw:
				_canvas.draw_string(font, r.position + Vector2(4, 40), cw.meaning, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 14, UiKit.INK.lightened(0.15))
	# 막는 선과 내 유닛
	var ly := _line_y()
	_canvas.draw_dashed_line(Vector2(0, ly), Vector2(W, ly), Color(1, 1, 1, 0.7), 3, 12)
	var uw := float(g.cfg["unit_w"]) * W
	var ux := g.unit_x * W
	var shield := Rect2(ux - uw / 2, ly - 30, uw, 60)
	var col := Color("f08080") if _flash > 0.0 else UiKit.ACCENT
	if not Art.draw(_canvas, "mini", "guard_unit", Vector2(ux, ly), Vector2(uw, 90)):
		_canvas.draw_style_box(UiKit.box(col, 16, 3), shield)
	_canvas.draw_string(font, shield.position + Vector2(0, 38), t("ui.mini.guard.me"), HORIZONTAL_ALIGNMENT_CENTER, uw, 20, UiKit.INK)
	_canvas.draw_string(font, Vector2(W - 260, _canvas.size.y - 6),
		t("ui.mini.guard.miss").format({"miss": g.misses, "max": int(g.cfg["max_miss"])}), HORIZONTAL_ALIGNMENT_RIGHT, 250, 20, UiKit.INK)
	# 판정 자리의 큰 ○ / ✕
	for m in _marks:
		var a: float = clampf(m["t"] / 0.9, 0.0, 1.0)
		var c := Vector2(m["x"], ly)
		if m["ok"]:
			_canvas.draw_arc(c, 34, 0, TAU, 32, Color(UiKit.GOOD, a), 8)
		else:
			_canvas.draw_line(c + Vector2(-30, -30), c + Vector2(30, 30), Color(UiKit.BAD, a), 9)
			_canvas.draw_line(c + Vector2(30, -30), c + Vector2(-30, 30), Color(UiKit.BAD, a), 9)
	# 보초 위 말풍선
	var k := 0
	for p_ in _pops:
		var a2: float = clampf(p_["t"] / 0.4, 0.0, 1.0)
		var bw := 330.0
		var box := Rect2(Vector2(p_["x"] - bw / 2, p_["y"] - 52 - k * 60), Vector2(bw, 52))
		var bg := UiKit.GOOD.lightened(0.55) if p_["ok"] else UiKit.BAD.lightened(0.5)
		_canvas.draw_style_box(UiKit.box(Color(bg, a2), 16, 3), box)
		_canvas.draw_string(font, box.position + Vector2(10, 22), String(p_["text"]).get_slice("\n", 0), HORIZONTAL_ALIGNMENT_CENTER, bw - 20, 18, Color(UiKit.INK, a2))
		_canvas.draw_string(font, box.position + Vector2(10, 44), String(p_["text"]).get_slice("\n", 1), HORIZONTAL_ALIGNMENT_CENTER, bw - 20, 16, Color(UiKit.INK, a2))
		k += 1
