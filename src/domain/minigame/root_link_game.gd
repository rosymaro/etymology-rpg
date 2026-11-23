class_name RootLinkGame
extends Minigame
## 10 갈라진 탑 '문양 잇기'(갈라진 말뿌리 되찾기): 단어 5개가 판 여기저기 뜻과 함께 놓여 있다.
## 그 단어들의 어원 조각과 함정 어원이 뜻을 달고 판 위를 돌아다닌다. 화살을 쏘아 맞히면 쓰러지고,
## 쓰러진 어원을 끌어 단어에 놓으면 그때 단어 아래로 뿌리 선이 생긴다. 미리 그어 두지 않아서 어원이 몇 개인지 모른다.
## 한 단어에 max_roots개까지 놓을 수 있다(어원이 1개인 단어에도 2개 이상 놓을 수 있다).
## 놓인 어원이 그 단어의 어원과 정확히 같으면(빠짐도 덤도 없이) 새싹이 오르고 그 단어 1개. 새싹 5개면 완성.
## 시간이 다 되도록 새싹이 안 오른 단어는 오답으로 두고 정답 어원을 보여 준다.
## 좌표는 0~1 비율: 단어는 아래쪽 절반, 어원은 위쪽(ROAM_BOTTOM까지)을 돌아다닌다. 활은 오른쪽 가장자리(0.96, 0.47).

const BOW := Vector2(0.96, 0.47)
const ROAM_BOTTOM := 0.45  ## 어원이 돌아다니는 아래 끝

var targets: Array[int] = []  ## 단어 순번
var word_pos: Array[Vector2] = []
var roots: Array[Dictionary] = []  ## {root, meaning, owner(단어 순번, 함정은 -1), pos, vel, state("roam"|"down"|"placed"), down_t, at(targets 칸), slot}
var arrows: Array[Dictionary] = []  ## {pos, to}
var sprouted: Array[bool] = []
var shots := 0


func _build() -> void:
	var used: Dictionary = {}
	for i in words.size():
		if targets.size() >= int(cfg["pairs"]):
			break
		var w := words[i]
		if w.etym.is_empty() or _shares(w, used):
			continue
		targets.append(i)
		for e in w.etym:
			used[_key(e)] = true
	# 단어 자리: 아래쪽 절반에 흩어 둔다(겹치지 않게 칸을 나눠 흔든다)
	var n := targets.size()
	for k in n:
		var col := (k + 0.5) / n
		var row := 0.56 if k % 2 == 0 else 0.8
		word_pos.append(Vector2(col * 0.92 + rng.randf_range(-0.02, 0.02), row + rng.randf_range(-0.01, 0.01)))
		sprouted.append(false)
		for e in words[targets[k]].etym:
			_add_root(e, targets[k])
	# 함정 어원: 다른 단어의 어원 중 정답과 겹치지 않는 것
	var decoys := 0
	for i in words.size():
		if decoys >= int(cfg["decoys"]):
			break
		if i in targets:
			continue
		for e in words[i].etym:
			if decoys < int(cfg["decoys"]) and not used.has(_key(e)):
				used[_key(e)] = true
				_add_root(e, -1)
				decoys += 1


static func _key(e: Dictionary) -> String:
	return String(e.get("root", "")).to_lower().strip_edges()


func _shares(w: WordData, used: Dictionary) -> bool:
	for e in w.etym:
		if used.has(_key(e)):
			return true
	return false


func _add_root(e: Dictionary, owner: int) -> void:
	var ang := rng.randf() * TAU
	roots.append({"root": e.get("root", ""), "meaning": e.get("meaning", ""), "owner": owner,
		"pos": Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.08, 0.4)),
		"vel": Vector2(cos(ang), sin(ang)) * float(cfg["roam_speed"]) * rng.randf_range(0.7, 1.3),
		"state": "roam", "down_t": 0.0, "at": -1, "slot": -1})


## 단어 칸 k의 실제 어원 수(화면에는 보이지 않는다)
func slots(k: int) -> int:
	return words[targets[k]].etym.size()


## 한 단어에 놓을 수 있는 어원 수
func cap() -> int:
	return int(cfg.get("max_roots", 3))


