class_name PipeGame
extends Minigame
## 4 바람 협곡 '연날리기'(파이프 잇기): 바람길 타일을 돌려 왼쪽 연에서 오른쪽 하늘 끝까지 잇는다.
## 이어진 바람길 위에 걸린 단어마다 1개. 연결은 N=1 E=2 S=4 W=8 비트.

const N := 1
const E := 2
const S := 4
const W := 8

var rows: int
var cols: int
var tiles: Array = []  ## [r][c] 연결 비트
var word_at_cell: Dictionary = {}  ## Vector2i -> 단어 순번
var start_row: int
var end_row: int
var solution: Array[Vector2i] = []


func _build() -> void:
	rows = int(cfg["rows"])
	cols = int(cfg["cols"])
	tiles = []
	for r in rows:
		var row: Array[int] = []
		row.resize(cols)
		row.fill(0)
		tiles.append(row)
	start_row = rng.randi_range(0, rows - 1)
	solution = _random_path(Vector2i(start_row, 0))
	end_row = solution[-1].x
	for i in solution.size():
		var p := solution[i]
		var prev := Vector2i(p.x, p.y - 1) if i == 0 else solution[i - 1]
		var next := Vector2i(p.x, p.y + 1) if i == solution.size() - 1 else solution[i + 1]
		tiles[p.x][p.y] = _dir(p, prev) | _dir(p, next)
	var shapes := [N | S, N | E, N | E | S]
	for r in rows:
		for c in cols:
			if tiles[r][c] == 0:
				tiles[r][c] = shapes[rng.randi_range(0, shapes.size() - 1)]
	var order := range(solution.size())
	order.shuffle()
	for k in mini(int(cfg["words"]), mini(solution.size(), words.size())):
		word_at_cell[solution[order[k]]] = k
	for r in rows:
		for c in cols:
			for t in rng.randi_range(0, 3):
				rotate(Vector2i(r, c))
	if connected().has(Vector2i(end_row, cols - 1)) and _reaches_end():
		rotate(solution[0])


## 왼쪽 열에서 오른쪽 열까지 무작위로 가는 길(자기 자신을 지나지 않음).
func _random_path(start: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [start]
	var seen := {start: true}
	while true:
		var p := path[-1]
		if p.y == cols - 1 and rng.randf() < 0.5:
			break
		var opts: Array[Vector2i] = []
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
			var n: Vector2i = p + d
			if n.x >= 0 and n.x < rows and n.y >= 0 and n.y < cols and not seen.has(n):
				opts.append(n)
		if opts.is_empty():
			if p.y == cols - 1:
				break
			path = [start]
			seen = {start: true}
			continue
		var n := opts[rng.randi_range(0, opts.size() - 1)]
		path.append(n)
		seen[n] = true
	return path


func _dir(from: Vector2i, to: Vector2i) -> int:
	var d := to - from
	if d == Vector2i(-1, 0):
		return N
	if d == Vector2i(0, 1):
		return E
	if d == Vector2i(1, 0):
		return S
	return W


## 시계 방향으로 90도.
func rotate(p: Vector2i) -> void:
	var m: int = tiles[p.x][p.y]
	tiles[p.x][p.y] = ((m << 1) | (m >> 3)) & 15


func turn(p: Vector2i) -> void:
	if finished:
		return
	rotate(p)
	if _reaches_end():
		for c in connected():
			if word_at_cell.has(c):
				earn(words[word_at_cell[c]].id)
		finish()


## 연(왼쪽, start_row)에서 바람이 닿는 칸들.
func connected() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var s := Vector2i(start_row, 0)
	if not (tiles[s.x][s.y] & W):
		return out
	var seen := {s: true}
	var stack: Array[Vector2i] = [s]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		out.append(p)
		for pair in [[N, Vector2i(-1, 0), S], [E, Vector2i(0, 1), W], [S, Vector2i(1, 0), N], [W, Vector2i(0, -1), E]]:
			var n: Vector2i = p + pair[1]
			if tiles[p.x][p.y] & pair[0] and n.x >= 0 and n.y >= 0 and n.x < rows and n.y < cols \
					and tiles[n.x][n.y] & pair[2] and not seen.has(n):
				seen[n] = true
				stack.append(n)
	return out


func _reaches_end() -> bool:
	var e := Vector2i(end_row, cols - 1)
	return tiles[e.x][e.y] & E and connected().has(e)
