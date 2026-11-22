class_name OreSlashGame
extends Minigame
## 9 부서진 광산 '광석 캐기'(그어 베기): 튀어 오르는 광석을 손가락으로 그어 깬다.
## 목표 무늬(광맥 색)와 같은 광석만 깨야 하고, 다른 것을 깨면 연속이 끊긴다. 연속 5개마다 1개.

const AREA := Vector2(1280, 720)

var ores: Array[Dictionary] = []  ## {pos, vel, target}
var combo := 0
var target_attr := 0
var _spawn_t := 0.0


func _build() -> void:
	target_attr = words[0].primary_attr() if not words.is_empty() else 1


func spawn(is_target: bool, pos: Vector2 = Vector2(-1, -1), vel: Vector2 = Vector2.ZERO) -> void:
	var p := pos if pos.x >= 0 else Vector2(rng.randf_range(120, AREA.x - 120), AREA.y + 40)
	var v := vel if vel != Vector2.ZERO else Vector2(rng.randf_range(-160, 160), -rng.randf_range(820, 1000))
	ores.append({"pos": p, "vel": v, "target": is_target})


func _tick(dt: float) -> void:
	_spawn_t -= dt
	if _spawn_t <= 0.0:
		_spawn_t = float(cfg["spawn_every"])
		spawn(rng.randf() < float(cfg["target_chance"]))
	var g := float(cfg["gravity"])
	for o in ores:
		o["vel"] += Vector2(0, g) * dt
		o["pos"] += o["vel"] * dt
	ores = ores.filter(func(o: Dictionary) -> bool: return o["pos"].y < AREA.y + 80 or o["vel"].y < 0)


## 손가락이 a에서 b로 그은 선. 닿은 광석을 깬다. 깬 수를 돌려준다.
func slash(a: Vector2, b: Vector2) -> int:
	if finished:
		return 0
	var r := float(cfg["radius"])
	var hit := 0
	var keep: Array[Dictionary] = []
	for o in ores:
		if Geometry2D.get_closest_point_to_segment(o["pos"], a, b).distance_to(o["pos"]) <= r:
			hit += 1
			if o["target"]:
				combo += 1
				if combo % int(cfg["combo_per_word"]) == 0 and earned.size() < words.size():
					earn(words[earned.size()].id)
			else:
				combo = 0
		else:
			keep.append(o)
	ores = keep
	return hit
