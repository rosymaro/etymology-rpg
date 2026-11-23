class_name PipeGame
extends Minigame
## 4 바람 협곡 '연날리기'(파이프 잇기): 바람길 타일을 돌려 왼쪽 연에서 오른쪽 하늘 끝까지 잇는다.
## 판에는 단어 words+decoys개(정답 5, 함정 3). 옆에 정답 단어의 뜻이 나온다.
## 하늘에 닿았을 때 바람길이 정답을 모두 지나고 함정을 하나도 지나지 않으면 성공(정답 모두 얻음).
## 함정이 섞이거나 정답이 빠지면 오답을 알려 주고 계속한다. 연결은 N=1 E=2 S=4 W=8 비트.

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
var targets := 0  ## 정답 단어 수(단어 순번 0..targets-1이 정답, 그 뒤가 함정)
var last_judge := ""  ## 하늘에 닿았을 때 판정: "" | "ok" | "trap" | "missing"


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
	# 정답은 정답 길 위에, 함정은 길 밖에 둔다(정답 길로 돌리면 함정을 지나지 않는다)
	var order := range(solution.size())
	order.shuffle()
	targets = mini(int(cfg["words"]), mini(solution.size(), words.size()))
	for k in targets:
		word_at_cell[solution[order[k]]] = k
	var off: Array[Vector2i] = []
	for r in rows:
		for c in cols:
			if not Vector2i(r, c) in solution:
				off.append(Vector2i(r, c))
	off.shuffle()
	for k in mini(int(cfg.get("decoys", 0)), mini(off.size(), words.size() - targets)):
		word_at_cell[off[k]] = targets + k
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
	last_judge = ""
	if _reaches_end():
		last_judge = judge(connected())
		if last_judge == "ok":
			for k in targets:
				earn(words[k].id)
			finish()


## 바람이 지나는 칸들을 보고 판정한다: 함정이 있으면 "trap", 정답이 빠지면 "missing", 아니면 "ok".
func judge(cells: Array[Vector2i]) -> String:
	var hit := {}
	for c in cells:
		if word_at_cell.has(c):
			hit[word_at_cell[c]] = true
	for k in hit:
		if k >= targets:
			return "trap"
	for k in targets:
		if not hit.has(k):
			return "missing"
	return "ok"


func is_decoy(cell: Vector2i) -> bool:
	return word_at_cell.has(cell) and word_at_cell[cell] >= targets


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
