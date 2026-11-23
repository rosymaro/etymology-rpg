class_name FishingView
extends MinigameScreen
## 5 낚시: 위에 뜻 미끼, 물속에는 영어 단어 물고기가 바늘 둘레로 모인다. 물고기를 눌러 채면 싸움이 시작된다.
## 싸움 중에는 화면 아무 곳이나 누르고 있으면 잡이 막대가 오르고, 떼면 내려간다.

const TRACK_H := 420.0

var _canvas: Control
var _bait: Label
var _msg: Label


func build() -> void:
	var top := UiKit.hbox(16)
	top.position = Vector2(40, 0)
	body.add_child(top)
	top.add_child(UiKit.label(t("ui.mini.fishing.bait"), 24))
	_bait = UiKit.label("", 34, UiKit.ACCENT.darkened(0.3))
	top.add_child(_bait)
	_msg = UiKit.wrap(UiKit.label("", 22, UiKit.INK), 1100)
	body.add_child(_msg)
	UiKit.pin(_msg, 0, 1, 40, -44)
	_canvas = Control.new()
	_canvas.anchor_right = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.offset_left = 40
	_canvas.offset_top = 56
	_canvas.offset_right = -40
	_canvas.offset_bottom = -54
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_sea)
	_canvas.gui_input.connect(_input)
	body.add_child(_canvas)


func _hook_pos() -> Vector2:
	return Vector2(_canvas.size.x * 0.36, _canvas.size.y * 0.55)


func _fish_at(f: Dictionary) -> Vector2:
	var rad := minf(_canvas.size.x * 0.3, _canvas.size.y * 0.42) * float(f["r"])
	return _hook_pos() + Vector2(cos(f["angle"]), sin(f["angle"]) * 0.7) * rad


func _fish_rect(f: Dictionary) -> Rect2:
	return Rect2(_fish_at(f) - Vector2(95, 26), Vector2(190, 52))


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var g := game as FishingGame
	if g.state == "fight":
		g.hold(ev.pressed)
		return
	if not ev.pressed:
		return
	for i in g.fish.size():
		if _fish_rect(g.fish[i]).has_point(ev.position):
			g.hook(i)
			_msg.text = t("ui.mini.fishing.fight_easy" if g.match_ else "ui.mini.fishing.fight_hard")
			return


func refresh() -> void:
	var g := game as FishingGame
	_bait.text = "「%s」" % g.bait().meaning if g.bait() else ""


func tick(_d: float) -> void:
	var g := game as FishingGame
	if not g.last.is_empty():
		var w := g.words[g.last["w"]]
		var key := "ui.mini.fishing.caught" if g.last["caught"] else "ui.mini.fishing.lost"
		_msg.text = t(key).format({"word": w.id, "meaning": w.meaning})
		GameData.vibrate(g.last["caught"])
		g.last = {}
		changed()
	_canvas.queue_redraw()


func _draw_sea() -> void:
	var g := game as FishingGame
	var font := ThemeDB.fallback_font
	var S := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, S), Color("bfe3f0"))
	_canvas.draw_rect(Rect2(0, 0, S.x, 30), Color("e6f4fa"))
	var hp := _hook_pos()
	_canvas.draw_line(Vector2(hp.x, 0), hp, UiKit.INK, 2)
	if not Art.draw(_canvas, "mini", "fish_bait", hp, Vector2(60, 60)):
		_canvas.draw_arc(hp + Vector2(0, -8), 10, 0, PI, 12, UiKit.INK, 3)
		_canvas.draw_circle(hp + Vector2(0, -16), 9, Color("f7a07a"))
	if g.state == "wait":
		for f in g.fish:
			var r := _fish_rect(f)
			if not Art.draw(_canvas, "mini", "fish_word", r.get_center(), r.size + Vector2(40, 20)):
				_canvas.draw_style_box(UiKit.box(Color("fff3c4"), 26, 3), r)
				var tail := r.position + Vector2(r.size.x, r.size.y / 2)
				_canvas.draw_colored_polygon([tail, tail + Vector2(20, -14), tail + Vector2(20, 14)], Color("ffd59e"))
			_canvas.draw_string(font, r.position + Vector2(6, 34), g.words[f["w"]].id, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12, 22, UiKit.INK)
		return
	# 싸움: 오른쪽에 세로 칸(막대, 물고기)과 손맛 게이지
	var word := g.words[g.hooked]
	_canvas.draw_string(font, Vector2(hp.x - 200, hp.y + 70), word.id, HORIZONTAL_ALIGNMENT_CENTER, 400, 40, UiKit.INK)
	_canvas.draw_string(font, Vector2(hp.x - 200, hp.y + 110), t("ui.mini.fishing.hold"), HORIZONTAL_ALIGNMENT_CENTER, 400, 22, UiKit.INK.lightened(0.2))
	var th := minf(TRACK_H, S.y - 20)
	var tr_ := Rect2(S.x * 0.72, (S.y - th) / 2, 70, th)
	_canvas.draw_style_box(UiKit.box(Color("3d6b80"), 12, 3), tr_)
	var bar := Rect2(tr_.position.x + 6, tr_.end.y - (g.bar_pos + g.bar_size()) * th, 58, g.bar_size() * th)
	_canvas.draw_rect(bar, Color(0.55, 0.9, 0.45, 0.85) if g.inside() else Color(0.55, 0.9, 0.45, 0.5))
	var fp := Vector2(tr_.get_center().x, tr_.end.y - g.fish_pos * th)
	if not Art.draw(_canvas, "mini", "fish_word", fp, Vector2(56, 36)):
		_canvas.draw_circle(fp, 14, Color("ffb070"))
	var gauge := Rect2(tr_.end.x + 18, tr_.position.y, 22, th)
	_canvas.draw_rect(gauge, Color(1, 1, 1, 0.6))
	var fill := th * clampf(g.progress, 0.0, 1.0)
	_canvas.draw_rect(Rect2(gauge.position.x, gauge.end.y - fill, 22, fill), UiKit.ACCENT)
	_canvas.draw_string(font, Vector2(S.x - 300, S.y - 8), t("ui.mini.guard.miss").format({"miss": g.misses, "max": int(g.cfg["max_miss"])}),
		HORIZONTAL_ALIGNMENT_RIGHT, 290, 20, UiKit.INK)
