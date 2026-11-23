class_name PipeGame
extends Minigame
## 4 바람 협곡 '연날리기'(파이프 잇기): 바람길 타일을 돌려 왼쪽 연에서 오른쪽 하늘 끝까지 잇는다.
## 7×7 판, 정답 길은 min_path칸 이상. 단어 5개는 모두 정답 길 위에 있다(함정 없음).
## 단어 칸에는 영어 단어와 뜻이 적혀 있고, 돌릴 때마다 뜻이 바뀐다(정답 1 + 오답 3).
## 뜻이 맞게 돌린 방향이 정답 길의 방향이다(힌트). 하늘에 닿았을 때 단어를 모두 지나고 모두 맞는 뜻이면 성공.
## 일자 타일에는 화살표(>>>)가 있어서 바람은 화살표 쪽으로만 지나간다(반 바퀴 돌리면 방향이 바뀐다).
## 연결은 N=1 E=2 S=4 W=8 비트.

const N := 1
const E := 2
const S := 4
const W := 8

var rows: int
var cols: int
var tiles: Array = []  ## [r][c] 연결 비트
var turns: Dictionary = {}  ## Vector2i -> 돌린 횟수(0~3), 정답 방향이 0
var arrows: Dictionary = {}  ## Vector2i -> 일자 타일 화살표가 가리키는 쪽(N/E/S/W 비트)
var word_at_cell: Dictionary = {}  ## Vector2i -> 단어 순번
var meanings: Dictionary = {}  ## Vector2i -> [정답 뜻, 오답 3]  (turns 값으로 고른다)
var start_row: int
var end_row: int
var solution: Array[Vector2i] = []
var targets := 0
var last_judge := ""  ## 하늘에 닿았을 때: "" | "ok" | "missing" | "meaning"
var _budget := 0


func _build() -> void:
	rows = int(cfg["rows"])
	cols = int(cfg["cols"])
	tiles = []
	for r in rows:
		var row: Array[int] = []
		row.resize(cols)
		row.fill(0)
		tiles.append(row)
	# 정답 길이 짧으면 쉬워서(사용자 의견) min_path칸 이상인 길을 찾는다
	for k in 200:
		start_row = rng.randi_range(0, rows - 1)
		solution = _long_path(Vector2i(start_row, 0), int(cfg.get("min_path", 0)))
		if not solution.is_empty():
			break
	end_row = solution[-1].x
	for i in solution.size():
		var p := solution[i]
		var prev := Vector2i(p.x, p.y - 1) if i == 0 else solution[i - 1]
		var next := Vector2i(p.x, p.y + 1) if i == solution.size() - 1 else solution[i + 1]
		tiles[p.x][p.y] = _dir(p, prev) | _dir(p, next)
		if is_straight(p):
			arrows[p] = _dir(p, next)  # 바람이 가는 쪽
	var shapes := [N | S, N | E, N | E | S]
	for r in rows:
		for c in cols:
			turns[Vector2i(r, c)] = 0
			if tiles[r][c] == 0:
				tiles[r][c] = shapes[rng.randi_range(0, shapes.size() - 1)]
				if is_straight(Vector2i(r, c)):
					arrows[Vector2i(r, c)] = N if rng.randf() < 0.5 else S
	# 단어는 모두 정답 길 위에, 길 전체에 고르게 흩어 둔다
	targets = mini(int(cfg["words"]), mini(solution.size(), words.size()))
	for k in targets:
		var at := solution[int((k + 0.5) * solution.size() / targets)]
		word_at_cell[at] = k
		meanings[at] = [words[k].meaning] + _wrong_meanings(k, 3)
	for r in rows:
		for c in cols:
			for t in rng.randi_range(0, 3):
				rotate(Vector2i(r, c))
	for p in word_at_cell:  # 처음부터 맞는 뜻이 보이지 않게 한다
		if turns[p] == 0:
			rotate(p)


func _wrong_meanings(k: int, n: int) -> Array:
	var out: Array = []
	var idx := range(words.size())
	idx.shuffle()
	for i in idx:
		if out.size() >= n:
			break
		if i != k and words[i].meaning != words[k].meaning and not words[i].meaning in out:
			out.append(words[i].meaning)
	while out.size() < n:
		out.append("?")
	return out


