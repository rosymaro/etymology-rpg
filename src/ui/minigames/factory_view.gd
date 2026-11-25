class_name FactoryView
extends MinigameScreen
## 말 공방 화면(05-minigames): [에너그램] - [어원 조합] - [단어 뜻] 영역이 옆으로 이어진다. 한 번에 한 영역이 보이고,
## 양쪽 끝 화살표를 누르면 옆 영역으로 옮겨 간다. 영역마다 위에 칠판(어원 + 어원 = 단어 → 뜻).
## 벨트는 사각형 한 바퀴: 앞 절반(t < 0.5)은 에너그램 영역 오른쪽에, 뒤 절반은 어원 조합 영역에 보인다.
## 어원은 눌러서(또는 끌어서) 용광로에 넣는다. 에너그램 쪽 어원은 쓰레기통으로 끌어 버린다.
## 쌓인 단어는 끌어서 진열대 칸에 놓는다. 달아오른 용광로를 누르면 단어찾기가 열린다.

const PILL := Vector2(104, 40)
const CARD := Vector2(150, 44)
## 세로 화면: 위에서부터 칠판 → 벨트 → (용광로 | 에너그램 책상 | 진열대)
const BOARD_H := 300.0
const BELT_TOP := 340.0
const BELT_BOTTOM := 640.0
const BOARD_TOP_S := 26.0  ## 단어찾기: 남은 시간 막대 아래 칠판 위치
const CHALK := Color("2f4a3a")
const CHALK_INK := Color("f4f1e6")
const BELT_COL := Color("8b7d6b")

var g: FactoryGame
var _canvas: Control
var _cam := 0.0  ## 보이는 영역의 왼쪽 x(세계 좌표)
var _area := 0  ## 보이는 영역 순번
var _aw := 688.0
var _msg: Label
var _miss: Label
var _nav_l: Button
var _nav_r: Button
var _drag := {}  ## {kind: "item"|"card", uid|i, pos, start, moved}
var _answer: Array[int] = []  ## 에너그램: 고른 글자 칸 순번
var _shake := 0.0
var _flash := {}  ## 잠깐 빛나는 것: {"furnace": 남은 초, "shelf<k>": 남은 초}
var _search_box: Control
var _search_canvas: Control
var _search_sel := {}  ## {a, b}
var _search_time: Label
var _intro: PanelContainer
var _snapped := false  ## 처음 한 번은 바로 그 영역으로


func build() -> void:
	g = game as FactoryGame
	_canvas = Control.new()
	_canvas.anchor_right = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.offset_left = 16
	_canvas.offset_right = -16
	_canvas.offset_bottom = -8
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_world)
	_canvas.gui_input.connect(_on_input)
	body.add_child(_canvas)
	_msg = UiKit.label("", 22, UiKit.INK)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(680, 0)
	body.add_child(_msg)
	UiKit.pin(_msg, 0.5, 1, 0, -84)
	_miss = UiKit.label("", 22, UiKit.BAD.darkened(0.2))
	add_child(_miss)
	UiKit.pin(_miss, 1, 0, -150, 18)
	_nav_l = UiKit.button("◀", func() -> void: _go(_area - 1), UiKit.SKY, 22)
	_nav_r = UiKit.button("▶", func() -> void: _go(_area + 1), UiKit.SKY, 22)
	for b in [_nav_l, _nav_r]:
		(b as Button).custom_minimum_size = Vector2(200, 60)
		body.add_child(b)
	UiKit.pin(_nav_l, 0, 1, 20, -8)
	UiKit.pin(_nav_r, 1, 1, -20, -8)
	_area = g.areas().find(FactoryGame.COMBINE) if g.has(FactoryGame.COMBINE) else 0
	_build_search()
	if bool(g.cfg.get("search_reverse", false)):
		_show_intro(t("ui.factory.reverse_intro"))
	_tutorial.call_deferred()


