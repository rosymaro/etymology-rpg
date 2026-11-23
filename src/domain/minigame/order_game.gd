class_name OrderGame
extends Minigame
## 1 공방 마을 '주문 제작'(주문 처리 퍼즐): 주문서(뜻과 속성 무늬)가 차례로 오고,
## 컨베이어 벨트 위로 단어 카드가 왼쪽에서 오른쪽으로 흘러간다. 맞는 카드를 집는다. 주문마다 제한 시간.
## 시간 안에 맞게 낸 주문마다 1개. 카드 위치 x는 벨트 위 0(왼쪽 끝)~1(오른쪽 끝)이다.

var orders: Array[String] = []  ## 주문 단어 id 차례
var current := 0
var order_left := 0.0
var items: Array[Dictionary] = []  ## 벨트 위 카드 {id, x}
var misses := 0
var _spacing := 0.25


func _build() -> void:
	var ids: Array[String] = []
	for w in words:
		ids.append(w.id)
	ids.shuffle()
	for i in mini(int(cfg["orders"]), ids.size()):
		orders.append(ids[i])
	order_left = float(cfg["order_time"])
	_spacing = 1.0 / float(cfg["belt_size"])
	for k in int(cfg["belt_size"]):
		items.append({"id": _random_card(), "x": 1.0 - _spacing * (k + 0.5)})
	_ensure_answer()


func current_word() -> String:
	return orders[current] if current < orders.size() else ""


## 지금 벨트 위 카드 id(오른쪽부터).
func belt_ids() -> Array[String]:
	var out: Array[String] = []
	for it in items:
		out.append(it["id"])
	return out


## 벨트에 아직 없는 단어 하나(같은 카드가 두 장 보이지 않게).
func _random_card() -> String:
	var on := {}
	for it in items:
		on[it["id"]] = true
	for k in 30:
		var id: String = words[rng.randi_range(0, words.size() - 1)].id
		if not on.has(id):
			return id
	return words[rng.randi_range(0, words.size() - 1)].id


## 답 카드가 벨트에 없으면(오른쪽 끝으로 떨어졌으면), 가장 왼쪽 카드를 답으로 바꾼다. 같은 카드가 두 장이 되지 않게 한다.
func _ensure_answer() -> void:
	var ans := current_word()
	if ans == "" or items.is_empty():
		return
	for it in items:
		if it["id"] == ans:
			return
	var last: Dictionary = items[0]
	for it in items:
		if it["x"] < last["x"]:
			last = it
	last["id"] = ans


## 카드 하나(items 순번)를 집는다. 맞으면 얻고 다음 주문, 틀리면 실수.
func pick(i: int) -> bool:
	if finished or i < 0 or i >= items.size():
		return false
	var ok: bool = items[i]["id"] == current_word()
	if ok:
		earn(items[i]["id"])
		items.remove_at(i)
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
	var v := float(cfg["belt_speed"])
	var min_x := 1.0
	for it in items:
		it["x"] += v * dt
		min_x = minf(min_x, it["x"])
	items = items.filter(func(it: Dictionary) -> bool: return it["x"] <= 1.05)
	if items.is_empty() or min_x >= _spacing:
		items.append({"id": _random_card(), "x": -0.05})
	_ensure_answer()
