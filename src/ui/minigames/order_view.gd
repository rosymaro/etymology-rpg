class_name OrderView
extends MinigameScreen
## 1 주문 제작: 위는 주문서(뜻, 속성 무늬, 남은 시간), 아래는 왼쪽에서 오른쪽으로 흐르는 컨베이어 벨트.
## 벨트의 줄무늬와 롤러가 같이 돌고 카드가 실제로 미끄러져 가서, 흐르는 방향이 보인다. 카드를 누르면 집는다.

const BELT_H := 200.0
const CARD := Vector2(230, 130)

var _order: Label
var _bar: ProgressBar
var _miss: Label
var _belt: Control
var _scroll := 0.0
var _flash := {}  ## 카드 id -> 남은 깜빡임 시간(틀렸을 때 빨강)


func build() -> void:
	var g := game as OrderGame
	var top := UiKit.hbox(20)
	top.position = Vector2(40, 6)
	body.add_child(top)
	var card := UiKit.card(UiKit.APRICOT.lightened(0.3))
	card.custom_minimum_size = Vector2(760, 0)
	var cv := UiKit.vbox(6)
	card.add_child(cv)
	var head := UiKit.hbox(10)
	var ticket := Art.rect("ui", "order_ticket", Vector2(48, 48))
	if ticket:
		head.add_child(ticket)
	head.add_child(UiKit.label(t("ui.mini.order.ticket"), 20))
	cv.add_child(head)
	_order = UiKit.label("", 32)
	cv.add_child(_order)
	_bar = ProgressBar.new()
	_bar.max_value = float(g.cfg["order_time"])
	_bar.custom_minimum_size = Vector2(700, 20)
	_bar.show_percentage = false
	cv.add_child(_bar)
	top.add_child(card)
	_miss = UiKit.label("", 24, UiKit.BAD.darkened(0.2))
	top.add_child(_miss)
	var hint := UiKit.label(t("ui.mini.order.belt"), 22)
	hint.position = Vector2(40, 200)
	body.add_child(hint)
	_belt = Control.new()
	_belt.position = Vector2(0, 250)
	_belt.anchor_right = 1.0
	_belt.custom_minimum_size = Vector2(0, BELT_H + 60)
	_belt.draw.connect(_draw_belt)
	_belt.gui_input.connect(_belt_input)
	body.add_child(_belt)


func refresh() -> void:
	var g := game as OrderGame
	var cur := g.current_word()
	if cur != "":
		var w := word(cur)
		_order.text = "%s   [%s]" % [w.meaning, t("name.attr.%02d" % w.primary_attr())]
	_miss.text = t("ui.mini.order.miss").format({"n": g.misses, "max": int(g.cfg["max_miss"])})


func tick(delta: float) -> void:
	var g := game as OrderGame
	_bar.value = g.order_left
	_scroll = fposmod(_scroll + float(g.cfg["belt_speed"]) * _belt_len() * delta, 40.0)
	for k in _flash.keys():
		_flash[k] -= delta
		if _flash[k] <= 0.0:
			_flash.erase(k)
	refresh()
	_belt.queue_redraw()


func _belt_len() -> float:
	return maxf(_belt.size.x - 120.0, 400.0)


func _card_rect(x: float) -> Rect2:
	var cx := 60.0 + x * _belt_len()
	return Rect2(Vector2(cx - CARD.x / 2, 30 + (BELT_H - CARD.y) / 2), CARD)


func _belt_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var g := game as OrderGame
	for i in range(g.items.size() - 1, -1, -1):
		if _card_rect(g.items[i]["x"]).has_point(ev.position):
			var id: String = g.items[i]["id"]
			if not g.pick(i):
				_flash[id] = 0.5
				GameData.vibrate()
			changed()
			return


func _draw_belt() -> void:
	var g := game as OrderGame
	var font := ThemeDB.fallback_font
	var w := _belt.size.x
	var top := 30.0
	# 벨트 몸통과 흐르는 줄무늬(왼쪽 → 오른쪽)
	if not Art.draw(_belt, "mini", "order_belt", Vector2(w / 2, top + BELT_H / 2), Vector2(w, BELT_H)):
		_belt.draw_rect(Rect2(Vector2(0, top), Vector2(w, BELT_H)), Color("8d8597"))
		var x := -40.0 + _scroll
		while x < w:
			_belt.draw_line(Vector2(x, top + 6), Vector2(x + 18, top + BELT_H - 6), Color("a69eb0"), 8)
			x += 40.0
	_belt.draw_rect(Rect2(Vector2(0, top), Vector2(w, BELT_H)), UiKit.INK, false, 4)
	# 롤러(돌아가는 점)
	for rx in [30.0, w - 30.0]:
		var c := Vector2(rx, top + BELT_H + 22)
		_belt.draw_circle(c, 18, Color("c9c4cf"))
		_belt.draw_arc(c, 18, 0, TAU, 20, UiKit.INK, 3)
		var ang := _scroll / 40.0 * TAU
		_belt.draw_circle(c + Vector2.from_angle(ang) * 11, 4, UiKit.INK)
	# 흐르는 방향 화살표
	for k in 3:
		var ax := w * (0.3 + 0.2 * k)
		_belt.draw_string(font, Vector2(ax, top + BELT_H + 34), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(UiKit.INK, 0.5))
	# 카드
	for it in g.items:
		var r := _card_rect(it["x"])
		var ww := word(it["id"])
		var col := MinigameScreen.attr_color(ww.primary_attr())
		if _flash.has(it["id"]):
			col = UiKit.BAD
		if not Art.draw(_belt, "mini", "order_card", r.get_center(), r.size, col.lightened(0.3)):
			var sb := UiKit.box(col, 20, 4)
			_belt.draw_style_box(sb, r)
		_belt.draw_string(font, r.position + Vector2(0, r.size.y / 2 + 12), ww.id, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, UiKit.INK)