func placed_at(k: int) -> Array[int]:
	var out: Array[int] = []
	for i in roots.size():
		if roots[i]["state"] == "placed" and roots[i]["at"] == k:
			out.append(i)
	return out


## 활에서 to(0~1 좌표)로 화살을 쏜다.
func shoot(to: Vector2) -> void:
	if finished:
		return
	shots += 1
	arrows.append({"pos": BOW, "to": to})


func root_at(p: Vector2, states: Array) -> int:
	var best := -1
	var bd := float(cfg["hit_r"])
	for i in roots.size():
		if roots[i]["state"] in states:
			var d: float = (roots[i]["pos"] as Vector2).distance_to(p)
			if d <= bd:
				bd = d
				best = i
	return best


## 쓰러진(또는 이미 놓인) 어원 i를 단어 칸 k에 놓는다. k = -1이면 판에 내려놓는다(쓰러진 채).
func place(i: int, k: int, drop: Vector2 = Vector2(-1, -1)) -> bool:
	if finished or i < 0 or i >= roots.size() or not roots[i]["state"] in ["down", "placed"]:
		return false
	var r := roots[i]
	var from: int = r["at"]
	if k < 0 or k >= targets.size() or sprouted[k] or (k != from and placed_at(k).size() >= cap()):
		if r["state"] == "placed" and drop.x >= 0.0:  # 단어에서 떼어 판에 내려놓기
			_unplace(r, drop)
			if from >= 0:
				_reslot(from)
				_check(from)  # 틀린 어원을 떼어 내면 남은 것이 정답일 수 있다
			return true
		return false
	r["state"] = "placed"
	r["at"] = k
	if from >= 0 and from != k:
		_reslot(from)
		_check(from)
	_reslot(k)
	_check(k)
	return true


func _unplace(r: Dictionary, drop: Vector2) -> void:
	r["state"] = "down"
	r["down_t"] = float(cfg["down_time"])
	r["at"] = -1
	r["slot"] = -1
	r["pos"] = drop


func _reslot(k: int) -> void:
	var s := 0
	for i in placed_at(k):
		roots[i]["slot"] = s
		s += 1


## 놓인 어원이 그 단어의 어원과 정확히 같으면 새싹.
func is_right(k: int) -> bool:
	var p := placed_at(k)
	if p.size() != slots(k):
		return false
	for i in p:
		if roots[i]["owner"] != targets[k]:
			return false
	return true


func _check(k: int) -> void:
	if finished or sprouted[k] or not is_right(k):
		return
	sprouted[k] = true
	earn(words[targets[k]].id)
	if not false in sprouted:
		finish()


func complete() -> bool:
	return not sprouted.is_empty() and not false in sprouted


func _tick(dt: float) -> void:
	var sp := float(cfg["arrow_speed"]) * dt
	for a in arrows:
		a["pos"] = (a["pos"] as Vector2).move_toward(a["to"], sp)
		var hit := root_at(a["pos"], ["roam"])
		if hit >= 0:
			roots[hit]["state"] = "down"
			roots[hit]["down_t"] = float(cfg["down_time"])
			a["done"] = true
		elif (a["pos"] as Vector2).is_equal_approx(a["to"]):
			a["done"] = true
	arrows = arrows.filter(func(a: Dictionary) -> bool: return not a.get("done", false))
	for r in roots:
		if r["state"] == "roam":
			var p: Vector2 = r["pos"] + r["vel"] * dt
			if p.x < 0.05 or p.x > 0.95:
				r["vel"].x = -r["vel"].x
			if p.y < 0.05 or p.y > ROAM_BOTTOM:
				r["vel"].y = -r["vel"].y
			r["pos"] = Vector2(clampf(p.x, 0.05, 0.95), clampf(p.y, 0.05, ROAM_BOTTOM))
		elif r["state"] == "down":
			r["down_t"] -= dt
			if r["down_t"] <= 0.0:  # 오래 두면 다시 일어나 달아난다
				r["state"] = "roam"
				r["pos"] = Vector2(r["pos"].x, minf(r["pos"].y, ROAM_BOTTOM))
