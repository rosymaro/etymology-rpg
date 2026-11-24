class_name RootJoyScreen
extends Screen
## 새 어근을 익힌 유닛이 나와서 기뻐한다(전투 '결과 보기' 뒤, 결과 화면 전에). 유닛마다 한 화면씩 차례로.
## args: unit(번호), roots(새로 익힌 어근들), done(다음으로)

var _fig: JoyFigure


func open(args: Dictionary) -> void:
	var unit: int = args["unit"]
	var roots: Array = args["roots"]
	UiKit.fill_bg(self, Color("fff4dc"))
	var v := UiKit.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	_fig = JoyFigure.new()
	_fig.unit = unit
	_fig.custom_minimum_size = Vector2(320, 300)
	_fig.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_fig)
	var title := UiKit.label(t("ui.joy.title").format({"name": UiKit.unit_name(unit)}), 34, UiKit.ACCENT.darkened(0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	for r in roots:
		var l := UiKit.label(GameText.root_desc(String(r)), 22)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 640
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(l)
	var hint := UiKit.label(t("ui.joy.hint"), 20, UiKit.INK.lightened(0.25))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var done: Callable = args["done"]
	var b := UiKit.button(t("ui.battle.next"), func() -> void: done.call(), UiKit.LEAF, 26)
	b.custom_minimum_size = Vector2(220, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(b)
	UiKit.thumb(b)  # 엄지 자리
	GameData.vibrate()


## 기뻐하는 유닛: 통통 뛰며 두 팔을 흔들고, 둘레에 반짝이가 돈다(그림이 있으면 그림을 쓴다).
class JoyFigure extends Control:
	const COLORS := ["cfe9c4", "cfe8f3", "f6d3dc", "f8d9c0", "e3d5f5", "fbe7a6"]
	var unit := 1
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var hop := absf(sin(_t * 6.0)) * 34.0  # 통통 뛴다
		var body := c + Vector2(0, 40 - hop)
		# 바닥 그림자(뛰면 작아진다)
		draw_set_transform(c + Vector2(0, 130), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, 70.0 - hop * 0.6, Color(0, 0, 0, 0.12))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 반짝이
		for k in 8:
			var a := _t * 1.6 + k * TAU / 8.0
			var p := c + Vector2(cos(a), sin(a)) * Vector2(150, 120)
			_star(p, 10.0 + 5.0 * sin(_t * 5.0 + k), Color(UiKit.ACCENT, 0.85) if k % 2 == 0 else Color("f5c542"))
		if Art.draw(self, "unit", "u%02d" % unit, body, Vector2(180, 180)):
			return
		var col := Color(COLORS[(unit - 1) % COLORS.size()])
		var ink := UiKit.INK
		# 팔(위로 흔든다)
		var wave := sin(_t * 10.0) * 0.35
		for sgn in [-1.0, 1.0]:
			var sh := body + Vector2(sgn * 52, 10)
			var hand := sh + Vector2(sgn * 40, -62).rotated(sgn * wave)
			draw_line(sh, hand, ink, 7.0, true)
			draw_circle(hand, 9.0, col)
		# 몸과 얼굴
		draw_circle(body, 64.0, col)
		draw_arc(body, 64.0, 0.0, TAU, 48, ink, 4.0, true)
		# 웃는 눈(^ ^)
		for sgn in [-1.0, 1.0]:
			var e := body + Vector2(sgn * 22, -12)
			draw_polyline(PackedVector2Array([e + Vector2(-10, 5), e + Vector2(0, -5), e + Vector2(10, 5)]), ink, 4.0, true)
		# 볼과 웃는 입
		for sgn in [-1.0, 1.0]:
			draw_circle(body + Vector2(sgn * 38, 10), 8.0, Color(UiKit.BAD, 0.35))
		draw_arc(body + Vector2(0, 8), 22.0, 0.2, PI - 0.2, 16, ink, 4.0, true)

	func _star(p: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 8:
			var a := i * TAU / 8.0 - PI / 2.0
			pts.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.4))
		draw_colored_polygon(pts, col)
