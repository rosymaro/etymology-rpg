class_name OrderView
extends MinigameScreen
## 1 주문 제작: 네모 고리 벨트 위 깨진 단어 조각을 눌러 캐릭터가 집게 하고, 용광로를 눌러 넣고, 모루를 눌러 두드린다.
## 완성 단어를 들고 진열장의 맞는 뜻 칸을 누르면 올린다. 벨트 왼쪽은 창고 벽에 가려 보이지 않는다.

const FRAG := Vector2(116, 44)
const JAG := 6  ## 깨진 면의 톱니 수

var _canvas: Control
var _msg: Label


func build() -> void:
	_canvas = Control.new()
	_canvas.anchor_right = 1.0
	_canvas.anchor_bottom = 1.0
	_canvas.offset_left = 16
	_canvas.offset_right = -16
	_canvas.offset_bottom = -10
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.clip_contents = true
	_canvas.draw.connect(_draw_shop)
	_canvas.gui_input.connect(_on_canvas_input)
	body.add_child(_canvas)
	_msg = UiKit.wrap(UiKit.label("", 22, UiKit.INK), 700)
	_msg.position = Vector2(260, 2)
	body.add_child(_msg)


func _px(p: Vector2) -> Vector2:
	return p * _canvas.size


func _furnace_rect() -> Rect2:
	return Rect2(_px(OrderGame.FURNACE) - Vector2(80, 50), Vector2(160, 100))


func _anvil_rect() -> Rect2:
	return Rect2(_px(OrderGame.ANVIL) - Vector2(80, 34), Vector2(160, 68))


func _slot_rect(k: int) -> Rect2:
	return Rect2(_px((game as OrderGame).shelf_pos(k)) - Vector2(130, 36), Vector2(260, 72))


func _on_canvas_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var g := game as OrderGame
	for i in range(g.items.size() - 1, -1, -1):
		var it: Dictionary = g.items[i]
		if g.visible(it) and Rect2(_px(g.belt_pos(it["d"])) - FRAG / 2, FRAG).grow(6).has_point(ev.position):
			g.go_pick(it["uid"])
			return
	if _furnace_rect().has_point(ev.position):
		g.go_furnace()
	elif _anvil_rect().has_point(ev.position):
		g.go_hammer()
	else:
		for k in g.shelf.size():
			if _slot_rect(k).has_point(ev.position):
				g.go_shelf(k)
				return


func tick(_d: float) -> void:
	var g := game as OrderGame
	for e in g.events:
		match e["kind"]:
			"full":
				_msg.text = t("ui.mini.order.full")
			"hammer":
				_msg.text = t("ui.mini.order.made").format({"word": g.words[e["w"]].id}) if e["ok"] else t("ui.mini.order.broke")
				GameData.vibrate(e["ok"])
			"shelf":
				var w := g.words[e["w"]]
				_msg.text = t("ui.mini.order.sold").format({"word": w.id, "meaning": w.meaning}) if e["ok"] \
					else t("ui.mini.order.wrong").format({"word": w.id, "meaning": w.meaning})
				GameData.vibrate(e["ok"])
	if not g.events.is_empty():
		g.events.clear()
		changed()
	_canvas.queue_redraw()


## 단어마다 다른 색(같은 단어 조각은 같은 색). 순번에 황금비를 곱해 이웃 단어끼리 색이 멀어지게 한다.
static func tint(w: int) -> Color:
	return Color.from_hsv(fposmod(w * 0.618034 + 0.08, 1.0), 0.42, 0.97)


