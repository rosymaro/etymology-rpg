class_name CoinRow
extends Control
## 카드 바깥에 놓는 코인 줄. 새 코인을 받으면 잠깐 빙글빙글 돈 뒤 앞면(금색)·뒷면(은색)으로 멈춘다.

const R := 18.0

var flips: Array[bool] = []
var dim := false
var _spin := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_flips(f: Array[bool], spin: bool) -> void:
	flips = f.duplicate()
	_spin = BattleCard.SPIN_SEC if spin else 0.0
	queue_redraw()


func spinning() -> bool:
	return _spin > 0.0


func _process(delta: float) -> void:
	if _spin > 0.0:
		_spin = maxf(0.0, _spin - delta)
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var n := flips.size()
	var x0 := size.x / 2.0 - (n - 1) * (R * 2 + 8) / 2.0
	for i in n:
		var c := Vector2(x0 + i * (R * 2 + 8), size.y / 2.0)
		var heads := flips[i]
		var sx := 1.0
		if _spin > 0.0:  # 도는 동안: 옆으로 납작해졌다 펴지기를 되풀이하고 앞뒤가 번갈아 보인다
			var ph := (BattleCard.SPIN_SEC - _spin) * 22.0 + i * 0.9
			sx = absf(cos(ph))
			heads = cos(ph * 0.5) > 0.0
		var col := Color("f2c14e") if heads else Color("c9c9d6")
		if dim:
			col = col.lerp(UiKit.GRAY, 0.6)
		var pts := PackedVector2Array()
		for k in 20:
			var a := TAU * k / 20.0
			pts.append(c + Vector2(cos(a) * R * maxf(0.12, sx), sin(a) * R))
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, UiKit.INK, 2)
		if _spin <= 0.0:
			draw_string(font, c + Vector2(-R, 6), "H" if heads else "T", HORIZONTAL_ALIGNMENT_CENTER, R * 2, 16, UiKit.INK)
