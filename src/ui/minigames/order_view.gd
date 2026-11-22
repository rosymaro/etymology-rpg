class_name OrderView
extends MinigameScreen
## 1 주문 제작: 주문서(뜻과 속성 무늬, 남은 시간)와 흘러가는 단어 카드.

var _order: Label
var _bar: ProgressBar
var _belt: HBoxContainer
var _miss: Label
var _shown: Array[String] = []


func build() -> void:
	var g := game as OrderGame
	var v := UiKit.vbox(18)
	v.position = Vector2(40, 10)
	v.custom_minimum_size = Vector2(1200, 0)
	body.add_child(v)
	var card := UiKit.card(UiKit.APRICOT.lightened(0.3))
	var cv := UiKit.vbox(6)
	card.add_child(cv)
	cv.add_child(UiKit.label(t("ui.mini.order.ticket"), 20))
	_order = UiKit.label("", 34)
	cv.add_child(_order)
	_bar = ProgressBar.new()
	_bar.max_value = float(g.cfg["order_time"])
	_bar.custom_minimum_size = Vector2(600, 22)
	_bar.show_percentage = false
	cv.add_child(_bar)
	v.add_child(card)
	v.add_child(UiKit.label(t("ui.mini.order.belt"), 22))
	_belt = UiKit.hbox(14)
	v.add_child(_belt)
	_miss = UiKit.label("", 22, UiKit.BAD.darkened(0.2))
	v.add_child(_miss)


func refresh() -> void:
	var g := game as OrderGame
	var cur := g.current_word()
	if cur != "":
		var w := word(cur)
		_order.text = "%s   [%s]" % [w.meaning, t("name.attr.%02d" % w.primary_attr())]
	_miss.text = t("ui.mini.order.miss").format({"n": g.misses, "max": int(g.cfg["max_miss"])})
	if _shown != g.belt:
		_shown = g.belt.duplicate()
		for c in _belt.get_children():
			c.queue_free()
		for i in g.belt.size():
			var idx := i
			var w := word(g.belt[i])
			var b := UiKit.button(w.id, func() -> void:
				if not g.pick(idx):
					GameData.vibrate()
				changed(), MinigameScreen.attr_color(w.primary_attr()), 26)
			b.custom_minimum_size = Vector2(270, 120)
			_belt.add_child(b)


func tick(_d: float) -> void:
	_bar.value = (game as OrderGame).order_left
	refresh()
