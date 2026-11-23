class_name FishingGame
extends Minigame
## 5 항구 도시 '낚시'(뜻 낚시): 낚싯줄에 영어 단어가 걸려 있고, 물속에서 뜻이 적힌 물고기가 헤엄친다.
## 그 단어의 뜻인 물고기를 낚으면 1개. 틀린 물고기를 낚으면 실수(max_miss번이면 끝). 주문 제작(뜻 → 단어)의 반대 방향.

const AREA := Vector2(1000, 420)  ## 물속 넓이(화면은 이 비율로 늘인다)

var questions: Array[int] = []  ## 물어볼 단어 순번
var q := 0
var fish: Array[Dictionary] = []  ## {w: 뜻을 가진 단어 순번, pos, vx}
var misses := 0
var last := ""  ## "right" | "wrong" | ""


func _build() -> void:
	for i in mini(int(cfg["questions"]), words.size()):
		questions.append(i)
	_new_school()


func current() -> WordData:
	return words[questions[q]] if q < questions.size() else null


## 정답 물고기 하나와 다른 뜻 물고기들.
func _new_school() -> void:
	fish.clear()
	if current() == null:
		return
	var ids: Array[int] = [questions[q]]
	var others := range(words.size())
	others.shuffle()
	for i in others:
		if ids.size() >= int(cfg["fish"]):
			break
		if i != questions[q] and words[i].meaning != current().meaning:
			ids.append(i)
	ids.shuffle()
	var lanes := ids.size()
	for k in lanes:
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		fish.append({"w": ids[k], "pos": Vector2(rng.randf_range(80, AREA.x - 80), 50 + k * (AREA.y - 80) / maxf(1, lanes - 1)),
			"vx": dir * rng.randf_range(float(cfg["speed_min"]), float(cfg["speed_max"]))})


func _tick(dt: float) -> void:
	for f in fish:
		f["pos"].x += f["vx"] * dt
		if f["pos"].x < 60 or f["pos"].x > AREA.x - 60:
			f["vx"] = -f["vx"]
			f["pos"].x = clampf(f["pos"].x, 60, AREA.x - 60)


## 물고기를 낚는다.
func catch(i: int) -> bool:
	if finished or i < 0 or i >= fish.size():
		return false
	var ok: bool = fish[i]["w"] == questions[q]
	if ok:
		last = "right"
		earn(current().id)
	else:
		last = "wrong"
		misses += 1
		if misses >= int(cfg["max_miss"]):
			finish()
			return false
	q += 1
	if q >= questions.size():
		finish()
	elif not finished:
		_new_school()
	return ok
