class_name WheelView
extends MinigameScreen
## 7 물레방아: 고리를 펼친 그림. 왼쪽이 바깥 고리(단어), 오른쪽이 안쪽 고리(뜻). 수문 칸에서 둘을 맞춘다.

var _rows: VBoxContainer


func build() -> void:
	var h := UiKit.hbox(20)
	h.position = Vector2(30, 0)
	body.add_child(h)
	var lb := UiKit.vbox(10)
	lb.add_child(UiKit.label(t("ui.mini.wheel.outer"), 20))
	lb.add_child(UiKit.button("▲", func() -> void: _turn(true, -1), UiKit.SKY, 26))
	lb.add_child(UiKit.button("▼", func() -> void: _turn(true, 1), UiKit.SKY, 26))
	h.add_child(lb)
	_rows = UiKit.vbox(6)
	_rows.custom_minimum_size = Vector2(900, 0)
	h.add_child(_rows)
	var rb := UiKit.vbox(10)
	rb.add_child(UiKit.label(t("ui.mini.wheel.inner"), 20))
	rb.add_child(UiKit.button("▲", func() -> void: _turn(false, -1), UiKit.LEAF, 26))
	rb.add_child(UiKit.button("▼", func() -> void: _turn(false, 1), UiKit.LEAF, 26))
	h.add_child(rb)


func _turn(outer: bool, step: int) -> void:
	var g := game as CryptexGame
	var before := g.rounds_done
	if outer:
		g.turn_outer(step)
	else:
		g.turn_inner(step)
	if g.rounds_done > before:
		GameData.vibrate(true)
	changed()


func refresh() -> void:
	var g := game as CryptexGame
	for c in _rows.get_children():
		c.queue_free()
	for p in g.n:
		var gate := p in g.gates
		var ok := gate and g.gate_ok(p)
		var row := UiKit.hbox(10)
		var tag := UiKit.label(t("ui.mini.wheel.gate") if gate else "", 18, UiKit.ACCENT.darkened(0.2))
		tag.custom_minimum_size = Vector2(60, 0)
		row.add_child(tag)
		var a := UiKit.card(UiKit.SKY if not ok else UiKit.GOOD.lightened(0.45))
		a.custom_minimum_size = Vector2(260, 0)
		a.add_child(UiKit.label(g.outer_at(p), 24))
		row.add_child(a)
		var b := UiKit.card(UiKit.LEAF.lightened(0.3) if not ok else UiKit.GOOD.lightened(0.45))
		b.custom_minimum_size = Vector2(560, 0)
		var bl := UiKit.label(g.inner_at(p), 20)
		bl.clip_text = true
		b.add_child(bl)
		row.add_child(b)
		_rows.add_child(row)
