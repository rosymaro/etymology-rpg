class_name FishingGame
extends Minigame
## 5 항구 도시 '낚시'(위에서 본 물 + 리듬 싸움): 위에 미끼(뜻)가 적혀 있고, 물속에 영어 단어 물고기가 돌아다닌다.
## 1. 누르고 있으면 그 자리에 찌를 던진다. 가장 가까운 물고기가 다가와 입질하면 큰 원이 점점 줄어든다.
## 2. 원이 작아졌을 때(hook_ring 이하) 손을 떼면 걸린다 → 싸움. 너무 일찍 떼면 달아나고, 원이 다 줄면 미끼만 먹고 간다.
## 3. 싸움: 물고기 둘레 6방향에 원이 있다. 물고기에서 점이 6개 중 하나로 날아가고, 원에 닿을 때 그 원을 누른다(리듬 게임).
##    미끼와 뜻이 맞는 물고기는 need_match번만 맞히면 잡힌다. 뜻이 틀린 물고기는 notes개를 모두 맞혀야 잡힌다.
## 잡으면 그 단어 1개, 놓치면 실수(max_miss번이면 끝). 판마다 물고기 수는 같다(cfg.fish). 좌표는 0~1 비율.

const DIRS := 6

var questions: Array[int] = []
var q := 0
var fish: Array[Dictionary] = []  ## {w, pos, vel}
var misses := 0
var state := "idle"  ## idle | cast(찌를 던짐) | bite(입질, 원이 준다) | fight
var bobber := Vector2(-1, -1)
var biter := -1  ## 다가오는/입질하는 물고기 칸
var ring := 1.0  ## 입질 원 크기 1 → 0
var hooked := -1  ## 싸우는 물고기의 단어 순번
var match_ := false
var note_dir := -1  ## 지금 날아가는 점의 방향(0~5)
var note_t := 0.0  ## 0(물고기) → 1(원에 닿음)
var notes_left := 0
var hits := 0
var last := {}  ## 끝난 싸움 {w, match, caught}, 화면이 읽고 비운다
var note_events: Array[Dictionary] = []  ## {dir, ok}
var _gap := 0.0


func _build() -> void:
	for i in mini(int(cfg["questions"]), words.size()):
		questions.append(i)
	_new_school()


func bait() -> WordData:
	return words[questions[q]] if q < questions.size() else null


func is_match(w: int) -> bool:
	return bait() != null and words[w].meaning == bait().meaning


func _new_school() -> void:
	fish.clear()
	if bait() == null:
		return
	var ids: Array[int] = [questions[q]]
	var others: Array = range(words.size())
	others.shuffle()
	for i in others:
		if ids.size() >= int(cfg["fish"]):
			break
		if i != questions[q] and words[i].meaning != bait().meaning:
			ids.append(i)
	while ids.size() < int(cfg["fish"]) and others.size() > 1:  # 단어가 모자라도 수를 채운다
		var j: int = others[rng.randi_range(0, others.size() - 1)]
		if j != questions[q]:
			ids.append(j)
	for w in ids:
		var a := rng.randf() * TAU
		fish.append({"w": w, "pos": Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.2, 0.9)),
			"vel": Vector2(cos(a), sin(a)) * float(cfg["swim_speed"])})


## 누른 자리에 찌를 던진다.
func cast(p: Vector2) -> void:
	if finished or state != "idle":
		return
	bobber = p
	state = "cast"
	biter = _nearest(p)
	ring = 1.0


## 손을 뗀다.
func release() -> String:
	if state == "cast":
		state = "idle"  # 아직 아무것도 안 물었다
		return "cancel"
	if state != "bite":
		return ""
	if ring <= float(cfg["hook_ring"]):
		_start_fight(fish[biter]["w"])
		return "hook"
	_scare()
	return "early"


func _nearest(p: Vector2) -> int:
	var best := -1
	var bd := INF
	for i in fish.size():
		var d: float = (fish[i]["pos"] as Vector2).distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best


func _scare() -> void:
	state = "idle"
	if biter >= 0:
		fish[biter]["vel"] = ((fish[biter]["pos"] as Vector2) - bobber).normalized() * float(cfg["swim_speed"]) * 3.0
	biter = -1


func _start_fight(w: int) -> void:
	hooked = w
	match_ = is_match(w)
	state = "fight"
	notes_left = int(cfg["notes"])
	hits = 0
	_gap = 0.6
	note_dir = -1


func need() -> int:
	return int(cfg["need_match"]) if match_ else int(cfg["notes"])


func note_time() -> float:
	return float(cfg["note_time_match" if match_ else "note_time_hard"])


## 싸움에서 d번 원을 누른다.
func tap(d: int) -> bool:
	if state != "fight" or note_dir < 0:
		return false
	var ok := d == note_dir and note_t >= float(cfg["hit_from"])
	_judge_note(ok)
	return ok


func _judge_note(ok: bool) -> void:
	note_events.append({"dir": note_dir, "ok": ok})
	note_dir = -1
	notes_left -= 1
	if ok:
		hits += 1
	_gap = float(cfg["note_gap"])
	if hits >= need():
		_end_fight(true)
	elif hits + notes_left < need():
		_end_fight(false)


func _end_fight(caught: bool) -> void:
	last = {"w": hooked, "match": match_, "caught": caught}
	state = "idle"
	biter = -1
	if caught:
		earn(words[hooked].id)
	else:
		misses += 1
		if misses >= int(cfg["max_miss"]):
			finish()
			return
	q += 1
	if q >= questions.size():
		finish()
	else:
		_new_school()


func _tick(dt: float) -> void:
	for i in fish.size():
		var f := fish[i]
		if i == biter and state in ["cast", "bite"]:
			var to: Vector2 = bobber - (f["pos"] as Vector2)
			if to.length() > 0.03:
				f["pos"] += to.normalized() * float(cfg["swim_speed"]) * 1.5 * dt
			elif state == "cast":
				state = "bite"
				ring = 1.0
			continue
		var p: Vector2 = f["pos"] + f["vel"] * dt
		if p.x < 0.05 or p.x > 0.95:
			f["vel"].x = -f["vel"].x
		if p.y < 0.15 or p.y > 0.95:
			f["vel"].y = -f["vel"].y
		f["pos"] = Vector2(clampf(p.x, 0.05, 0.95), clampf(p.y, 0.15, 0.95))
		if (f["vel"] as Vector2).length() > float(cfg["swim_speed"]) * 1.01:
			f["vel"] = (f["vel"] as Vector2).lerp((f["vel"] as Vector2).normalized() * float(cfg["swim_speed"]), dt)
	if state == "bite":
		ring -= dt / float(cfg["bite_time"])
		if ring <= 0.0:  # 미끼만 먹고 달아났다
			_scare()
	elif state == "fight":
		if note_dir < 0:
			_gap -= dt
			if _gap <= 0.0 and notes_left > 0:
				note_dir = rng.randi_range(0, DIRS - 1)
				note_t = 0.0
		else:
			note_t += dt / note_time()
			if note_t > float(cfg["hit_until"]):  # 놓쳤다
				_judge_note(false)
