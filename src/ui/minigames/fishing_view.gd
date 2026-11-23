class_name FishingView
extends MinigameScreen
## 5 낚시: 물을 위에서 본다. 누르고 있으면 찌를 던지고, 물고기가 입질하면 원이 줄어든다. 원이 작아지면 손을 뗀다.
## 싸움에서는 물고기 둘레 6개 원 중 점이 날아가는 원을, 점이 닿을 때 누른다.

const FIGHT_R := 170.0
const NOTE_R := 46.0

var _canvas: Control
var _bait: Label
var _msg: Label
var _was_bite := false
var _flash: Dictionary = {}  ## 방향 -> {ok, t}


func build() -> void:
	var top := UiKit.hbox(16)
	top.position = Vector2(40, 0)
	body.add_child(top)
	top.add_child(UiKit.label(t("ui.mini.fishing.bait"), 24))
	_bait = UiKit.label("", 34, UiKit.ACCENT.darkened(0.3))
	top.add_child(_bait)
	_canvas = Control.new()
	_canvas.anchor_right = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.offset_left = 24
	_canvas.offset_top = 56
	_canvas.offset_right = -24
	_canvas.offset_bottom = -12
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_water)
	_canvas.gui_input.connect(_input)
	body.add_child(_canvas)
	_msg = UiKit.wrap(UiKit.label("", 22, UiKit.INK), 900)
	_msg.position = Vector2(40, 60)
	body.add_child(_msg)


func _px(p: Vector2) -> Vector2:
	return p * _canvas.size


func _center() -> Vector2:
	return _canvas.size / 2.0


func _note_pos(d: int, k: float) -> Vector2:
	var a := -PI / 2 + TAU * d / FishingGame.DIRS
	return _center() + Vector2(cos(a), sin(a)) * FIGHT_R * k


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var g := game as FishingGame
	if g.state == "fight":
		if ev.pressed:
			for d in FishingGame.DIRS:
				if ev.position.distance_to(_note_pos(d, 1.0)) <= NOTE_R + 10:
					g.tap(d)
					return
		return
	if ev.pressed:
		g.cast(ev.position / _canvas.size)
		_msg.text = t("ui.mini.fishing.wait")
	else:
		match g.release():
			"hook":
				_msg.text = t("ui.mini.fishing.fight_easy" if g.match_ else "ui.mini.fishing.fight_hard").format({"n": g.need()})
				GameData.vibrate(true)
			"early":
				_msg.text = t("ui.mini.fishing.early")
			"cancel":
				_msg.text = ""


func refresh() -> void:
	var g := game as FishingGame
	_bait.text = "「%s」" % g.bait().meaning if g.bait() else ""


func tick(delta: float) -> void:
	var g := game as FishingGame
	var bite := g.state == "bite"
	if bite and not _was_bite:  # 입질: 진동
		GameData.vibrate(true)
		_msg.text = t("ui.mini.fishing.bite")
	if _was_bite and g.state == "idle" and g.last.is_empty() and _msg.text == t("ui.mini.fishing.bite"):
		_msg.text = t("ui.mini.fishing.ate")
	_was_bite = bite
	for e in g.note_events:
		_flash[e["dir"]] = {"ok": e["ok"], "t": 0.35}
		if not e["ok"]:
			GameData.vibrate()
	g.note_events.clear()
	for d in _flash.keys():
		_flash[d]["t"] -= delta
		if _flash[d]["t"] <= 0.0:
			_flash.erase(d)
	if not g.last.is_empty():
		var w := g.words[g.last["w"]]
		_msg.text = t("ui.mini.fishing.caught" if g.last["caught"] else "ui.mini.fishing.lost").format({"word": w.id, "meaning": w.meaning})
		GameData.vibrate(g.last["caught"])
		g.last = {}
		changed()
	_canvas.queue_redraw()


