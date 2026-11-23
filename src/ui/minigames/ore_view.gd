class_name OreView
extends MinigameScreen
## 9 광석 캐기: 위에 광맥 어원 2개가 나온다. 튀어 오르는 단어 광석 중 그 어원이 든 단어만 그어 깬다.
## 광석은 모두 같은 모양이다(단어를 읽고 가려야 한다).

var _canvas: Control
var _last := Vector2(-1, -1)
var _trail: Array[Vector2] = []
var _pops: Array[Dictionary] = []


func build() -> void:
	_canvas = Control.new()
	_canvas.anchor_right = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.draw.connect(_draw_ores)
	_canvas.gui_input.connect(_on_canvas_input)
	body.add_child(_canvas)


func _on_canvas_input(ev: InputEvent) -> void:
	var g := game as OreSlashGame
	var s := OreSlashGame.AREA / _canvas.size if _canvas.size.x > 0 else Vector2.ONE
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_last = ev.position if ev.pressed else Vector2(-1, -1)
		_trail.clear()
	elif ev is InputEventMouseMotion and _last.x >= 0:
		g.slash(_last * s, ev.position * s)
		_trail.append(ev.position)
		if _trail.size() > 8:
			_trail.pop_front()
		_last = ev.position


func tick(delta: float) -> void:
	var g := game as OreSlashGame
	for e in g.events:
		var w := g.words[e["w"]]
		var text := t("ui.mini.ore.ok" if e["ok"] else "ui.mini.ore.bad").format({"word": w.id, "meaning": w.meaning})
		_pops.append({"text": text, "ok": e["ok"], "pos": e["pos"], "t": 1.6})
		GameData.vibrate(e["ok"])
	g.events.clear()
	for p_ in _pops:
		p_["t"] -= delta
	_pops = _pops.filter(func(p_: Dictionary) -> bool: return p_["t"] > 0.0)
	_canvas.queue_redraw()


func _draw_ores() -> void:
	var g := game as OreSlashGame
	var s := _canvas.size / OreSlashGame.AREA
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color("e8e0d8"))
	var parts: Array[String] = []
	for r0 in g.roots:
		parts.append("%s(%s)" % [r0["root"], r0["meaning"]])
	_canvas.draw_rect(Rect2(Vector2(0, 0), Vector2(_canvas.size.x, 44)), Color("f2d27a"))
	_canvas.draw_string(font, Vector2(20, 31), t("ui.mini.ore.target").format({"roots": "  ·  ".join(parts)}), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiKit.INK)
	_canvas.draw_string(font, Vector2(_canvas.size.x - 260, 31), t("ui.mini.guard.miss").format({"miss": g.misses, "max": int(g.cfg["max_miss"])}),
		HORIZONTAL_ALIGNMENT_RIGHT, 240, 20, UiKit.INK)
	var r := float(g.cfg["radius"]) * s.x
	for o in g.ores:
		var p: Vector2 = o["pos"] * s
		if not Art.draw(_canvas, "mini", "ore_rock", p, Vector2(r * 2.8, r * 2)):
			var pts := PackedVector2Array()
			for k in 9:
				var a := TAU * k / 9.0
				pts.append(p + Vector2(cos(a) * r * 1.4, sin(a) * r) * (0.88 + 0.12 * float((k * 7) % 3)))
			_canvas.draw_colored_polygon(pts, Color("b9aea2"))
			pts.append(pts[0])
			_canvas.draw_polyline(pts, UiKit.INK, 3)
		_canvas.draw_string(font, p + Vector2(-r * 1.4, 8), g.words[o["w"]].id, HORIZONTAL_ALIGNMENT_CENTER, r * 2.8, 20, UiKit.INK)
	for p_ in _pops:
		var c: Vector2 = p_["pos"] * s
		var box := Rect2(c - Vector2(150, 60), Vector2(300, 36))
		var bg := UiKit.GOOD.lightened(0.5) if p_["ok"] else UiKit.BAD.lightened(0.45)
		_canvas.draw_style_box(UiKit.box(Color(bg, clampf(p_["t"], 0.0, 1.0)), 14, 3), box)
		_canvas.draw_string(font, box.position + Vector2(6, 25), p_["text"], HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 12, 17, UiKit.INK)
	for i in range(1, _trail.size()):
		_canvas.draw_line(_trail[i - 1], _trail[i], Color(UiKit.ACCENT, 0.8), 6)
