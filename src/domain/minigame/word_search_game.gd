class_name WordSearchGame
extends Minigame
## 3 망루 도서관 '책 읽기'(단어 찾기): 알파벳 격자에 가로·세로·대각선으로 숨은 단어를 찾는다. 뜻이 힌트.

const DIRS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(-1, 1),
	Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(1, -1)]

var size: int
var grid: Array = []  ## [row][col] 글자
var placed: Array[Dictionary] = []  ## {id, start, dir, len}
var found: Array[String] = []


func _build() -> void:
	size = int(cfg["size"])
	grid = []
	for r in size:
		var row: Array[String] = []
		row.resize(size)
		row.fill("")
		grid.append(row)
	var cand: Array[WordData] = []
	for w in words:
		if Minigame.letters_only(w, int(cfg["min_len"]), mini(int(cfg["max_len"]), size)):
			cand.append(w)
	cand.shuffle()
	for w in cand:
		if placed.size() >= int(cfg["words"]):
			break
		_try_place(w.id.to_lower())
	for r in size:
		for c in size:
			if grid[r][c] == "":
				grid[r][c] = char(97 + rng.randi_range(0, 25))


func _try_place(s: String) -> bool:
	for attempt in 120:
		var d: Vector2i = DIRS[rng.randi_range(0, DIRS.size() - 1)]
		var st := Vector2i(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1))
		var ok := true
		for i in s.length():
			var p := st + d * i
			if p.x < 0 or p.y < 0 or p.x >= size or p.y >= size:
				ok = false
				break
			var g: String = grid[p.x][p.y]
			if g != "" and g != s[i]:
				ok = false
				break
		if ok:
			for i in s.length():
				var p := st + d * i
				grid[p.x][p.y] = s[i]
			placed.append({"id": s, "start": st, "dir": d, "len": s.length()})
			return true
	return false


func hidden_ids() -> Array[String]:
	var out: Array[String] = []
	for p in placed:
		out.append(p["id"])
	return out


## 직선으로 고른 칸들의 글자. 직선이 아니면 "".
func read(a: Vector2i, b: Vector2i) -> String:
	var d := b - a
	var n := maxi(absi(d.x), absi(d.y))
	if n == 0 or not (d.x == 0 or d.y == 0 or absi(d.x) == absi(d.y)):
		return ""
	var step := Vector2i(signi(d.x), signi(d.y))
	var s := ""
	for i in n + 1:
		var p := a + step * i
		s += grid[p.x][p.y]
	return s


func select(a: Vector2i, b: Vector2i) -> String:
	var s := read(a, b)
	for p in placed:
		var id: String = p["id"]
		if not id in found and (s == id or s.reverse() == id):
			found.append(id)
			earn(_original(id))
			if found.size() >= placed.size():
				finish()
			return id
	return ""


func _original(lower: String) -> String:
	for w in words:
		if w.id.to_lower() == lower:
			return w.id
	return lower
