class_name TrapGame
extends Minigame
## 2 사냥꾼 초원 '덫 놓기'(지뢰찾기): 칸의 숫자 = 주변에 숨은 단어 수. 단어가 숨은 칸에 덫을 놓으면 1개.
## 빈 칸에 덫을 놓거나, 단어가 숨은 칸을 살피면(단어가 달아남) 판이 끝난다. 첫 살피기는 늘 안전하다.

var rows: int
var cols: int
var hidden: Dictionary = {}  ## Vector2i -> 단어 순번
var revealed: Dictionary = {}  ## Vector2i -> true
var trapped: Dictionary = {}
var _placed := false
var lost := false


func _build() -> void:
	rows = int(cfg["rows"])
	cols = int(cfg["cols"])


func count() -> int:
	return mini(int(cfg["words"]), words.size())


func _place(safe: Vector2i) -> void:
	_placed = true
	var cells: Array[Vector2i] = []
	for r in rows:
		for c in cols:
			var p := Vector2i(r, c)
			if absi(p.x - safe.x) > 1 or absi(p.y - safe.y) > 1:
				cells.append(p)
	cells.shuffle()
	for i in count():
		hidden[cells[i]] = i


## 테스트용: 숨길 곳을 정해 넣는다.
func place_at(cells: Array[Vector2i]) -> void:
	_placed = true
	hidden.clear()
	for i in cells.size():
		hidden[cells[i]] = i


func number(p: Vector2i) -> int:
	var n := 0
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if (dr != 0 or dc != 0) and hidden.has(p + Vector2i(dr, dc)):
				n += 1
	return n


func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < rows and p.y < cols


func reveal(p: Vector2i) -> void:
	if finished or revealed.has(p) or trapped.has(p):
		return
	if not _placed:
		_place(p)
	if hidden.has(p):
		lost = true
		finish()
		return
	var stack: Array[Vector2i] = [p]
	while not stack.is_empty():
		var q: Vector2i = stack.pop_back()
		if revealed.has(q) or not inside(q):
			continue
		revealed[q] = true
		if number(q) == 0:
			for dr in [-1, 0, 1]:
				for dc in [-1, 0, 1]:
					var n := q + Vector2i(dr, dc)
					if inside(n) and not revealed.has(n) and not hidden.has(n):
						stack.append(n)


func trap(p: Vector2i) -> void:
	if finished or revealed.has(p) or trapped.has(p):
		return
	if not _placed:
		_place(p)
	trapped[p] = true
	if hidden.has(p):
		earn(words[hidden[p]].id)
		if trapped.size() >= count():
			finish()
	else:
		lost = true
		finish()
