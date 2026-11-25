class_name TutorialOverlay
extends Control
## 튜토리얼 한 묶음(08-tutorial.md 1절): 가리킬 자리만 뚫고 바깥은 반투명한 밝은 회색으로 덮는다.
## 화살표가 그 자리를 가리키고, 말풍선(반투명 바탕 + 밝은 글씨)으로 설명한다.
## 단계 = {target: Control 또는 Callable(-> Rect2 화면 좌표), text: 대사 키, speaker: 인물 id, mode: "tap"(그 자리를 눌러야) | "any"(아무 곳)}
## 다 보거나 건너뛰면 done을 부르고 사라진다.

signal finished

const DIM := Color(0.42, 0.42, 0.46, 0.5)  ## 반투명한 밝은 회색(사용자 의견)
const PAD := 12.0

var steps: Array[Dictionary] = []
var i := 0
var _hole := Rect2()
var _dims: Array[ColorRect] = []
var _bubble: PanelContainer
var _text: Label
var _who: Label
var _t := 0.0
var _armed := 0.0  ## 단계가 바뀐 직후 잠깐은 누름을 받지 않는다(앞 단계 누름이 넘어오지 않게)


func start(list: Array[Dictionary]) -> void:
	steps = list
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60
	for k in 4:
		var d := ColorRect.new()
		d.color = DIM
		d.mouse_filter = Control.MOUSE_FILTER_STOP
		d.gui_input.connect(_on_dim_input)
		add_child(d)
		_dims.append(d)
	_bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.2, 0.26, 0.86)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UiKit.vbox(6)
	_bubble.add_child(v)
	_who = UiKit.label("", 20, Color("fbe07a"))
	v.add_child(_who)
	_text = UiKit.label("", 24, Color.WHITE)  # 반투명 위의 글씨는 밝게
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 600
	v.add_child(_text)
	var hint := UiKit.label(tr("tut.tap_next"), 16, Color(1, 1, 1, 0.7))
	hint.name = "Hint"
	v.add_child(hint)
	add_child(_bubble)
	var skip := UiKit.button(tr("tut.skip"), _finish, UiKit.PAPER, 18)
	skip.z_index = 1
	add_child(skip)
	UiKit.pin(skip, 1, 0, -16, 16)
	_show()


func _rect_of(st: Dictionary) -> Rect2:
	var tg: Variant = st.get("target")
	var r := Rect2()
	if tg is Control and is_instance_valid(tg):
		r = (tg as Control).get_global_rect()
	elif tg is Callable:
		r = (tg as Callable).call()
	elif tg is Rect2:
		r = tg
	r.position -= global_position
	return r.grow(PAD) if r.size != Vector2.ZERO else r


func _show() -> void:
	if i >= steps.size():
		_finish()
		return
	var st := steps[i]
	_hole = _rect_of(st)
	_armed = 0.25
	var sp := String(st.get("speaker", "ttukttak"))
	_who.text = GameData.say("name.char." + sp) if sp != "" else ""
	_text.text = tr(String(st["text"]))
	(_bubble.find_child("Hint", true, false) as Label).text = tr("tut.tap_target") if st.get("mode", "any") == "tap" else tr("tut.tap_next")
	_layout()
	if st.get("mode", "any") == "tap":
		var tg: Variant = st.get("target")
		if tg is BaseButton and not (tg as BaseButton).pressed.is_connected(_next):
			(tg as BaseButton).pressed.connect(_next, CONNECT_ONE_SHOT)


