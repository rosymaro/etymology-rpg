class_name CryptexGame
extends Minigame
## 7 소용돌이 호수 '물레방아'(회전 고리): 바깥 고리(단어)와 안쪽 고리(뜻)를 돌려 수문 세 곳에서 단어와 뜻을 맞춘다.
## 세 수문이 모두 맞으면 바퀴가 한 바퀴 돌고 1개를 얻는다. 다음 바퀴가 나온다.

var n: int
var gates: Array[int] = []
var outer: Array[String] = []  ## 단어 id
var inner: Array[String] = []  ## 뜻
var outer_rot := 0
var inner_rot := 0
var rounds_done := 0
var _answer_word := ""


func _build() -> void:
	n = int(cfg["ring"])
	for g in cfg["gates"]:
		gates.append(int(g))
	_new_round()


func _new_round() -> void:
	var pool := words.duplicate()
	pool.shuffle()
	var ring: Array[WordData] = []
	for i in mini(n, pool.size()):
		ring.append(pool[i])
	n = ring.size()
	outer.clear()
	for w in ring:
		outer.append(w.id)
	# 안쪽 고리: 수문 자리에는 비밀 차이 d만큼 돌렸을 때 맞는 뜻, 나머지 자리에는 다른 단어의 뜻
	var d := rng.randi_range(1, n - 1)
	inner.clear()
	inner.resize(n)
	inner.fill("")
	for g in gates:
		if g < n:
			inner[(g + d) % n] = _meaning(outer[g])
	var decoys: Array[String] = []
	for w in words:
		if not w.id in outer:
			decoys.append(w.meaning)
	decoys.shuffle()
	var k := 0
	for i in n:
		if inner[i] == "":
			inner[i] = decoys[k] if k < decoys.size() else _meaning(outer[(i + 1) % n])
			k += 1
	outer_rot = 0
	inner_rot = 0
	_answer_word = outer[gates[0]] if not gates.is_empty() else ""
	# 처음부터 맞지 않게
	if solved():
		inner_rot = 1


func _meaning(id: String) -> String:
	for w in words:
		if w.id == id:
			return w.meaning
	return ""


## 자리 p(0..n-1)에 보이는 단어와 뜻.
func outer_at(p: int) -> String:
	return outer[posmod(p + outer_rot, n)]


func inner_at(p: int) -> String:
	return inner[posmod(p + inner_rot, n)]


func gate_ok(p: int) -> bool:
	return _meaning(outer_at(p)) == inner_at(p)


func solved() -> bool:
	for g in gates:
		if g < n and not gate_ok(g):
			return false
	return true


func turn_outer(step: int) -> void:
	outer_rot = posmod(outer_rot + step, n)
	_check()


func turn_inner(step: int) -> void:
	inner_rot = posmod(inner_rot + step, n)
	_check()


func _check() -> void:
	if finished or not solved():
		return
	earn(outer_at(gates[0]))
	rounds_done += 1
	if rounds_done >= int(cfg["rounds"]) or finished:
		finish()
	else:
		_new_round()
