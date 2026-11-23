class_name OreSlashGame
extends Minigame
## 9 부서진 광산 '광석 캐기'(그어 베기 + 어원 가리기): 처음에 어원 2개(광맥)를 알려 준다.
## 영어 단어가 적힌 광석이 튀어 오른다. 그 어원이 들어간 단어의 광석만 그어 깬다.
## 맞게 깨면 그 단어 1개. 다른 단어를 깨면 실수(max_miss번이면 끝).

const AREA := Vector2(1280, 720)

var roots: Array[Dictionary] = []  ## 광맥 어원 {root, meaning}
var targets: Array[int] = []  ## 어원이 든 단어 순번
var others: Array[int] = []
var ores: Array[Dictionary] = []  ## {pos, vel, target, w}
var misses := 0
var events: Array[Dictionary] = []  ## 깬 광석 {w, ok, pos}
var _spawn_t := 0.0


static func key(e: Dictionary) -> String:
	return String(e.get("root", "")).to_lower().strip_edges()


static func is_stem(k: String) -> bool:
	return not k.ends_with("-") and not k.begins_with("-")


func _build() -> void:
	# 판의 단어에서 가장 많이 쓰인 어원 2개(접두사보다 어근을 먼저)
	var count := {}
	var info := {}
	for w in words:
		for e in w.etym:
			var k := key(e)
			if k == "":
				continue
			count[k] = int(count.get(k, 0)) + 1
			info[k] = e
	var ks: Array = count.keys()
	ks.sort_custom(func(a: String, b: String) -> bool:
		if is_stem(a) != is_stem(b):
			return is_stem(a)
		return count[a] > count[b] if count[a] != count[b] else a < b)
	for k in ks.slice(0, 2):
		roots.append({"root": info[k].get("root", ""), "meaning": info[k].get("meaning", ""), "key": k})
	for i in words.size():
		if has_root(words[i]):
			targets.append(i)
		else:
			others.append(i)


func has_root(w: WordData) -> bool:
	for e in w.etym:
		for r in roots:
			if key(e) == r["key"]:
				return true
	return false


func spawn(is_target: bool, pos: Vector2 = Vector2(-1, -1), vel: Vector2 = Vector2.ZERO) -> void:
	var pool := targets if is_target or others.is_empty() else others
	if pool.is_empty():
		return
	# 아직 안 깬 단어를 먼저
	var fresh := pool.filter(func(i: int) -> bool: return not words[i].id in earned)
	var from: Array = fresh if not fresh.is_empty() else pool
	var w: int = from[rng.randi_range(0, from.size() - 1)]
	var p := pos if pos.x >= 0 else Vector2(rng.randf_range(160, AREA.x - 160), AREA.y + 40)
	var v := vel if vel != Vector2.ZERO else Vector2(rng.randf_range(-160, 160), -rng.randf_range(820, 1000))
	ores.append({"pos": p, "vel": v, "target": pool == targets, "w": w})


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
			events.append({"w": o["w"], "ok": o["target"], "pos": o["pos"]})
			if o["target"]:
				earn(words[o["w"]].id)
			else:
				misses += 1
				if misses >= int(cfg["max_miss"]):
					finish()
		else:
			keep.append(o)
	ores = keep
	return hit
