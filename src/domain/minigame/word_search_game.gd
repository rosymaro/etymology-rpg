class_name WordSearchGame
extends Minigame
## 3 망루 도서관 '책 읽기'(단어 찾기): 알파벳 격자에 숨은 단어를 찾는다(오른쪽·아래·오른쪽 아래 방향만). 뜻이 힌트.
## 너무 어렵지 않게, fade_every초마다 정답에 쓰이지 않는 글자를 하나씩 지운다(지운 칸은 removed). 끝나면 화면이 못 찾은 답을 보여 준다.

## 왼쪽 → 오른쪽, 위 → 아래, 왼쪽 위 → 오른쪽 아래로만 숨긴다(거꾸로는 너무 어렵다, 사용자 의견).
const DIRS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)]

var size: int
var grid: Array = []  ## [row][col] 글자
var placed: Array[Dictionary] = []  ## {id, start, dir, len}
var found: Array[String] = []
var removed: Dictionary = {}  ## Vector2i -> 지운 순서
var _fade_t := 0.0


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


## 정답 단어가 지나는 칸.
func answer_cells() -> Dictionary:
	var out := {}
	for p in placed:
		for i in int(p["len"]):
			out[p["start"] + p["dir"] * i] = p["id"]
	return out


func _tick(dt: float) -> void:
	_fade_t += dt
	var every := float(cfg.get("fade_every", 0))
	if every > 0.0 and _fade_t >= every:
		_fade_t -= every
		remove_one()


## 정답에 쓰이지 않는 글자 하나를 지운다. 지운 칸을 돌려준다(더 지울 칸이 없으면 (-1,-1)).
func remove_one() -> Vector2i:
	var keep := answer_cells()
	var cand: Array[Vector2i] = []
	for r in size:
		for c in size:
			var p := Vector2i(r, c)
			if not keep.has(p) and not removed.has(p):
				cand.append(p)
	if cand.is_empty():
		return Vector2i(-1, -1)
	var p := cand[rng.randi_range(0, cand.size() - 1)]
	removed[p] = removed.size() + 1
	return p


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
