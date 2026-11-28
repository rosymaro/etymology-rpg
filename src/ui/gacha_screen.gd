class_name GachaScreen
extends Screen
## 말 뽑기(07-fun.md 7절): 코인을 넣고 손잡이를 돌리면 캡슐이 떨어지고, 열리면 단어 카드가 뱅그르르 나온다.
## 규칙은 Gacha. 처음 보는 단어면 '새 단어!'와 풀이(06-learning)를 함께 보여 준다.

var _gacha: Gacha
var _coins: Label
var _result: HFlowContainer
var _info: Label
var _info_card: PanelContainer
var _btns: Array[Button] = []
var _free_btn: Button  ## 무료 뽑기(사냥 레벨 5마다 받는다)
var _busy := false
var last: Array[Dictionary] = []  ## 마지막에 뽑은 것(테스트용)


var overlay := false  ## 필드 위에 투명하게 겹쳐 연다(사용자 의견: 배경 없이)


func open(args: Dictionary) -> void:
	_gacha = Gacha.new(GameData.repo, GameData.rules, JsonFile.read("res://data/balance/gacha.json"))
	overlay = bool(args.get("overlay", false))
	if overlay:
		mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤의 필드는 보이기만 한다
	else:
		UiKit.fill_bg(self, Color("fde9f0"))
	var v := UiKit.vbox(14)
	v.position = Vector2(24, 24)
	v.custom_minimum_size.x = 672
	add_child(v)
	var top := UiKit.card(Color(UiKit.PAPER, 0.94))  # 글씨는 크림 카드 위에(배경이 비쳐도 읽히게)
	v.add_child(top)
	var tv := UiKit.vbox(6)
	top.add_child(tv)
	var head := UiKit.hbox()
	var title := UiKit.label(t("ui.gacha.title"), 32, UiKit.ACCENT.darkened(0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_coins = UiKit.label("", 26)
	head.add_child(_coins)
	tv.add_child(head)
	var how := UiKit.wrap(UiKit.label(t("ui.gacha.how"), 20, UiKit.INK.lightened(0.2)), 620)
	tv.add_child(how)
	var machine := Machine.new()
	machine.custom_minimum_size = Vector2(672, 430)
	machine.name = "Machine"
	v.add_child(machine)
	_result = HFlowContainer.new()
	_result.add_theme_constant_override("h_separation", 8)
	_result.add_theme_constant_override("v_separation", 8)
	_result.alignment = FlowContainer.ALIGNMENT_CENTER
	v.add_child(_result)
	_info_card = UiKit.card(Color(UiKit.PAPER, 0.94))
	_info_card.visible = false
	v.add_child(_info_card)
	_info = UiKit.wrap(UiKit.label("", 22, UiKit.INK), 620)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_card.add_child(_info)
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
	_free_btn = UiKit.button("", func() -> void: pull(GameData.state.free_pulls, true), UiKit.LEAF, 24)
	_free_btn.custom_minimum_size = Vector2(0, UiKit.THUMB_H)
	v.add_child(_free_btn)
	var back := UiKit.button(t("ui.common.back"), _close, UiKit.PAPER, 24)
	back.custom_minimum_size = Vector2(160, UiKit.THUMB_H)
	row.add_child(back)
	UiKit.thumb(row)  # 엄지 자리
	_refresh()
	(func() -> void:
		await get_tree().process_frame
		TutorialOverlay.run(self, "gacha", [{"target": _coins, "text": "tut.gacha.coins", "mode": "any"},
			{"target": _btns[0], "text": "tut.gacha.pull", "mode": "any"}] as Array[Dictionary])).call()


func _close() -> void:
	if overlay:
		GameData.set_route({"s": "field"})
		queue_free()  # 필드가 그대로 이어진다
	else:
		main.flow.go_field()


func _set_info(text: String) -> void:
	_info.text = text
	_info_card.visible = text != ""


func _refresh() -> void:
	_coins.text = t("ui.gacha.coins").format({"n": GameData.state.wallet})
	_free_btn.visible = GameData.state.free_pulls > 0
	_free_btn.text = t("ui.gacha.free").format({"n": GameData.state.free_pulls})


## n번 뽑기(버튼·테스트). 코인이 모자라면 알린다.
func pull(n: int, free := false) -> void:
	if _busy:
		return
	var got := _gacha.pull_free(GameData.state, n, GameData.rng) if free else _gacha.pull(GameData.state, n, GameData.rng)
	if got.is_empty():
		_set_info(t("ui.gacha.no_coins"))
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
		var notes := GameText.etym_notes(parts, w.etym)
		_set_info((t("ui.gacha.new_word") + "  " if got[0]["new"] else "") + (q.explain(w.meaning) if parts.size() > 1 else "%s = %s" % [w.id, w.meaning]) + ("\n" + notes if notes != "" else ""))
	else:
		_set_info(t("ui.gacha.news").format({"n": news.size()}))
	_busy = false


## 뽑기 기계(사용자 의견: 톤앤매너를 지켜 더 곱게, 배경 없이). 크림 테두리·갈색 먹선·파스텔 캡슐.
## 유리통 안에 두 색 캡슐들, 금빛 뚜껑, 산호색 몸통(동전 구멍·손잡이·나오는 곳). spin()하면 캡슐이 흔들리고 손잡이가 돌며 하나가 굴러 나온다.
class Machine extends Control:
	const CAPS := [Color("f6b8c8"), Color("b9e3a8"), Color("ffd98a"), Color("a9d8ee"), Color("d6c4f2"), Color("ffc29e")]
	var _t := 0.0
	var _spin := 0.0

	func spin() -> void:
		_spin = 0.9

	func _process(delta: float) -> void:
		_t += delta
		_spin = maxf(0.0, _spin - delta)
		queue_redraw()

	func _rrect(r: Rect2, col: Color, rad: float, line := 0.0, ink := UiKit.INK) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(int(rad))
		sb.anti_aliasing = true
		if line > 0.0:
			sb.border_color = ink
			sb.set_border_width_all(int(line))
		draw_style_box(sb, r)

	func _capsule(p: Vector2, r: float, col: Color, rot: float) -> void:
		var ink := UiKit.INK
		draw_circle(p, r, Color("fffaf0"))
		var top := PackedVector2Array()
		for k in 17:
			var a := rot + PI + PI * k / 16.0
			top.append(p + Vector2.from_angle(a) * r)
		draw_colored_polygon(top, col)
		draw_line(p + Vector2.from_angle(rot + PI) * r, p + Vector2.from_angle(rot) * r, ink.lightened(0.2), 2.0, true)
		draw_arc(p, r, 0, TAU, 28, ink, 2.5, true)
		draw_circle(p + Vector2.from_angle(rot - PI * 0.7) * r * 0.5, r * 0.22, Color(1, 1, 1, 0.7))

	func _draw() -> void:
		var ink := UiKit.INK
		var c := Vector2(size.x / 2.0, 150)
		var R := 118.0
		var shake := Vector2(sin(_t * 40.0), 0) * 3.0 if _spin > 0.0 else Vector2.ZERO
		# 바닥 그림자
		draw_set_transform(c + Vector2(0, 268), 0.0, Vector2(1.0, 0.2))
		draw_circle(Vector2.ZERO, 150, Color(0.24, 0.14, 0.07, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 몸통(산호) + 크림 앞판
		var body := Rect2(c + Vector2(-118, 96), Vector2(236, 168))
		_rrect(body.grow(4), ink, 26)
		_rrect(body, Color("ef8f74"), 24)
		_rrect(Rect2(body.position + Vector2(0, body.size.y - 30), Vector2(body.size.x, 30)), Color("d9775e"), 18)
		_rrect(Rect2(body.position + Vector2(16, 14), Vector2(body.size.x - 32, 92)), Color("fff1dc"), 16, 3.0)
		# 동전 구멍 + 별
		_rrect(Rect2(c + Vector2(-52, 128), Vector2(10, 34)), ink.lightened(0.1), 5)
		var sp := c + Vector2(-47, 182)
		var star := PackedVector2Array()
		for k in 10:
			star.append(sp + Vector2.from_angle(-PI / 2 + PI * k / 5.0) * (11.0 if k % 2 == 0 else 5.0))
		draw_colored_polygon(star, Color("f5c542"))
		# 손잡이(금빛 원판 + 손잡이 막대)
		var h := c + Vector2(30, 152)
		draw_circle(h, 34, ink)
		draw_circle(h, 31, Color("f8d26a"))
		draw_arc(h, 22, 0, TAU, 32, Color("e0ad3c"), 3, true)
		var ang := -PI / 2 + (1.0 - _spin / 0.9) * TAU * 1.5 if _spin > 0.0 else -PI / 2
		var tip := h + Vector2.from_angle(ang) * 26
		draw_line(h - Vector2.from_angle(ang) * 26, tip, ink, 14, true)
		draw_line(h - Vector2.from_angle(ang) * 24, h + Vector2.from_angle(ang) * 24, Color("fff6e3"), 8, true)
		draw_circle(h, 6, ink)
		# 나오는 곳
		var mouth := Rect2(c + Vector2(-34, 214), Vector2(68, 38))
		_rrect(mouth.grow(3), ink, 14)
		_rrect(mouth, Color("6e4a33"), 12)
		_rrect(Rect2(mouth.position + Vector2(4, 4), Vector2(mouth.size.x - 8, 12)), Color("8a6046"), 6)
		# 목(유리통과 몸통 사이 고리)
		_rrect(Rect2(c + Vector2(-92, 80), Vector2(184, 26)).grow(3), ink, 13)
		_rrect(Rect2(c + Vector2(-92, 80), Vector2(184, 26)), Color("f8d26a"), 12)
		_rrect(Rect2(c + Vector2(-86, 84), Vector2(172, 7)), Color("fff1b8"), 4)
		# 유리통 안 캡슐(아래쪽에 쌓이게)
		draw_circle(c + shake, R + 4, ink)
		draw_circle(c + shake, R, Color(0.86, 0.95, 1.0, 1.0))
		for k in 16:
			var row := k / 5
			var colx := k % 5 - 2.0 + (0.5 if row % 2 == 1 else 0.0)
			var p := c + shake + Vector2(colx * 40.0, 70.0 - row * 34.0)
			if _spin > 0.0:
				p += Vector2(sin(_t * 18.0 + k), cos(_t * 15.0 + k * 1.7)) * 9.0
			if p.distance_to(c + shake) > R - 20.0:
				continue
			_capsule(p, 19.0, CAPS[k % CAPS.size()], 0.4 * sin(k * 1.3))
		# 유리 반짝임
		draw_arc(c + shake, R - 14, PI * 1.1, PI * 1.45, 18, Color(1, 1, 1, 0.85), 9, true)
		draw_arc(c + shake, R - 14, PI * 1.55, PI * 1.62, 6, Color(1, 1, 1, 0.85), 9, true)
		draw_circle(c + shake + Vector2(48, -66), 8, Color(1, 1, 1, 0.6))
		draw_arc(c + shake, R, 0, TAU, 64, ink, 4, true)
		# 뚜껑
		var cap := Rect2(c + shake + Vector2(-38, -R - 18), Vector2(76, 30))
		_rrect(cap.grow(3), ink, 14)
		_rrect(cap, Color("ef8f74"), 12)
		draw_circle(c + shake + Vector2(0, -R - 26), 13, ink)
		draw_circle(c + shake + Vector2(0, -R - 26), 10, Color("f8d26a"))
		# 굴러 나오는 캡슐
		if _spin > 0.0:
			var k2 := 1.0 - _spin / 0.9
			var p2 := mouth.get_center() + Vector2(lerpf(0, 90, k2), lerpf(-4, 30, minf(1.0, k2 * 2.0)))
			_capsule(p2, 16.0, Color("ffd98a"), k2 * 8.0)
