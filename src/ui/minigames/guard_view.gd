class_name GuardView
extends MinigameScreen
## 8 보초 서기: 통을 눌러 맨 위 패를 고르고, 옮길 통을 누른다. 같은 무늬(속성)끼리 한 통에 모은다.

var _row: HBoxContainer
var _sel := -1


func build() -> void:
	_row = UiKit.hbox(14)
	_row.position = Vector2(30, 10)
	body.add_child(_row)


func _press(i: int) -> void:
	var g := game as SortGame
	if _sel < 0:
		if not g.tubes[i].is_empty():
			_sel = i
	else:
		if _sel != i and not g.move(_sel, i):
			GameData.vibrate()
		_sel = -1
	changed()


func refresh() -> void:
	var g := game as SortGame
	for c in _row.get_children():
		c.queue_free()
	for i in g.tubes.size():
		var idx := i
		var col := UiKit.vbox(4)
		var tube: Array = g.tubes[i]
		var flag := ""
		if tube.size() == g.per_tube and g.done_colors.has(tube[0]):
			flag = g.words[tube[0]].id
		col.add_child(UiKit.label(flag, 16, UiKit.GOOD.darkened(0.3)))
		for k in range(g.per_tube - 1, -1, -1):
			var txt := ""
			var bg := UiKit.PAPER
			if k < tube.size():
				var a: int = g.color_attr[tube[k]]
				txt = t("name.attr.%02d" % a)
				bg = MinigameScreen.attr_color(a)
			var b := UiKit.button(txt, func() -> void: _press(idx), bg, 20)
			b.custom_minimum_size = Vector2(130, 92)
			if i == _sel and k == tube.size() - 1:
				b.add_theme_stylebox_override("normal", UiKit.box(bg, 30, 7))
			col.add_child(b)
		_row.add_child(col)