## 뚫린 자리 바깥 네 조각을 덮는다(누름은 바깥에서만 막힌다).
func _layout() -> void:
	var full := Rect2(Vector2(-20, -UiKit.BG_BLEED), size + Vector2(40, UiKit.BG_BLEED * 2))
	var h := _hole if _hole.size != Vector2.ZERO else Rect2(size / 2.0, Vector2.ZERO)
	var parts := [
		Rect2(full.position, Vector2(full.size.x, h.position.y - full.position.y)),
		Rect2(Vector2(full.position.x, h.end.y), Vector2(full.size.x, full.end.y - h.end.y)),
		Rect2(Vector2(full.position.x, h.position.y), Vector2(h.position.x - full.position.x, h.size.y)),
		Rect2(Vector2(h.end.x, h.position.y), Vector2(full.end.x - h.end.x, h.size.y)),
	]
	for k in 4:
		_dims[k].position = parts[k].position
		_dims[k].size = parts[k].size.max(Vector2.ZERO)
	# 말풍선: 뚫린 자리 반대쪽(자리가 위면 아래에, 아래면 위에)
	_bubble.size = Vector2.ZERO
	await get_tree().process_frame
	if not is_instance_valid(_bubble):
		return
	var below := h.get_center().y < size.y * 0.5
	var y := (h.end.y + 120.0) if below else (h.position.y - 120.0 - _bubble.size.y)
	_bubble.position = Vector2((size.x - _bubble.size.x) / 2.0, clampf(y, 80.0, size.y - _bubble.size.y - 40.0))


func _process(delta: float) -> void:
	_t += delta
	_armed = maxf(0.0, _armed - delta)
	if i < steps.size() and (steps[i].get("target") is Control or steps[i].get("target") is Callable):
		var r := _rect_of(steps[i])  # 따라 움직이는 자리(애니메이션)
		if r != _hole:
			_hole = r
			_layout()
	queue_redraw()


func _draw() -> void:
	if _hole.size == Vector2.ZERO:
		return
	var pulse := 4.0 + 3.0 * sin(_t * 4.0)
	draw_rect(_hole.grow(pulse), Color(1, 0.95, 0.6, 0.9), false, 4.0)
	# 화살표: 자리가 위쪽이면 아래에서, 아래쪽이면 위에서 가리킨다
	var below := _hole.get_center().y < size.y * 0.5
	var bob := sin(_t * 6.0) * 10.0
	var tip := Vector2(_hole.get_center().x, (_hole.end.y + 14.0 + bob) if below else (_hole.position.y - 14.0 - bob))
	var dir := -1.0 if below else 1.0  # 화살표 머리 쪽
	var base := tip - Vector2(0, dir * 70.0)
	draw_line(base, tip - Vector2(0, dir * 26.0), Color("f5c542"), 14.0)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-26, -dir * 30), tip + Vector2(26, -dir * 30)]), Color("f5c542"))
	draw_polyline(PackedVector2Array([tip, tip + Vector2(-26, -dir * 30), tip + Vector2(26, -dir * 30), tip]), UiKit.INK, 3.0)


func _on_dim_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	if i < steps.size() and steps[i].get("mode", "any") == "any" and _armed <= 0.0:
		_next()


## 뚫린 자리를 누름(any 단계도 자리를 누르면 넘어간다. tap 단계에서 버튼이 아니면 여기서 넘어간다).
func _input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or _armed > 0.0:
		return
	if i >= steps.size() or not _hole.has_point(get_global_transform_with_canvas().affine_inverse() * ev.position):
		return
	var tg: Variant = steps[i].get("target")
	if steps[i].get("mode", "any") == "tap" and tg is BaseButton:
		return  # 버튼은 pressed로 넘어간다
	_next.call_deferred()


func _next() -> void:
	if i >= steps.size():
		return
	i += 1
	_show()


func _finish() -> void:
	i = steps.size()
	finished.emit()
	queue_free()


## 화면에서 한 묶음을 보인다(처음일 때만). 끝나면 본 것으로 남긴다.
static func run(host: Control, id: String, list: Array[Dictionary]) -> TutorialOverlay:
	if not TutorialBook.should(GameData.state, id, GameData.tutorials_enabled):
		return null
	TutorialBook.mark(GameData.state, id)
	GameData.save()
	var o := TutorialOverlay.new()
	host.add_child(o)
	o.start(list)
	return o