func _draw_fish(c: Vector2, word_id: String, dir: Vector2, scale_: float = 1.0) -> void:
	var font := ThemeDB.fallback_font
	var d := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var size := Vector2(150, 54) * scale_
	if not Art.draw(_canvas, "mini", "fish_top", c, size):
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			var v := Vector2(cos(a) * size.x / 2, sin(a) * size.y / 2)
			pts.append(c + v.rotated(d.angle()))
		_canvas.draw_colored_polygon(pts, Color("fff3c4"))
		var tail := c - d * size.x / 2
		_canvas.draw_colored_polygon([tail, tail - d * 22 * scale_ + d.orthogonal() * 16 * scale_, tail - d * 22 * scale_ - d.orthogonal() * 16 * scale_], Color("ffd59e"))
	_canvas.draw_string(font, c + Vector2(-size.x / 2, 7 * scale_), word_id, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(20 * scale_), UiKit.INK)


func _draw_water() -> void:
	var g := game as FishingGame
	var font := ThemeDB.fallback_font
	var S := _canvas.size
	_canvas.draw_style_box(UiKit.box(Color("8fcbe3"), 24, 3), Rect2(Vector2.ZERO, S))
	for i in 7:  # 잔물결
		var y := S.y * (0.12 + i * 0.13)
		_canvas.draw_arc(Vector2(S.x * (0.15 + fmod(i * 0.37, 0.7)), y), 30, PI * 1.1, PI * 1.9, 10, Color(1, 1, 1, 0.35), 2)
	if g.state == "fight":
		_draw_fight(g, font)
		return
	for i in g.fish.size():
		var f: Dictionary = g.fish[i]
		var to: Vector2 = f["vel"]
		if i == g.biter and g.state in ["cast", "bite"]:
			to = g.bobber - (f["pos"] as Vector2)
		_draw_fish(_px(f["pos"]), g.words[f["w"]].id, to)
	if g.state in ["cast", "bite"]:
		var b := _px(g.bobber)
		_canvas.draw_circle(b, 12, Color("f07070"))
		_canvas.draw_circle(b + Vector2(0, -4), 6, Color.WHITE)
		if g.state == "bite":
			var ok := g.ring <= float(g.cfg["hook_ring"])
			_canvas.draw_arc(b, 20 + 120 * g.ring, 0, TAU, 48, UiKit.GOOD if ok else Color.WHITE, 5)
			_canvas.draw_arc(b, 20 + 120 * float(g.cfg["hook_ring"]), 0, TAU, 48, Color(UiKit.GOOD, 0.5), 2)
	_canvas.draw_string(font, Vector2(S.x - 300, S.y - 12), t("ui.mini.guard.miss").format({"miss": g.misses, "max": int(g.cfg["max_miss"])}),
		HORIZONTAL_ALIGNMENT_RIGHT, 290, 20, UiKit.INK)


func _draw_fight(g: FishingGame, font: Font) -> void:
	var c := _center()
	_canvas.draw_circle(c, FIGHT_R + 60, Color(0.2, 0.35, 0.5, 0.25))
	for d in FishingGame.DIRS:
		var p := _note_pos(d, 1.0)
		var col := Color.WHITE
		if _flash.has(d):
			col = UiKit.GOOD if _flash[d]["ok"] else UiKit.BAD
		elif d == g.note_dir:
			col = UiKit.ACCENT.lightened(0.4)
		_canvas.draw_circle(p, NOTE_R, Color(col, 0.85))
		_canvas.draw_arc(p, NOTE_R, 0, TAU, 32, UiKit.INK, 3)
	if g.note_dir >= 0:
		var k := minf(g.note_t, 1.2)
		var hit := g.note_t >= float(g.cfg["hit_from"])
		_canvas.draw_circle(_note_pos(g.note_dir, k), 16, UiKit.ACCENT.darkened(0.1) if hit else UiKit.INK)
	_draw_fish(c, g.words[g.hooked].id, Vector2.RIGHT.rotated(sin(Time.get_ticks_msec() / 150.0) * 0.4), 1.3)
	_canvas.draw_string(font, Vector2(c.x - 200, c.y + FIGHT_R + 90), t("ui.mini.fishing.hits").format({"n": g.hits, "need": g.need(), "left": g.notes_left}),
		HORIZONTAL_ALIGNMENT_CENTER, 400, 22, UiKit.INK)
