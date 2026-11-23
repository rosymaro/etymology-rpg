class_name CryptexGame
extends Minigame
## 7 소용돌이 호수 '물레방아'(회전 고리): 바깥 고리(단어)와 안쪽 고리(뜻)를 돌려 수문 세 곳에서 단어와 뜻을 맞춘다.
## 돌리기만 해서는 맞지 않는다: 맞췄다고 생각하면 '수문 열기'(open_gates)를 누른다. 바퀴마다 tries번까지.
## 세 수문이 모두 맞으면 바퀴가 돌고 1개, 다 틀리면 답을 보여 주고(revealed) 그 바퀴는 놓친다.

var n: int
var gates: Array[int] = []
var outer: Array[String] = []  ## 단어 id
var inner: Array[String] = []  ## 뜻
var outer_rot := 0
var inner_rot := 0
var rounds_done := 0
var _answer_word := ""
var tries_left := 0
var revealed := false  ## 이번 바퀴를 놓쳐서 답을 보여 주는 중
var last := ""  ## "right" | "wrong" | "lost" | ""


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
	tries_left = int(cfg["tries"])
	revealed = false
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
	if not revealed:
		outer_rot = posmod(outer_rot + step, n)


func turn_inner(step: int) -> void:
	if not revealed:
		inner_rot = posmod(inner_rot + step, n)


## 수문을 연다. 맞으면 1개, 틀리면 시도가 줄고, 다 쓰면 맞는 자리로 돌려 답을 보여 준다(그 바퀴는 놓침).
func open_gates() -> String:
	if finished or revealed:
		return ""
	if solved():
		earn(outer_at(gates[0]))
		last = "right"
		round_done()
		return last
	tries_left -= 1
	if tries_left > 0:
		last = "wrong"
		return last
	for k in n:
		inner_rot = k
		if solved():
			break
	revealed = true
	last = "lost"
	return last


## 답을 본 뒤 다음 바퀴로.
func next_round() -> void:
	if revealed:
		round_done()


func round_done() -> void:
	rounds_done += 1
	if rounds_done >= int(cfg["rounds"]) or finished:
		finish()
	else:
		_new_round()
