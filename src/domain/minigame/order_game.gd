class_name OrderGame
extends Minigame
## 1 공방 마을 '주문 제작'(주문 처리 퍼즐): 주문서(뜻과 속성 무늬)가 차례로 오고,
## 흘러오는 단어 카드 중 맞는 것을 집는다. 주문마다 제한 시간. 시간 안에 맞게 낸 주문마다 1개.

var orders: Array[String] = []  ## 주문 단어 id 차례
var current := 0
var order_left := 0.0
var belt: Array[String] = []
var misses := 0
var _belt_t := 0.0


func _build() -> void:
	var ids: Array[String] = []
	for w in words:
		ids.append(w.id)
	ids.shuffle()
	for i in mini(int(cfg["orders"]), ids.size()):
		orders.append(ids[i])
	order_left = float(cfg["order_time"])
	for i in int(cfg["belt_size"]):
		belt.append(_random_card())
	_ensure_answer()


func current_word() -> String:
	return orders[current] if current < orders.size() else ""


func _random_card() -> String:
	return words[rng.randi_range(0, words.size() - 1)].id


func _ensure_answer() -> void:
	var ans := current_word()
	if ans != "" and not ans in belt:
		belt[rng.randi_range(0, belt.size() - 1)] = ans


## 카드 하나를 집는다. 맞으면 얻고 다음 주문, 틀리면 실수.
func pick(i: int) -> bool:
	if finished or i < 0 or i >= belt.size():
		return false
	var ok := belt[i] == current_word()
	if ok:
		earn(belt[i])
		belt[i] = _random_card()
		_next_order()
	else:
		_miss()
	return ok


func _miss() -> void:
	misses += 1
	if misses >= int(cfg["max_miss"]):
		finish()


func _next_order() -> void:
	current += 1
	order_left = float(cfg["order_time"])
	if current >= orders.size():
		finish()
	else:
		_ensure_answer()


func _tick(dt: float) -> void:
	order_left -= dt
	if order_left <= 0.0:
		_miss()
		if not finished:
			_next_order()
	_belt_t += dt
	if _belt_t >= float(cfg["belt_step"]):
		_belt_t = 0.0
		belt.pop_front()
		belt.append(_random_card())
		_ensure_answer()
