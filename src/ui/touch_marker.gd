class_name TouchMarker
extends Control
## 옵션 '누른 자리 표시'를 켜면, 게임이 받은 터치 자리에 빨간 고리를 잠깐 그린다.
## 손가락 자리와 고리가 어긋나면 화면과 입력 좌표가 어긋난 것이다(기기 화면 설정 문제를 찾을 때 쓴다).

var _marks: Array[Dictionary] = []  ## {pos, t}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100


func _input(ev: InputEvent) -> void:
	if not (GameData.settings and GameData.settings.touch_marker):
		return
	if ev is InputEventScreenTouch and ev.pressed:
		_marks.append({"pos": (ev as InputEventScreenTouch).position, "t": 0.8})
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_marks.append({"pos": (ev as InputEventMouseButton).position, "t": 0.8})
	queue_redraw()


func _process(delta: float) -> void:
	if _marks.is_empty():
		return
	for m in _marks:
		m["t"] -= delta
	_marks = _marks.filter(func(m: Dictionary) -> bool: return m["t"] > 0.0)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for m in _marks:
		var p: Vector2 = get_global_transform_with_canvas().affine_inverse() * (m["pos"] as Vector2)
		var a: float = clampf(m["t"] / 0.8, 0.0, 1.0)
		draw_arc(p, 26, 0, TAU, 32, Color(1, 0.2, 0.2, a), 4)
		draw_line(p - Vector2(36, 0), p + Vector2(36, 0), Color(1, 0.2, 0.2, a), 2)
		draw_line(p - Vector2(0, 36), p + Vector2(0, 36), Color(1, 0.2, 0.2, a), 2)
		draw_string(font, p + Vector2(30, -30), "%d, %d" % [int(p.x), int(p.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.2, 0.2, a))