## 지금 보이는 뜻.
func shown_meaning(p: Vector2i) -> String:
	return meanings[p][turns[p]] if meanings.has(p) else ""


## 왼쪽 열에서 오른쪽 열까지, 자기 자신을 지나지 않고 min_len칸 이상인 길(무작위 깊이 우선 + 되돌아가기).
func _long_path(start: Vector2i, min_len: int) -> Array[Vector2i]:
	_budget = 6000
	var path: Array[Vector2i] = [start]
	var seen := {start: true}
	if _dfs(path, seen, min_len):
		return path
	return [] as Array[Vector2i]


func _dfs(path: Array[Vector2i], seen: Dictionary, min_len: int) -> bool:
	_budget -= 1
	if _budget <= 0:
		return false
	var p := path[-1]
	if p.y == cols - 1 and path.size() >= min_len:
		return true
	var dirs := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]
	dirs.shuffle()
	for d in dirs:
		var n: Vector2i = p + d
		if n.x < 0 or n.x >= rows or n.y < 0 or n.y >= cols or seen.has(n):
			continue
		# 첫 칸은 연(왼쪽)에서 들어오므로 첫 열에서 왼쪽으로는 나갈 수 없다
		path.append(n)
		seen[n] = true
		if _dfs(path, seen, min_len):
			return true
		path.pop_back()
		seen.erase(n)
	return false


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
func is_straight(p: Vector2i) -> bool:
	var m: int = tiles[p.x][p.y]
	return m == (N | S) or m == (E | W)


static func _rot(m: int) -> int:
	return ((m << 1) | (m >> 3)) & 15


func rotate(p: Vector2i) -> void:
	tiles[p.x][p.y] = _rot(tiles[p.x][p.y])
	if arrows.has(p):
		arrows[p] = _rot(arrows[p])
	turns[p] = (int(turns.get(p, 0)) + 1) % 4


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


## 바람이 지나는 칸들을 보고 판정한다: 단어가 빠지면 "missing", 뜻이 틀린 단어가 있으면 "meaning", 아니면 "ok".
func judge(cells: Array[Vector2i]) -> String:
	var hit := {}
	for c in cells:
		if word_at_cell.has(c):
			hit[c] = true
	if hit.size() < word_at_cell.size():
		return "missing"
	for c in hit:
		if turns[c] != 0:
			return "meaning"
	return "ok"


## 연(왼쪽, start_row)에서 바람이 닿는 칸들.
func connected() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var s := Vector2i(start_row, 0)
	if not (tiles[s.x][s.y] & W) or not _can_enter(s, E):
		return out
	var seen := {s: true}
	var stack: Array[Vector2i] = [s]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		out.append(p)
		for pair in [[N, Vector2i(-1, 0), S], [E, Vector2i(0, 1), W], [S, Vector2i(1, 0), N], [W, Vector2i(0, -1), E]]:
			var n: Vector2i = p + pair[1]
			if tiles[p.x][p.y] & pair[0] and _can_leave(p, pair[0]) and n.x >= 0 and n.y >= 0 and n.x < rows and n.y < cols \
					and tiles[n.x][n.y] & pair[2] and _can_enter(n, pair[0]) and not seen.has(n):
				seen[n] = true
				stack.append(n)
	return out


## 일자 타일은 화살표 쪽으로만 나간다.
func _can_leave(p: Vector2i, side: int) -> bool:
	return not arrows.has(p) or not is_straight(p) or arrows[p] == side


## 바람이 move 쪽으로 움직여 들어올 때, 일자 타일이면 화살표가 같은 쪽이어야 한다.
func _can_enter(p: Vector2i, move: int) -> bool:
	return not arrows.has(p) or not is_straight(p) or arrows[p] == move


func _reaches_end() -> bool:
	var e := Vector2i(end_row, cols - 1)
	return tiles[e.x][e.y] & E and _can_leave(e, E) and connected().has(e)
