class_name OreView
extends MinigameScreen
## 9 광석 캐기: 화면을 그어 튀어 오르는 광석을 깬다. 광맥 색과 같은 광석만. 연속 5개마다 단어 1개.

var _canvas: Control
var _last := Vector2(-1, -1)
var _trail: Array[Vector2] = []


func build() -> void:
	_canvas = Control.new()
	_canvas.anchor_right = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.draw.connect(_draw_ores)
	_canvas.gui_input.connect(_input)
	body.add_child(_canvas)


func _input(ev: InputEvent) -> void:
	var g := game as OreSlashGame
	var s := OreSlashGame.AREA / _canvas.size if _canvas.size.x > 0 else Vector2.ONE
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_last = ev.position if ev.pressed else Vector2(-1, -1)
		_trail.clear()
	elif ev is InputEventMouseMotion and _last.x >= 0:
		var before := g.combo
		if g.slash(_last * s, ev.position * s) > 0 and g.combo < before:
			GameData.vibrate()
		_trail.append(ev.position)
		if _trail.size() > 8:
			_trail.pop_front()
		_last = ev.position


func tick(_d: float) -> void:
	_canvas.queue_redraw()


func _draw_ores() -> void:
	var g := game as OreSlashGame
	var s := _canvas.size / OreSlashGame.AREA
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color("e8e0d8"))
	var tc := MinigameScreen.attr_color(g.target_attr)
	_canvas.draw_rect(Rect2(Vector2(0, 0), Vector2(_canvas.size.x, 36)), tc)
	_canvas.draw_string(font, Vector2(20, 26), t("ui.mini.ore.target").format({"attr": t("name.attr.%02d" % g.target_attr),
		"combo": g.combo, "per": int(g.cfg["combo_per_word"])}), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiKit.INK)
	var r := float(g.cfg["radius"]) * s.x
	for o in g.ores:
		var p: Vector2 = o["pos"] * s
		_canvas.draw_circle(p, r, tc if o["target"] else UiKit.GRAY.darkened(0.15))
		_canvas.draw_arc(p, r, 0, TAU, 20, UiKit.INK, 3)
	for i in range(1, _trail.size()):
		_canvas.draw_line(_trail[i - 1], _trail[i], Color(UiKit.ACCENT, 0.8), 6)