## 미니게임마다 처음(08-tutorial.md 2절): 칠판 → 벨트 → 아래 작업대 → (영역이 여럿이면) 옆 영역 버튼.
func _tutorial() -> void:
	await get_tree().process_frame
	var id := "minigame_" + String(game_id)
	var key := "tut.mini.%s." % String(game_id)
	var c := _canvas
	var at := func(r: Rect2) -> Callable: return func() -> Rect2: return Rect2(c.get_global_rect().position + r.position, r.size)
	var steps: Array[Dictionary] = [
		{"target": at.call(Rect2(16, 4, _aw - 32, BOARD_H)), "text": key + "1", "mode": "any"},
		{"target": at.call(Rect2(0, BELT_TOP - 30, _aw, BELT_BOTTOM - BELT_TOP + 60)), "text": key + "2", "mode": "any"},
		{"target": at.call(Rect2(0, BELT_BOTTOM + 50, _aw, 280)), "text": key + "3", "mode": "any"},
	]
	if g.areas().size() > 1:
		steps.append({"target": _nav_r, "text": "tut.mini.nav", "mode": "any"})
	TutorialOverlay.run(self, id, steps)


# ----- 좌표 -----

func _area_x(area: String) -> float:
	return g.areas().find(area) * _aw


## 벨트 사각형: X0(왼쪽) Xm(앞 절반과 뒤 절반의 경계) X1(오른쪽)
func _belt_x() -> Vector3:
	if g.has(FactoryGame.ANAGRAM):
		var a := _area_x(FactoryGame.ANAGRAM)
		var xm := a + _aw
		var x1 := (_area_x(FactoryGame.COMBINE) + _aw * 0.85) if g.has(FactoryGame.COMBINE) else xm + _aw * 0.4
		return Vector3(a + _aw * 0.12, xm, x1)
	var c := _area_x(FactoryGame.COMBINE)
	return Vector3(c + 60, c + _aw * 0.5, c + _aw - 60)


func belt_pos(t: float) -> Vector2:
	var bx := _belt_x()
	var x0 := bx.x
	var xm := bx.y
	var x1 := bx.z
	var y0 := BELT_TOP
	var y1 := BELT_BOTTOM
	var segs: Array
	var s: float
	if t < 0.5:
		segs = [[Vector2(xm, y1), Vector2(x0, y1)], [Vector2(x0, y1), Vector2(x0, y0)], [Vector2(x0, y0), Vector2(xm, y0)]]
		s = t / 0.5
	else:
		segs = [[Vector2(xm, y0), Vector2(x1, y0)], [Vector2(x1, y0), Vector2(x1, y1)], [Vector2(x1, y1), Vector2(xm, y1)]]
		s = (t - 0.5) / 0.5
	var total := 0.0
	for sg in segs:
		total += (sg[1] as Vector2).distance_to(sg[0])
	var d := s * total
	for sg in segs:
		var l := (sg[1] as Vector2).distance_to(sg[0])
		if d <= l:
			return (sg[0] as Vector2).lerp(sg[1], d / maxf(1.0, l))
		d -= l
	return segs[-1][1]


func _furnace_rect() -> Rect2:
	var c := _area_x(FactoryGame.COMBINE)
	return Rect2(c + _aw / 2 - 115, BELT_BOTTOM + 60, 230, 160)


func _hammer_rect() -> Rect2:
	var f := _furnace_rect()
	return Rect2(f.position.x, f.end.y + 14, f.size.x, 62)


func _takeout_rect() -> Rect2:
	var f := _furnace_rect()
	return Rect2(f.position.x, f.end.y + 88, f.size.x, 50)


func _trash_rect() -> Rect2:
	var a := _area_x(FactoryGame.ANAGRAM)
	return Rect2(_desk_x(), BELT_BOTTOM + 266, 150, 60)


func _desk_x() -> float:
	return _area_x(FactoryGame.ANAGRAM) + 30


func _tile_rect(k: int, row: int) -> Rect2:
	return Rect2(_desk_x() + k * 62, BELT_BOTTOM + 96 + row * 80, 56, 64)


func _skip_rect() -> Rect2:
	return Rect2(_desk_x() + 165, BELT_BOTTOM + 266, 150, 60)


func _clear_rect() -> Rect2:
	return Rect2(_desk_x() + 330, BELT_BOTTOM + 266, 150, 60)


