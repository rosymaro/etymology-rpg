class_name OrderGame
extends Minigame
## 1 공방 마을 '주문 제작'(깨진 단어 고쳐 내기): 깨진 단어 조각들이 네모 고리 컨베이어 벨트를 돈다.
## 벨트 왼쪽은 창고 벽에 가려 보이지 않지만 그 안에서도 돈다(놓치면 다시 나올 때까지 오래 걸린다).
## 내 캐릭터가 걸어가서 조각을 하나씩 집어 용광로에 넣는다. 한 단어의 조각을 모두 넣었으면 두드린다.
## - 성공(용광로에 한 단어의 조각이 빠짐없이, 다른 조각 없이): 완성 단어가 나오고 캐릭터가 든다.
##   진열장의 주문(뜻) 칸에 올리면 그 단어 1개. 뜻이 다른 칸에 올리면 깨진다(실수).
## - 실패: 용광로 속 조각은 사라진다(나중에 창고에서 새로 나온다).
## 같은 단어의 조각은 같은 색이고, 깨진 면의 톱니가 서로 맞물린다(단어를 몰라도 한 단어임을 알 수 있다).
## 좌표는 0~1 비율. 벨트 위치 d는 고리 둘레를 따라 0~perimeter.

const BELT := Rect2(0.04, 0.08, 0.64, 0.42)  ## 고리 네모
const HIDE_X := 0.2  ## 이 x보다 왼쪽은 창고 벽에 가려 보이지 않는다
const FURNACE := Vector2(0.86, 0.2)
const ANVIL := Vector2(0.86, 0.46)
const SHELF_Y := 0.84

var items: Array[Dictionary] = []  ## 벨트 위 조각 {uid, w, piece, d}
var furnace: Array[Dictionary] = []  ## {w, piece}
var carry := {}  ## {} | {"w", "piece"}(조각) | {"word": w}(완성 단어)
var shelf: Array[int] = []  ## 진열장 주문 칸(단어 순번, -1 = 빈칸)
var orders: Array[int] = []  ## 앞으로 올 주문(단어 순번)
var hero := Vector2(0.8, 0.68)
var action := {}  ## 걸어가서 할 일 {kind: "pick"|"furnace"|"hammer"|"shelf", uid?, slot?}
var misses := 0
var events: Array[Dictionary] = []  ## 화면 알림 {kind, ok, w}
var _uid := 0
var _queue: Array[Dictionary] = []  ## 창고에서 나올 조각
var _spawn_t := 0.0


func _build() -> void:
	var idx: Array = range(words.size())
	idx.shuffle()
	for i in mini(int(cfg["orders"]), idx.size()):
		orders.append(idx[i])
	for k in int(cfg["shelf"]):
		shelf.append(orders.pop_front() if not orders.is_empty() else -1)
	# 처음 벨트: 주문 단어의 조각 + 다른 단어 조각을 고리에 고르게
	var start: Array[Dictionary] = []
	for w in shelf:
		if w >= 0:
			for p in pieces(w):
				start.append({"w": w, "piece": p})
	while start.size() < int(cfg["belt_size"]):
		var other: int = idx[rng.randi_range(0, idx.size() - 1)]
		start.append({"w": other, "piece": rng.randi_range(0, pieces(other) - 1)})
	start.shuffle()
	for k in start.size():
		_put(start[k], perimeter() * k / start.size())


## 단어가 깨진 조각 수(글자 수로 정한다).
func pieces(w: int) -> int:
	var n := words[w].id.length()
	return 2 if n <= 6 else 3


## 조각 p의 글자.
func piece_text(w: int, p: int) -> String:
	var s := words[w].id
	var n := pieces(w)
	var a := int(round(float(s.length()) * p / n))
	var b := int(round(float(s.length()) * (p + 1) / n))
	return s.substr(a, b - a)


func perimeter() -> float:
	return 2.0 * (BELT.size.x + BELT.size.y)


## 고리 위 d의 자리(위 변 왼→오, 오른쪽 변 위→아래, 아래 변 오→왼, 왼쪽 변 아래→위).
func belt_pos(d: float) -> Vector2:
	var w := BELT.size.x
	var h := BELT.size.y
	d = fposmod(d, perimeter())
	if d < w:
		return BELT.position + Vector2(d, 0)
	d -= w
	if d < h:
		return BELT.position + Vector2(w, d)
	d -= h
	if d < w:
		return BELT.position + Vector2(w - d, h)
	d -= w
	return BELT.position + Vector2(0, h - d)


func visible(it: Dictionary) -> bool:
	return belt_pos(it["d"]).x >= HIDE_X


func _put(frag: Dictionary, d: float) -> void:
	_uid += 1
	items.append({"uid": _uid, "w": frag["w"], "piece": frag["piece"], "d": d})


## 벨트 d 자리 앞뒤로 min_gap 안에 다른 조각이 없는가(조각끼리 겹치지 않게).
func gap_free(d: float) -> bool:
	var gap := float(cfg["min_gap"])
	for it in items:
		var diff := absf(fposmod(it["d"] - d + perimeter() / 2.0, perimeter()) - perimeter() / 2.0)
		if diff < gap:
			return false
	return true


