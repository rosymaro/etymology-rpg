class_name MoatGame
extends Minigame
## 7 소용돌이 호수 '물레방아'(물레방아 디펜스): 위에서 단어 병사들이 마을로 내려온다. 마을 앞에 물레방아 3개가 있고,
## 물레방아마다 활이 달려 사정거리(range) 안의 적을 쏜다. 물길(수문)을 열면 그 물레방아가 돈다.
## 흐르는 물의 양은 정해져 있어서, 하나만 열면 그 물레방아가 빨라져 화살이 빠르게 나가고, 셋을 열면 고르게 나눠 나간다.
## 잡은 수만큼 단어를 얻는 게임이 아니다: goal(100)마리를 잡으면 이 판의 단어를 모두, 못 잡으면 절반을 얻는다.
## 시간이 갈수록 적이 많아지고 빨라지며 튼튼해진다. 적은 한쪽으로 몰려오므로 물길을 바꿔 가며 막아야 한다.
## 좌표는 0~1 비율. y = 0 위쪽(적이 나옴) → 1 성.

const WHEEL_X := [0.2, 0.5, 0.8]
const WHEEL_Y := 0.82

var gates: Array[bool] = [true, false, false]
var enemies: Array[Dictionary] = []  ## {w, pos, hp, speed}
var arrows: Array[Dictionary] = []  ## {pos, target(적 순번 대신 위치), vel}
var kills := 0
var leaks := 0
var elapsed := 0.0
var spin: Array[float] = [0.0, 0.0, 0.0]  ## 물레방아 각도(그림용)
var _cool: Array[float] = [0.0, 0.0, 0.0]
var _spawn := 0.0
var _lane := 0.5  ## 지금 적이 몰려오는 쪽
var _lane_t := 0.0
var _next := 0
var _paid := false


func _build() -> void:
	_spawn = 0.5
	_lane = rng.randf_range(0.15, 0.85)


func toggle(i: int) -> void:
	if not finished and i >= 0 and i < gates.size():
		gates[i] = not gates[i]


func open_count() -> int:
	return gates.count(true)


## 물레방아 i가 1초에 쏘는 화살 수(물을 나눠 쓴다).
func fire_rate(i: int) -> float:
	if not gates[i]:
		return 0.0
	return float(cfg["total_fire"]) / open_count()


func wheel_pos(i: int) -> Vector2:
	return Vector2(WHEEL_X[i], WHEEL_Y)


func progress() -> float:
	return clampf(elapsed / float(cfg["duration"]), 0.0, 1.0)


func spawn_enemy(x: float = -1.0) -> void:
	if x < 0.0:
		x = clampf(_lane + rng.randf_range(-0.12, 0.12), 0.05, 0.95)
	var k := progress()
	var hp := 1 if k < float(cfg["tough_from"]) else (2 if rng.randf() < 0.5 else 1)
	enemies.append({"w": _next % words.size(), "pos": Vector2(x, 0.0), "hp": hp, "max": hp,
		"speed": lerpf(float(cfg["speed_start"]), float(cfg["speed_end"]), k) * rng.randf_range(0.85, 1.15)})
	_next += 1


func _tick(dt: float) -> void:
	elapsed += dt
	var k := progress()
	# 적이 몰려오는 쪽이 가끔 바뀐다
	_lane_t -= dt
	if _lane_t <= 0.0:
		_lane_t = float(cfg["lane_change"])
		_lane = rng.randf_range(0.1, 0.9)
	_spawn -= dt
	if _spawn <= 0.0:
		_spawn = lerpf(float(cfg["spawn_start"]), float(cfg["spawn_end"]), k)
		spawn_enemy()
	for e in enemies:
		e["pos"].y += e["speed"] * dt
		if e["pos"].y >= WHEEL_Y + 0.08:
			e["hp"] = 0
			leaks += 1
			e["leak"] = true
	# 물레방아: 열린 것만 돌고, 사정거리 안에서 가장 성에 가까운 적을 쏜다
	for i in gates.size():
		spin[i] += fire_rate(i) * dt * 1.5
		if not gates[i]:
			continue
		_cool[i] -= dt
		if _cool[i] > 0.0:
			continue
		var target := _target(i)
		if target < 0:
			continue
		_cool[i] = 1.0 / fire_rate(i)
		var to: Vector2 = enemies[target]["pos"] - wheel_pos(i)
		arrows.append({"pos": wheel_pos(i), "vel": to.normalized() * float(cfg["arrow_speed"]), "life": float(cfg["range"]) / float(cfg["arrow_speed"]) + 0.2})
	for a in arrows:
		a["pos"] += a["vel"] * dt
		a["life"] -= dt
		for e in enemies:
			if e["hp"] > 0 and (a["pos"] as Vector2).distance_to(e["pos"]) < float(cfg["hit_r"]):
				e["hp"] -= 1
				a["life"] = 0.0
				if e["hp"] <= 0:
					kills += 1
				break
	arrows = arrows.filter(func(a: Dictionary) -> bool: return a["life"] > 0.0)
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e["hp"] > 0)
	if kills >= int(cfg["goal"]):
		finish()


func _target(i: int) -> int:
	var best := -1
	var by := -1.0
	for j in enemies.size():
		var e := enemies[j]
		if (e["pos"] as Vector2).distance_to(wheel_pos(i)) <= float(cfg["range"]) and e["pos"].y > by:
			by = e["pos"].y
			best = j
	return best


## 다 잡으면 이 판의 단어를 모두, 못 잡으면 절반.
func reward_count() -> int:
	var n := mini(max_words, words.size())
	return n if kills >= int(cfg["goal"]) else n / 2


func finish() -> void:
	if not _paid:
		_paid = true
		finished = true  # earn()이 다시 finish를 부르지 않게 먼저 끝낸다
		for i in reward_count():
			if earned.size() < max_words and not words[i].id in earned:
				earned.append(words[i].id)
	finished = true