func _card_rect(n: int) -> Rect2:
	var s := _area_x(FactoryGame.SHELF)
	var cols := 4
	return Rect2(s + 24 + (n % cols) * (CARD.x + 10), BOARD_H + 30 + (n / cols) * (CARD.y + 10), CARD.x, CARD.y)


func _slot_rect(k: int) -> Rect2:
	var s := _area_x(FactoryGame.SHELF)
	var n := g.slots.size()
	var w := (_aw - 48 - (n - 1) * 10) / n
	return Rect2(s + 24 + k * (w + 10), 700, w, 190)


func _item_at(p: Vector2) -> Dictionary:
	for i in range(g.belt.size() - 1, -1, -1):
		var it: Dictionary = g.belt[i]
		if Rect2(belt_pos(it["t"]) - PILL / 2, PILL).grow(6).has_point(p):
			return it
	return {}


# ----- 영역 옮기기 -----

func _go(k: int) -> void:
	if k < 0 or k >= g.areas().size():
		return
	_area = k  # 화면은 tick에서 부드럽게 따라간다


func _area_name(k: int) -> String:
	return t("ui.factory.area." + String(g.areas()[k]))


# ----- 입력 -----

func _on_input(ev: InputEvent) -> void:
	if g.finished or g.search or _intro:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = ev.position + Vector2(_cam, 0)
		if ev.pressed:
			_press(p)
		else:
			_release(p)
	elif ev is InputEventMouseMotion and not _drag.is_empty():
		var p: Vector2 = ev.position + Vector2(_cam, 0)
		_drag["pos"] = p
		if p.distance_to(_drag["start"]) > 14:
			_drag["moved"] = true


func _press(p: Vector2) -> void:
	var it := _item_at(p)
	if not it.is_empty():
		_drag = {"kind": "item", "uid": it["uid"], "pos": p, "start": p, "moved": false}
		return
	if g.has(FactoryGame.SHELF):
		for n in g.stack.size():
			if _card_rect(n).has_point(p):
				_drag = {"kind": "card", "i": g.stack[n], "pos": p, "start": p, "moved": false}
				return
	if g.has(FactoryGame.COMBINE):
		if _furnace_rect().has_point(p) and g.hot:
			_open_search()
			return
		if g.absorb_n() == 0 and _hammer_rect().has_point(p):
			_hammer()
			return
		if g.absorb_n() == 0 and _takeout_rect().has_point(p):
			while not g.furnace.is_empty():
				g.take_out(0)
			return
	if g.has(FactoryGame.ANAGRAM) and not g.puzzle.is_empty():
		var letters: Array = g.puzzle["letters"]
		for k in letters.size():
			if not k in _answer and _tile_rect(k, 0).has_point(p):
				_answer.append(k)
				if _answer.size() == letters.size():
					_submit()
				return
		for k in _answer.size():
			if _tile_rect(k, 1).has_point(p):
				_answer.remove_at(k)
				return
		if _clear_rect().has_point(p):
			_answer.clear()
			return
		if bool(g.cfg.get("skip", false)) and _skip_rect().has_point(p):
			_answer.clear()
			g.skip()
			_say(t("ui.factory.skipped"))


func _release(p: Vector2) -> void:
	if _drag.is_empty():
		return
	var d := _drag
	_drag = {}
	if d["kind"] == "item":
		var it := g.item(d["uid"])
		if it.is_empty():
			return
		if g.has(FactoryGame.ANAGRAM) and bool(g.cfg.get("trash", false)) and _trash_rect().has_point(p):
			if g.trash(d["uid"]):
				_say(t("ui.factory.trashed").format({"root": it["form"]}))
			else:
				_say(t("ui.factory.trash_side"))
			return
		var to_furnace: bool = not d["moved"] or _furnace_rect().grow(30).has_point(p)
		if to_furnace and g.has(FactoryGame.COMBINE):
			_put(d["uid"])
	elif d["kind"] == "card":
		for k in g.slots.size():
			if _slot_rect(k).has_point(p):
				_place(d["i"], k)
				return