func item_by_uid(uid: int) -> int:
	for i in items.size():
		if items[i]["uid"] == uid:
			return i
	return -1


## 화면에서 누른 것: 캐릭터가 걸어가서 한다.
func go_pick(uid: int) -> void:
	if not finished:
		action = {"kind": "pick", "uid": uid}


func go_furnace() -> void:
	if not finished:
		action = {"kind": "furnace"}


func go_hammer() -> void:
	if not finished:
		action = {"kind": "hammer"}


func go_shelf(k: int) -> void:
	if not finished:
		action = {"kind": "shelf", "slot": k}


func _target() -> Vector2:
	match action.get("kind", ""):
		"pick":
			var i := item_by_uid(action["uid"])
			return belt_pos(items[i]["d"]) + Vector2(0, 0.06) if i >= 0 else hero
		"furnace":
			return FURNACE + Vector2(0, 0.08)
		"hammer":
			return ANVIL + Vector2(-0.05, 0.04)
		"shelf":
			return shelf_pos(action["slot"]) + Vector2(0, -0.08)
	return hero


func shelf_pos(k: int) -> Vector2:
	return Vector2(0.14 + k * 0.24, SHELF_Y)


## 지금 할 일을 그 자리에서 한다(걸어가서 닿았을 때).
func act() -> void:
	var kind: String = action.get("kind", "")
	action = {}
	match kind:
		"pick":
			pass
		"furnace":
			if carry.has("piece"):
				furnace.append({"w": carry["w"], "piece": carry["piece"]})
				carry = {}
				events.append({"kind": "furnace", "ok": true})
		"hammer":
			_hammer()
		"shelf":
			pass


## 조각을 집는다(손이 비어 있고 보이는 조각만).
func pick(uid: int) -> bool:
	var i := item_by_uid(uid)
	if i < 0 or not carry.is_empty() or not visible(items[i]):
		if not carry.is_empty():
			events.append({"kind": "full", "ok": false})
		return false
	carry = {"w": items[i]["w"], "piece": items[i]["piece"]}
	items.remove_at(i)
	return true


func _hammer() -> void:
	if furnace.is_empty():
		return
	if not carry.is_empty():  # 손에 든 것부터 내려놓아야 한다
		events.append({"kind": "full", "ok": false})
		return
	var w: int = furnace[0]["w"]
	var got := {}
	var ok := true
	for f in furnace:
		if f["w"] != w or got.has(f["piece"]):
			ok = false
		got[f["piece"]] = true
	ok = ok and got.size() == pieces(w)
	if ok:
		carry = {"word": w}
	events.append({"kind": "hammer", "ok": ok, "w": w})
	furnace.clear()  # 실패하면 조각이 사라진다(창고에서 다시 나온다)


func place(k: int) -> bool:
	if not carry.has("word") or k < 0 or k >= shelf.size() or shelf[k] < 0:
		return false
	var w: int = carry["word"]
	carry = {}
	if words[shelf[k]].meaning == words[w].meaning:
		earn(words[w].id)
		events.append({"kind": "shelf", "ok": true, "w": w})
		shelf[k] = orders.pop_front() if not orders.is_empty() else -1
		if not shelf.any(func(x: int) -> bool: return x >= 0):
			finish()
		return true
	misses += 1
	events.append({"kind": "shelf", "ok": false, "w": w, "want": shelf[k]})
	if misses >= int(cfg["max_miss"]):
		finish()
	return false


## 주문 단어의 조각이 어디에도 없으면 창고에서 다시 나오게 한다.
func _refill() -> void:
	for w in shelf:
		if w < 0:
			continue
		for p in pieces(w):
			if not _exists(w, p):
				_queue.append({"w": w, "piece": p})
	if _queue.is_empty() and items.size() < int(cfg["belt_size"]):
		var other := rng.randi_range(0, words.size() - 1)
		_queue.append({"w": other, "piece": rng.randi_range(0, pieces(other) - 1)})


func _exists(w: int, p: int) -> bool:
	for it in items + furnace + _queue:
		if it["w"] == w and it["piece"] == p:
			return true
	return carry.get("w", -1) == w and carry.get("piece", -1) == p or carry.get("word", -1) == w


func _tick(dt: float) -> void:
	var sp := float(cfg["belt_speed"]) * dt
	for it in items:
		it["d"] = fposmod(it["d"] + sp, perimeter())
	_spawn_t -= dt
	if _spawn_t <= 0.0:
		_spawn_t = float(cfg["spawn_gap"])
		_refill()
	# 창고 안(왼쪽 변)에서 나온다. 빈자리가 지나갈 때만 올린다(조각끼리 겹치지 않게)
	var at := perimeter() - BELT.size.y * 0.5
	if not _queue.is_empty() and items.size() < int(cfg["belt_size"]) and gap_free(at):
		_put(_queue.pop_front(), at)
	if action.is_empty():
		return
	var to := _target()
	hero = hero.move_toward(to, float(cfg["hero_speed"]) * dt)
	if hero.distance_to(to) < 0.02:
		match action["kind"]:
			"pick":
				var uid: int = action["uid"]
				action = {}
				pick(uid)
			"shelf":
				var k: int = action["slot"]
				action = {}
				place(k)
			_:
				act()
