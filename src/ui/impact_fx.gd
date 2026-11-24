class_name ImpactFx
extends Control
## 카드가 부딪힐 때 가운데 터지는 충격 이펙트(별 모양 + 퍼지는 고리). 그린 뒤 스스로 사라진다.

const LIFE := 0.55

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 12


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	var k := clampf(_t / LIFE, 0.0, 1.0)
	var a := 1.0 - k
	var r := lerpf(30.0, 95.0, k)
	if Art.draw(self, "fx", "impact", Vector2.ZERO, Vector2(r, r) * 2.4, Color(1, 1, 1, a)):
		return
	var pts := PackedVector2Array()
	for i in 16:  # 뾰족한 별
		var ang := TAU * i / 16.0 + k * 0.6
		pts.append(Vector2(cos(ang), sin(ang)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, Color(1.0, 0.85, 0.3, a))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.95, 0.45, 0.2, a), 4)
	draw_arc(Vector2.ZERO, r * 1.25, 0, TAU, 40, Color(1, 1, 1, a * 0.8), 5)
