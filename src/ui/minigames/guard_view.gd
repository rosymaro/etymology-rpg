class_name GuardView
extends MinigameScreen
## 8 보초 서기: 성문 바깥에서 성문을 바라본다. 성벽 앞의 내 유닛을 손가락으로 좌우로 옮긴다.
## 뜻이 맞는 손님은 비켜서 통과시키고, 뜻이 틀린 손님과 담 넘는 단어는 막아선다.

const WALL_TOP := 30.0
const WALL_H := 190.0
const LINE_GAP := 40.0  ## 성벽 아래에서 막는 선까지

var _canvas: Control
var _msg: Label
var _flash := 0.0


func build() -> void:
	_canvas = Control.new()
	_canvas.anchor_right = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.offset_left = 16
	_canvas.offset_right = -16
	_canvas.offset_bottom = -50
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_field)
	_canvas.gui_input.connect(_input)
	body.add_child(_canvas)
	_msg = UiKit.wrap(UiKit.label("", 22, UiKit.ACCENT.darkened(0.2)), 1000)
	body.add_child(_msg)
	UiKit.pin(_msg, 0, 1, 24, -44)


func _input(ev: InputEvent) -> void:
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
	for e in g.events:
		var w := g.words[e["w"]]
		if e["kind"] == "climb":
			_msg.text = t("ui.mini.guard.climb_ok" if e["ok"] else "ui.mini.guard.climb_miss").format({"word": w.id})
		elif e["ok"]:
			_msg.text = t("ui.mini.guard.ok").format({"word": w.id, "meaning": w.meaning})
		else:
			_msg.text = t("ui.mini.guard.wrong").format({"word": w.id, "meaning": w.meaning})
		if not e["ok"]:
			_flash = 0.4
			GameData.vibrate()
	g.events.clear()
	_flash = maxf(0.0, _flash - delta)
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
			var r := Rect2(p - Vector2(80, 26), Vector2(160, 44))
			if not Art.draw(_canvas, "mini", "guard_climber", p, Vector2(180, 70)):
				_canvas.draw_style_box(UiKit.box(Color("f4a6a6"), 14, 3), r)
			_canvas.draw_string(font, r.position + Vector2(4, 30), "⚠ " + word.id, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 22, UiKit.INK)
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