func _put(uid: int) -> void:
	var it := g.item(uid)
	var form: String = it.get("form", "")
	match g.put(uid):
		"in":
			pass
		"absorbed":
			_flash["furnace"] = 0.4
			var n := g.absorb_shown()
			_say(t("ui.factory.absorbed").format({"root": form, "n": n.x, "max": n.y}))
			if g.hot:
				_say(t("ui.factory.hot"))
				GameData.vibrate(true)
		"miss":
			_shake = 0.4
			_say(t("ui.factory.rejected").format({"root": form}))
			GameData.vibrate(false)
		"hot":
			_say(t("ui.factory.hot"))
		"full":
			_say(t("ui.factory.full"))
		"none":
			if g.has(FactoryGame.ANAGRAM):
				_say(t("ui.factory.not_yet"))
	changed()


func _hammer() -> void:
	if g.furnace.is_empty():
		_say(t("ui.factory.empty"))
		return
	var i := g.hammer()
	if i >= 0:
		_flash["furnace"] = 0.6
		var key := "ui.factory.made_stack" if g.has(FactoryGame.SHELF) else "ui.factory.made"
		_say(t(key).format({"word": g.board[i]["id"], "meaning": g.board[i]["meaning"]}))
		GameData.vibrate(true)
	else:
		_shake = 0.5
		_say(t("ui.factory.burnt"))
		GameData.vibrate(false)
	changed()


func _submit() -> void:
	var letters: Array = g.puzzle["letters"]
	var s := ""
	for k in _answer:
		s += letters[k]
	_answer.clear()
	match g.submit(s):
		"ok":
			_say(t("ui.factory.anagram_ok").format({"root": s}))
		"wrong":
			_shake = 0.4
			_say(t("ui.factory.anagram_wrong_miss") if bool(g.cfg.get("anagram_miss", false)) else t("ui.factory.anagram_wrong"))
			GameData.vibrate(false)
	changed()


func _place(i: int, k: int) -> void:
	var slot_word: int = g.slots[k]
	if g.place(i, k):
		_flash["shelf%d" % k] = 0.5
		_say(t("ui.factory.shelved").format({"word": g.board[i]["id"], "meaning": g.board[i]["meaning"]}))
		GameData.vibrate(true)
	elif slot_word >= 0:
		_shake = 0.4
		_say(t("ui.factory.wrong_shelf").format({"word": g.board[i]["id"], "meaning": g.board[i]["meaning"]}))
		GameData.vibrate(false)
	changed()


func _say(text: String) -> void:
	_msg.text = text


func _show_intro(text: String) -> void:
	_intro = UiKit.card(UiKit.APRICOT.lightened(0.3))
	_intro.z_index = 30
	var v := UiKit.vbox(16)
	_intro.add_child(v)
	var l := UiKit.wrap(UiKit.label(text, 26), 580)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var ok := UiKit.button(t("ui.common.ok"), func() -> void:
		_intro.queue_free()
		_intro = null, UiKit.LEAF, 26)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ok)
	add_child(_intro)
	UiKit.pin(_intro, 0.5, 0.5, 0, 0)


# ----- 시간 -----

func tick(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta)
	for k in _flash.keys():
		_flash[k] = float(_flash[k]) - delta
		if _flash[k] <= 0.0:
			_flash.erase(k)
	_aw = maxf(600.0, _canvas.size.x)
	_cam = lerpf(_cam, _area * _aw, minf(1.0, delta * 10.0)) if _snapped else _area * _aw
	_snapped = true
	if absf(_cam - _area * _aw) < 1.0:
		_cam = _area * _aw
	_nav_l.visible = _area > 0
	_nav_r.visible = _area < g.areas().size() - 1
	if _nav_l.visible:
		_nav_l.text = "◀ " + _area_name(_area - 1)
	if _nav_r.visible:
		_nav_r.text = _area_name(_area + 1) + " ▶"
	_miss.text = t("ui.factory.misses").format({"marks": "✕".repeat(g.misses) + "○".repeat(maxi(0, int(g.cfg["max_miss"]) - g.misses))})
	match g.last:
		"exited":
			_say(t("ui.factory.exited"))
		"found":
			pass
	g.last = ""
	_search_box.visible = g.search != null
	if g.search:
		_search_time.text = t("ui.factory.search_time").format({"s": int(ceil(g.search_left)), "n": g.search.found.size(), "max": g.search.placed.size()})
		_search_canvas.queue_redraw()
	_canvas.queue_redraw()


