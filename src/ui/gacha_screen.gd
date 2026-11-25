class_name GachaScreen
extends Screen
## 말 뽑기(07-fun.md 7절): 코인을 넣고 손잡이를 돌리면 캡슐이 떨어지고, 열리면 단어 카드가 뱅그르르 나온다.
## 규칙은 Gacha. 처음 보는 단어면 '새 단어!'와 풀이(06-learning)를 함께 보여 준다.

var _gacha: Gacha
var _coins: Label
var _result: HFlowContainer
var _info: Label
var _btns: Array[Button] = []
var _busy := false
var last: Array[Dictionary] = []  ## 마지막에 뽑은 것(테스트용)


func open(_args: Dictionary) -> void:
	_gacha = Gacha.new(GameData.repo, GameData.rules, JsonFile.read("res://data/balance/gacha.json"))
	UiKit.fill_bg(self, Color("fde9f0"))
	var v := UiKit.vbox(14)
	v.position = Vector2(24, 24)
	v.custom_minimum_size.x = 672
	add_child(v)
	var head := UiKit.hbox()
	var title := UiKit.label(t("ui.gacha.title"), 32, UiKit.ACCENT.darkened(0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_coins = UiKit.label("", 26)
	head.add_child(_coins)
	v.add_child(head)
	var how := UiKit.wrap(UiKit.label(t("ui.gacha.how"), 20, UiKit.INK.lightened(0.2)), 660)
	v.add_child(how)
	var machine := Machine.new()
	machine.custom_minimum_size = Vector2(672, 300)
	machine.name = "Machine"
	v.add_child(machine)
	_result = HFlowContainer.new()
	_result.add_theme_constant_override("h_separation", 8)
	_result.add_theme_constant_override("v_separation", 8)
	_result.alignment = FlowContainer.ALIGNMENT_CENTER
	v.add_child(_result)
	_info = UiKit.wrap(UiKit.label("", 22, UiKit.INK), 660)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_info)
	var row := UiKit.hbox(12)
	add_child(row)
	var cfg: Dictionary = JsonFile.read("res://data/balance/gacha.json")
	for n in [1, 10]:
		var k: int = n
		var price := int(cfg["price10"]) if k >= 10 else int(cfg["price"])
		var b := UiKit.button(t("ui.gacha.pull").format({"n": k, "price": price}), func() -> void: pull(k), UiKit.ACCENT.lightened(0.35), 24)
		b.custom_minimum_size = Vector2(220, UiKit.THUMB_H)
		row.add_child(b)
		_btns.append(b)
	var back := UiKit.button(t("ui.common.back"), func() -> void: main.flow.go_field(), UiKit.PAPER, 24)
	back.custom_minimum_size = Vector2(160, UiKit.THUMB_H)
	row.add_child(back)
	UiKit.thumb(row)  # 엄지 자리
	_refresh()
	(func() -> void:
		await get_tree().process_frame
		TutorialOverlay.run(self, "gacha", [{"target": _coins, "text": "tut.gacha.coins", "mode": "any"},
			{"target": _btns[0], "text": "tut.gacha.pull", "mode": "any"}] as Array[Dictionary])).call()


func _refresh() -> void:
	_coins.text = t("ui.gacha.coins").format({"n": GameData.state.wallet})


## n번 뽑기(버튼·테스트). 코인이 모자라면 알린다.
func pull(n: int) -> void:
	if _busy:
		return
	var got := _gacha.pull(GameData.state, n, GameData.rng)
	if got.is_empty():
		_info.text = t("ui.gacha.no_coins")
		return
	last = got
	GameData.save()
	_busy = true
	_refresh()
	for c in _result.get_children():
		c.queue_free()
	var m: Machine = find_child("Machine", true, false)
	m.spin()
	GameData.vibrate()
	await get_tree().create_timer(0.7).timeout
	var news: Array[String] = []
	for g in got:
		var w := GameData.repo.get_word(g["id"])
		var card := WordCard.make(w, t("ui.gacha.new") if g["new"] else ("★" if g["rare"] else ""), 20)
		card.pivot_offset = Vector2(60, 30)
		card.scale = Vector2(0.2, 0.2)
		card.rotation_degrees = -360.0
		_result.add_child(card)
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.45)
		tw.tween_property(card, "rotation_degrees", 0.0, 0.45)
		if g["new"]:
			news.append("%s = %s" % [w.id, w.meaning])
		await get_tree().create_timer(0.12 if n > 1 else 0.3).timeout
	if n == 1:
		var w := GameData.repo.get_word(got[0]["id"])
		var parts := PieceSplit.split(w.id, w.etym)
		var q := InferenceQuestion.new()
		q.parts = parts
		_info.text = (t("ui.gacha.new_word") + "  " if got[0]["new"] else "") + (q.explain(w.meaning) if parts.size() > 1 else "%s = %s" % [w.id, w.meaning])
	else:
		_info.text = t("ui.gacha.news").format({"n": news.size()})
	_busy = false


## 뽑기 기계: 둥근 유리통 안에 캡슐들, 손잡이. spin()하면 캡슐이 흔들리고 하나가 떨어진다.
class Machine extends Control:
	var _t := 0.0
	var _spin := 0.0

	func spin() -> void:
		_spin = 0.7

	func _process(delta: float) -> void:
		_t += delta
		_spin = maxf(0.0, _spin - delta)
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x / 2, 120)
		draw_rect(Rect2(c + Vector2(-90, 80), Vector2(180, 100)), Color("e9876a"))
		draw_rect(Rect2(c + Vector2(-90, 80), Vector2(180, 100)), UiKit.INK, false, 4)
		draw_circle(c, 100, Color(0.85, 0.95, 1.0, 0.8))
		var cols := [Color("f6d3dc"), Color("cfe9c4"), Color("fbe7a6"), Color("cfe8f3"), Color("e3d5f5")]
		for k in 14:
			var a := k * 2.4 + (_t * 6.0 if _spin > 0.0 else 0.0)
			var p := c + Vector2(cos(a), sin(a) * 0.6 + 0.3) * (30 + (k % 4) * 15)
			draw_circle(p, 16, cols[k % cols.size()])
			draw_arc(p, 16, 0, TAU, 16, UiKit.INK, 2)
		draw_arc(c, 100, 0, TAU, 48, UiKit.INK, 4)
		var h := c + Vector2(0, 130)
		draw_circle(h, 26, Color("fff4dc"))
		var ang := _spin * 12.0
		draw_line(h, h + Vector2.from_angle(ang) * 22, UiKit.INK, 6)
		if _spin > 0.0:  # 떨어지는 캡슐
			var y := lerpf(150, 175, 1.0 - _spin / 0.7)
			draw_circle(c + Vector2(60, y), 14, Color("f5c542"))