## 조각 경계 b(0 = 첫 조각 왼쪽 끝 …)의 톱니. 이웃 조각이 같은 값을 써서 맞물린다.
func _jag(word_id: String, b: int, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in JAG + 1:
		if b == 0 or b == n:
			out.append(0.0)  # 바깥쪽 끝은 곧다
		else:
			# 지그재그(번갈아 튀어나옴) + 단어마다 다른 깊이: 깨진 면처럼 보이고 이웃 조각과 맞물린다
			var h := absi(hash("%s#%d#%d" % [word_id, b, k]))
			var depth := 6.0 + float(h % 7)
			out.append(depth if k % 2 == 0 else -depth)
	return out


func _frag_poly(c: Vector2, word_id: String, p: int, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var hw := FRAG.x / 2
	var hh := FRAG.y / 2
	var left := _jag(word_id, p, n)
	var right := _jag(word_id, p + 1, n)
	for k in JAG + 1:  # 오른쪽 면 위→아래
		pts.append(c + Vector2(hw + right[k], -hh + FRAG.y * k / JAG))
	for k in range(JAG, -1, -1):  # 왼쪽 면 아래→위
		pts.append(c + Vector2(-hw + left[k], -hh + FRAG.y * k / JAG))
	return pts


func _draw_frag(c: Vector2, g: OrderGame, w: int, p: int) -> void:
	var font := ThemeDB.fallback_font
	var id := g.words[w].id
	var pts := _frag_poly(c, id, p, g.pieces(w))
	_canvas.draw_colored_polygon(pts, tint(w))
	var closed := pts.duplicate()
	closed.append(pts[0])
	_canvas.draw_polyline(closed, UiKit.INK, 2.5)
	_canvas.draw_string(font, c + Vector2(-FRAG.x / 2, 8), g.piece_text(w, p), HORIZONTAL_ALIGNMENT_CENTER, FRAG.x, 22, UiKit.INK)


func _draw_shop() -> void:
	var g := game as OrderGame
	var font := ThemeDB.fallback_font
	var S := _canvas.size
	_canvas.draw_style_box(UiKit.box(Color("efe1c8"), 20, 3), Rect2(Vector2.ZERO, S))
	# 벨트 고리
	var br := Rect2(_px(OrderGame.BELT.position), OrderGame.BELT.size * S)
	_canvas.draw_style_box(UiKit.box(Color(0, 0, 0, 0), 30, 0), br)
	var belt := StyleBoxFlat.new()
	belt.bg_color = Color(0, 0, 0, 0)
	belt.border_color = Color("8d8496")
	belt.set_border_width_all(52)
	belt.set_corner_radius_all(40)
	_canvas.draw_style_box(belt, br.grow(26))
	var phase := fmod(Time.get_ticks_msec() / 1000.0 * float(g.cfg["belt_speed"]), 0.08)
	var k := 0.0
	while k < g.perimeter():  # 벨트 눈금이 함께 돈다
		var p := _px(g.belt_pos(k + phase))
		_canvas.draw_circle(p, 3, Color("b8b0c2"))
		k += 0.08
	# 조각
	for it in g.items:
		_draw_frag(_px(g.belt_pos(it["d"])), g, it["w"], it["piece"])
	# 창고 벽(왼쪽을 가린다)
	var wall := Rect2(Vector2(-20, br.position.y - 60), Vector2(OrderGame.HIDE_X * S.x + 20, br.size.y + 120))
	_canvas.draw_style_box(UiKit.box(Color("a98a6a"), 16, 3), wall)
	_canvas.draw_string(font, wall.position + Vector2(0, wall.size.y / 2), t("ui.mini.order.store"), HORIZONTAL_ALIGNMENT_CENTER, wall.size.x, 24, Color.WHITE)
	# 용광로와 모루
	var fr := _furnace_rect()
	if not Art.draw(_canvas, "mini", "furnace", fr.get_center(), fr.size):
		_canvas.draw_style_box(UiKit.box(Color("e8875a"), 22, 3), fr)
	_canvas.draw_string(font, fr.position + Vector2(0, 24), t("ui.mini.order.furnace"), HORIZONTAL_ALIGNMENT_CENTER, fr.size.x, 20, UiKit.INK)
	var chips := ""
	for f in g.furnace:
		chips += "[%s] " % g.piece_text(f["w"], f["piece"])
	_canvas.draw_string(font, fr.position + Vector2(6, 64), chips, HORIZONTAL_ALIGNMENT_CENTER, fr.size.x - 12, 18, UiKit.INK)
	var ar := _anvil_rect()
	if not Art.draw(_canvas, "mini", "anvil", ar.get_center(), ar.size):
		_canvas.draw_style_box(UiKit.box(Color("9aa3ad"), 16, 3), ar)
	_canvas.draw_string(font, ar.position + Vector2(0, 42), t("ui.mini.order.hammer"), HORIZONTAL_ALIGNMENT_CENTER, ar.size.x, 22, UiKit.INK)
	# 진열장(주문 뜻)
	_canvas.draw_string(font, Vector2(20, _px(Vector2(0, OrderGame.SHELF_Y)).y - 46), t("ui.mini.order.shelf"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiKit.INK)
	for s in g.shelf.size():
		var r := _slot_rect(s)
		_canvas.draw_style_box(UiKit.box(Color("fbf3e0") if g.shelf[s] >= 0 else UiKit.GRAY.lightened(0.3), 14, 3), r)
		var text: String = g.words[g.shelf[s]].meaning if g.shelf[s] >= 0 else t("ui.mini.order.done")
		_canvas.draw_string(font, r.position + Vector2(8, 44), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16, 20, UiKit.INK)
	# 캐릭터와 든 것
	var h := _px(g.hero)
	if not Art.draw(_canvas, "mini", "order_hero", h, Vector2(64, 64)):
		_canvas.draw_circle(h, 24, UiKit.ACCENT)
		_canvas.draw_circle(h + Vector2(-8, -5), 3, UiKit.INK)
		_canvas.draw_circle(h + Vector2(8, -5), 3, UiKit.INK)
	if g.carry.has("piece"):
		_draw_frag(h + Vector2(0, -52), g, g.carry["w"], g.carry["piece"])
	elif g.carry.has("word"):
		var wr := Rect2(h + Vector2(-80, -76), Vector2(160, 44))
		_canvas.draw_style_box(UiKit.box(Color("ffe9a8"), 16, 3), wr)
		_canvas.draw_string(font, wr.position + Vector2(0, 30), "★ " + g.words[g.carry["word"]].id, HORIZONTAL_ALIGNMENT_CENTER, wr.size.x, 22, UiKit.INK)
	_canvas.draw_string(font, Vector2(S.x - 300, S.y - 10), t("ui.mini.guard.miss").format({"miss": g.misses, "max": int(g.cfg["max_miss"])}),
		HORIZONTAL_ALIGNMENT_RIGHT, 290, 20, UiKit.INK)