# ----- 그리기 -----

func _draw_world() -> void:
	var font := ThemeDB.fallback_font
	var sx := sin(Time.get_ticks_msec() / 30.0) * 8.0 * _shake / 0.5
	_canvas.draw_set_transform(Vector2(-_cam + sx, 0))
	for k in g.areas().size():
		var x := k * _aw
		_canvas.draw_rect(Rect2(x, 0, _aw, _canvas.size.y), Color("f3ead8") if k % 2 == 0 else Color("efe3cc"))
		_draw_board(Rect2(x + 16, 4, _aw - 32, BOARD_H), font)
	_draw_belt(font)
	if g.has(FactoryGame.COMBINE):
		_draw_furnace(font)
	if g.has(FactoryGame.ANAGRAM):
		_draw_anagram(font)
	if g.has(FactoryGame.SHELF):
		_draw_shelf(font)
	# 끌고 있는 것
	if not _drag.is_empty() and _drag["moved"]:
		var p: Vector2 = _drag["pos"]
		if _drag["kind"] == "item":
			var it := g.item(_drag["uid"])
			if not it.is_empty():
				_pill(p, it["form"], font, UiKit.ACCENT.lightened(0.4))
		else:
			var r := Rect2(p - CARD / 2, CARD)
			_canvas.draw_rect(r, UiKit.ACCENT.lightened(0.4))
			_canvas.draw_string(font, r.position + Vector2(0, 30), String(g.board[_drag["i"]]["id"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, UiKit.INK)
	_canvas.draw_set_transform(Vector2.ZERO)


## 칠판: 단어가 많으면 2단, 확보한(찾은) 단어는 흐리게 ✓. ci = 그릴 곳, ids = 적을 칠판 순번(비면 모두)
func _draw_board(r: Rect2, font: Font, ci: CanvasItem = null, ids: Array[int] = [], note := "") -> void:
	if ci == null:
		ci = _canvas
	ids = ids.duplicate()  # 기본값 배열을 고치지 않게
	if ids.is_empty():
		for i in g.board.size():
			ids.append(i)
	ci.draw_rect(r, CHALK)
	ci.draw_rect(r, Color("8a6d3b"), false, 6.0)
	var top := 12.0
	if note != "":
		ci.draw_string(font, r.position + Vector2(14, 30), note, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 18, Color("ffd59e"))
		top = 40.0
	var n := ids.size()
	var cols := 1 if n <= 10 else 2
	var rows := int(ceil(n / float(cols)))
	var row_h := minf(30.0, (r.size.y - top - 4) / rows)
	var fs := int(clampf(row_h * 0.62, 12, 19) if cols == 1 else clampf(row_h * 0.55, 12, 16))
	var cw := (r.size.x - 24) / cols
	for k in n:
		var i := ids[k]
		var c := k / rows
		var row := k % rows
		var p := r.position + Vector2(14 + c * cw, top + row * row_h + row_h * 0.72)
		var done: bool = g.board[i]["state"] == FactoryGame.DONE or (g.search != null and String(g.board[i]["id"]).to_lower() in g.search.found)
		var col := CHALK_INK.darkened(0.45) if done else CHALK_INK
		ci.draw_string(font, p, ("✓ " if done else "") + g.board_line(i), HORIZONTAL_ALIGNMENT_LEFT, cw - 10, fs, col)


func _draw_belt(font: Font) -> void:
	var bx := _belt_x()
	var pts := PackedVector2Array()
	for k in 81:
		pts.append(belt_pos(k / 80.0 if k < 80 else 0.0))
	if not g.has(FactoryGame.COMBINE):  # 에너그램만: 앞 절반만 그린다(뒤는 벨트 너머)
		pts = PackedVector2Array()
		for k in 41:
			pts.append(belt_pos(k / 80.0 * 0.999))
	_canvas.draw_polyline(pts, BELT_COL, PILL.y + 18, true)
	_canvas.draw_polyline(pts, BELT_COL.darkened(0.3), 3.0, true)
	if g.has(FactoryGame.ANAGRAM) and g.has(FactoryGame.COMBINE):
		_canvas.draw_line(Vector2(bx.y, BELT_TOP - 40), Vector2(bx.y, BELT_BOTTOM + 40), Color(0, 0, 0, 0.15), 3.0)
	for it in g.belt:
		if not _drag.is_empty() and _drag["kind"] == "item" and _drag["uid"] == it["uid"] and _drag["moved"]:
			continue
		_pill(belt_pos(it["t"]), it["form"], font, UiKit.PAPER)


func _pill(c: Vector2, text: String, font: Font, col: Color) -> void:
	var r := Rect2(c - PILL / 2, PILL)
	_canvas.draw_rect(r, col)
	_canvas.draw_rect(r, UiKit.INK, false, 2.0)
	_canvas.draw_string(font, r.position + Vector2(0, 28), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, UiKit.INK)


func _draw_furnace(font: Font) -> void:
	var f := _furnace_rect()
	# 벨트에서 용광로로 내려가는 홈통
	_canvas.draw_line(belt_pos(float(g.cfg.get("furnace_t", 0.9))) + Vector2(0, 20), f.position + Vector2(f.size.x / 2, 0), BELT_COL.darkened(0.2), 14.0)
	var heat := 1.0 if g.hot else (0.5 if _flash.has("furnace") else 0.0)
	var col := Color("6b5b55").lerp(Color("e0452c"), heat)
	if g.hot:
		col = col.lerp(Color("ff8a3d"), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0))
	_canvas.draw_rect(f, col)
	_canvas.draw_rect(f, UiKit.INK, false, 3.0)
	_canvas.draw_string(font, f.position + Vector2(0, 30), t("ui.factory.furnace"), HORIZONTAL_ALIGNMENT_CENTER, f.size.x, 22, Color.WHITE)
	if g.absorb_n() > 0:
		var n := g.absorb_shown()
		_canvas.draw_string(font, f.position + Vector2(0, 100), "%d / %d" % [n.x, n.y], HORIZONTAL_ALIGNMENT_CENTER, f.size.x, 40, Color.WHITE)
		if g.hot:
			_canvas.draw_string(font, f.position + Vector2(0, 150), t("ui.factory.tap_hot"), HORIZONTAL_ALIGNMENT_CENTER, f.size.x, 18, Color.WHITE)
		return
	for k in g.furnace.size():
		_pill(f.position + Vector2(f.size.x / 2, 66 + k * 0) + Vector2((k % 2) * 108 - 54, (k / 2) * 46), g.furnace[k]["form"], font, UiKit.APRICOT)
	var h := _hammer_rect()
	_canvas.draw_rect(h, UiKit.LEAF if not g.furnace.is_empty() else UiKit.GRAY)
	_canvas.draw_rect(h, UiKit.INK, false, 2.0)
	_canvas.draw_string(font, h.position + Vector2(0, 38), t("ui.factory.hammer"), HORIZONTAL_ALIGNMENT_CENTER, h.size.x, 24, UiKit.INK)
	var o := _takeout_rect()
	_canvas.draw_rect(o, UiKit.PAPER)
	_canvas.draw_rect(o, UiKit.INK, false, 2.0)
	_canvas.draw_string(font, o.position + Vector2(0, 30), t("ui.factory.takeout"), HORIZONTAL_ALIGNMENT_CENTER, o.size.x, 20, UiKit.INK)


func _draw_anagram(font: Font) -> void:
	var a := _area_x(FactoryGame.ANAGRAM)
	_canvas.draw_string(font, Vector2(_desk_x(), BELT_BOTTOM + 78), t("ui.factory.anagram_title"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiKit.INK)
	if g.puzzle.is_empty():
		_canvas.draw_string(font, Vector2(_desk_x(), BELT_BOTTOM + 130), t("ui.factory.anagram_none"), HORIZONTAL_ALIGNMENT_LEFT, 500, 20, UiKit.INK)
	else:
		var letters: Array = g.puzzle["letters"]
		for k in letters.size():
			var r := _tile_rect(k, 0)
			var used := k in _answer
			_canvas.draw_rect(r, UiKit.GRAY.lightened(0.3) if used else UiKit.APRICOT.lightened(0.2))
			_canvas.draw_rect(r, UiKit.INK, false, 2.0)
			if not used:
				_canvas.draw_string(font, r.position + Vector2(0, 46), String(letters[k]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, UiKit.INK)
		for k in letters.size():
			var r := _tile_rect(k, 1)
			_canvas.draw_rect(r, Color.WHITE)
			_canvas.draw_rect(r, UiKit.INK, false, 2.0)
			if k < _answer.size():
				_canvas.draw_string(font, r.position + Vector2(0, 46), String(letters[_answer[k]]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, UiKit.INK)
		var c := _clear_rect()
		_canvas.draw_rect(c, UiKit.PAPER)
		_canvas.draw_rect(c, UiKit.INK, false, 2.0)
		_canvas.draw_string(font, c.position + Vector2(0, 36), t("ui.factory.clear"), HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 22, UiKit.INK)
		if bool(g.cfg.get("skip", false)):
			var s := _skip_rect()
			_canvas.draw_rect(s, UiKit.SKY)
			_canvas.draw_rect(s, UiKit.INK, false, 2.0)
			_canvas.draw_string(font, s.position + Vector2(0, 36), "SKIP", HORIZONTAL_ALIGNMENT_CENTER, s.size.x, 24, UiKit.INK)
	if bool(g.cfg.get("trash", false)):
		var tr := _trash_rect()
		_canvas.draw_rect(tr, Color("9aa3a8"))
		_canvas.draw_rect(tr, UiKit.INK, false, 2.0)
		_canvas.draw_string(font, tr.position + Vector2(0, 38), t("ui.factory.trash"), HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 20, Color.WHITE)
	if not g.outbox.is_empty():
		_canvas.draw_string(font, Vector2(a + _aw * 0.12, BELT_TOP - 30), t("ui.factory.waiting").format({"n": g.outbox.size()}), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiKit.INK)


func _draw_shelf(font: Font) -> void:
	for n in g.stack.size():
		var i: int = g.stack[n]
		if not _drag.is_empty() and _drag["kind"] == "card" and _drag["i"] == i and _drag["moved"]:
			continue
		var r := _card_rect(n)
		_canvas.draw_rect(r, UiKit.PAPER)
		_canvas.draw_rect(r, UiKit.INK, false, 2.0)
		_canvas.draw_string(font, r.position + Vector2(0, 30), String(g.board[i]["id"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, UiKit.INK)
	for k in g.slots.size():
		var r := _slot_rect(k)
		var lit := _flash.has("shelf%d" % k)
		_canvas.draw_rect(r, UiKit.LEAF if lit else Color("d9c3a0"))
		_canvas.draw_rect(r, UiKit.INK, false, 2.0)
		var i: int = g.slots[k]
		if i >= 0:
			_canvas.draw_multiline_string(font, r.position + Vector2(6, 30), String(g.board[i]["meaning"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12, 18, 7, UiKit.INK)


# ----- 단어찾기 -----

func _build_search() -> void:
	_search_box = UiKit.card(UiKit.PAPER)
	_search_box.z_index = 25
	_search_box.visible = false
	_search_box.anchor_right = 1.0
	_search_box.anchor_bottom = 1.0
	_search_box.offset_top = 6
	_search_box.offset_left = 10
	_search_box.offset_right = -10
	_search_box.offset_bottom = -6
	_search_box.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_child(_search_box)
	var v := UiKit.vbox(6)
	_search_box.add_child(v)
	_search_time = UiKit.label("", 22, UiKit.ACCENT.darkened(0.3))
	v.add_child(_search_time)
	_search_canvas = Control.new()
	_search_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_search_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_search_canvas.draw.connect(_draw_search)
	_search_canvas.gui_input.connect(_on_search_input)
	v.add_child(_search_canvas)


func _open_search() -> void:
	if g.open_search():
		_search_sel = {}
		_say(t("ui.factory.search_go"))
		changed()


func _grid_geom() -> Dictionary:
	var n := g.search.size
	var oy := BOARD_TOP_S + BOARD_H + 16
	var cell := minf(50.0, minf((_search_canvas.size.x - 20) / n, (_search_canvas.size.y - oy - 10) / n))
	return {"o": Vector2((_search_canvas.size.x - cell * n) / 2.0, oy), "cell": cell, "n": n}


func _cell_at(p: Vector2) -> Vector2i:
	var gm := _grid_geom()
	var q: Vector2 = (p - gm["o"]) / float(gm["cell"])
	var c := Vector2i(int(floor(q.y)), int(floor(q.x)))
	if c.x < 0 or c.y < 0 or c.x >= int(gm["n"]) or c.y >= int(gm["n"]):
		return Vector2i(-1, -1)
	return c


func _on_search_input(ev: InputEvent) -> void:
	if g.search == null:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		var c := _cell_at(ev.position)
		if ev.pressed and c.x >= 0:
			_search_sel = {"a": c, "b": c}
		elif not ev.pressed and not _search_sel.is_empty():
			var i := g.search_select(_search_sel["a"], _search_sel["b"])
			_search_sel = {}
			if i >= 0:
				_say(t("ui.factory.found").format({"word": g.board[i]["id"], "meaning": g.board[i]["meaning"]}))
				GameData.vibrate(true)
			changed()
	elif ev is InputEventMouseMotion and not _search_sel.is_empty():
		var c := _cell_at(ev.position)
		if c.x >= 0:
			_search_sel["b"] = c


func _draw_search() -> void:
	if g.search == null:
		return
	var font := ThemeDB.fallback_font
	var gm := _grid_geom()
	var o: Vector2 = gm["o"]
	var cell: float = gm["cell"]
	var n: int = gm["n"]
	# 남은 시간 막대
	var full := float(g.cfg.get("search_sec", 15)) * g.search.placed.size()
	var w := _search_canvas.size.x - 20
	_search_canvas.draw_rect(Rect2(10, 4, w, 14), UiKit.GRAY.lightened(0.3))
	_search_canvas.draw_rect(Rect2(10, 4, w * clampf(g.search_left / maxf(1.0, full), 0, 1), 14), UiKit.ACCENT)
	var found_cells := {}
	for id in g.search.found:
		for c in g.search.cells_of(id):
			found_cells[c] = true
	var sel := {}
	if not _search_sel.is_empty():
		var a: Vector2i = _search_sel["a"]
		var b: Vector2i = _search_sel["b"]
		var d := b - a
		var len := maxi(absi(d.x), absi(d.y))
		if d.x == 0 or d.y == 0 or absi(d.x) == absi(d.y):
			var st := Vector2i(signi(d.x), signi(d.y))
			for k in len + 1:
				sel[a + st * k] = true
	for r in n:
		for c in n:
			var p := Vector2i(r, c)
			var rect := Rect2(o + Vector2(c, r) * cell, Vector2(cell, cell))
			var bg := UiKit.LEAF if found_cells.has(p) else (UiKit.ACCENT.lightened(0.5) if sel.has(p) else Color.WHITE)
			_search_canvas.draw_rect(rect, bg)
			_search_canvas.draw_rect(rect, UiKit.GRAY, false, 1.0)
			_search_canvas.draw_string(font, rect.position + Vector2(0, cell * 0.72), String(g.search.grid[r][c]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, cell, int(cell * 0.6), UiKit.INK)
	# 칠판(위)은 다른 영역 칠판과 같은 크기, 글자판은 그 아래
	var note := t("ui.factory.reverse_note") if bool(g.cfg.get("search_reverse", false)) else ""
	_draw_board(Rect2(10, BOARD_TOP_S, _search_canvas.size.x - 20, BOARD_H), font, _search_canvas, g.search_words.duplicate(), note)
