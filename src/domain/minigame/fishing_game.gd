class_name FishingGame
extends Minigame
## 5 항구 도시 '낚시'(뜻 미끼 + 손맛 싸움): 뜻이 적힌 미끼를 던지면 영어 단어 물고기들이 바늘 둘레로 모여든다.
## 물고기 하나를 골라 챈다 → 싸움. 누르고 있으면 잡이 막대가 오르고, 떼면 내려간다(스타듀 밸리 낚시 차용).
## 물고기가 막대 안에 있으면 손맛 게이지가 차고, 밖에 있으면 준다. 가득 차면 그 단어를 낚는다(1개), 비면 놓친다(실수).
## 미끼와 단어의 뜻이 맞으면 막대가 크고 물고기가 느리다(쉬운 싸움). 안 맞으면 막대가 작고 물고기가 빠르다.
## 판마다 모이는 물고기 수는 늘 같다(cfg.fish).

var questions: Array[int] = []  ## 미끼(뜻)로 쓸 단어 순번
var q := 0
var fish: Array[Dictionary] = []  ## {w, angle, r, speed} 바늘 둘레를 도는 물고기
var misses := 0
var state := "wait"  ## "wait"(고르기) | "fight"(싸움)
var hooked := -1  ## 싸우는 물고기의 단어 순번
var match_ := false  ## 미끼와 맞는 물고기인지
var fish_pos := 0.5  ## 싸움 칸 안의 물고기 높이 0(아래)~1(위)
var bar_pos := 0.2  ## 잡이 막대 아래 끝
var bar_vel := 0.0
var progress := 0.0
var holding := false
var last := {}  ## 끝난 싸움 {w, match, caught}
var _goal := 0.5
var _goal_t := 0.0


func _build() -> void:
	for i in mini(int(cfg["questions"]), words.size()):
		questions.append(i)
	_new_school()


func bait() -> WordData:
	return words[questions[q]] if q < questions.size() else null


## 맞는 물고기 하나 + 다른 뜻 물고기들. 판이 지나도 수는 그대로다.
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
	ids.shuffle()
	for k in ids.size():
		fish.append({"w": ids[k], "angle": TAU * k / ids.size(), "r": rng.randf_range(0.55, 0.95),
			"speed": rng.randf_range(0.25, 0.5) * (1.0 if k % 2 == 0 else -1.0)})


func is_match(w: int) -> bool:
	return words[w].meaning == bait().meaning


## 지금 싸움의 막대 크기(0~1)와 물고기 빠르기.
func bar_size() -> float:
	return float(cfg["bar_easy" if match_ else "bar_hard"])


func fish_speed() -> float:
	return float(cfg["fish_easy" if match_ else "fish_hard"])


## 물고기를 챈다 → 싸움 시작.
func hook(i: int) -> bool:
	if finished or state != "wait" or i < 0 or i >= fish.size():
		return false
	hooked = fish[i]["w"]
	match_ = is_match(hooked)
	state = "fight"
	fish_pos = 0.5
	bar_pos = 0.5 - bar_size() / 2.0
	bar_vel = 0.0
	progress = float(cfg["start_progress"])
	_goal = rng.randf()
	_goal_t = 0.0
	return true


func hold(on: bool) -> void:
	holding = on


func _tick(dt: float) -> void:
	if state == "wait":
		for f in fish:
			f["angle"] += f["speed"] * dt
		return
	# 물고기: 가끔 새 목표 높이를 고르고 그쪽으로 헤엄친다
	_goal_t -= dt
	if _goal_t <= 0.0:
		_goal = rng.randf()
		_goal_t = rng.randf_range(0.4, 1.2) / maxf(0.3, fish_speed())
	fish_pos = move_toward(fish_pos, _goal, fish_speed() * dt)
	# 막대: 누르면 위로, 떼면 아래로(바닥·천장에서 멈춘다)
	bar_vel += (float(cfg["lift"]) if holding else -float(cfg["gravity"])) * dt
	bar_vel = clampf(bar_vel, -1.2, 1.2)
	bar_pos += bar_vel * dt
	var top := 1.0 - bar_size()
	if bar_pos < 0.0 or bar_pos > top:
		bar_pos = clampf(bar_pos, 0.0, top)
		bar_vel = 0.0
	if inside():
		progress += float(cfg["fill"]) * dt
	else:
		progress -= float(cfg["drain"]) * dt
	if progress >= 1.0:
		_end_fight(true)
	elif progress <= 0.0:
		_end_fight(false)


func inside() -> bool:
	return fish_pos >= bar_pos and fish_pos <= bar_pos + bar_size()


func _end_fight(caught: bool) -> void:
	last = {"w": hooked, "match": match_, "caught": caught}
	state = "wait"
	holding = false
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
