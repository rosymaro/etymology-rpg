class_name LetterGrid
extends RefCounted
## 단어찾기 글자판(05-minigames '말 공방' 단어찾기). 단어를 직선으로 숨기고 남은 칸은 아무 글자로 채운다.
## 기본은 → ↓ ↘ 세 방향만. reverse면 거꾸로(← ↑ ↖)와 ↗ ↙까지 여덟 방향(미니게임 10).
## 칸 좌표는 Vector2i(행, 열).

const FORWARD := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)]
const ALL := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, -1),
	Vector2i(1, -1), Vector2i(-1, 1)]

var size := 0
var grid: Array = []  ## [행][열] 글자
var placed: Array[Dictionary] = []  ## {id, start, dir, len}
var found: Array[String] = []
var reverse := false


## ids: 숨길 단어(소문자 영어). 다 들어가지 않으면 판을 키워 다시 한다.
static func make(ids: Array[String], min_size: int, max_size: int, reverse_ok: bool, rng: RandomNumberGenerator) -> LetterGrid:
	var longest := 0
	for id in ids:
		longest = maxi(longest, id.length())
	var n := clampi(maxi(min_size, longest), min_size, maxi(max_size, longest))
	while true:
		for attempt in 6:
			var g := LetterGrid.new()
			g.reverse = reverse_ok
			if g._fill(ids, n, rng):
				return g
		if n >= maxi(max_size, longest) + 4:
			break
		n += 1
	var last := LetterGrid.new()  # 끝내 다 못 넣으면 들어간 것만
	last.reverse = reverse_ok
	last._fill(ids, n, rng, true)
	return last


func _fill(ids: Array[String], n: int, rng: RandomNumberGenerator, partial := false) -> bool:
	size = n
	grid = []
	placed.clear()
	for r in n:
		var row: Array[String] = []
		row.resize(n)
		row.fill("")
		grid.append(row)
	var order := ids.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())  # 긴 단어부터
	for id in order:
		if not _place(id, rng) and not partial:
			return false
	for r in n:
		for c in n:
			if grid[r][c] == "":
				grid[r][c] = char(97 + rng.randi_range(0, 25))
	return true


func _place(s: String, rng: RandomNumberGenerator) -> bool:
	var dirs: Array = ALL if reverse else FORWARD
	for attempt in 200:
		var d: Vector2i = dirs[rng.randi_range(0, dirs.size() - 1)]
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


func ids() -> Array[String]:
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
	if a.x < 0 or a.y < 0 or b.x < 0 or b.y < 0 or a.x >= size or a.y >= size or b.x >= size or b.y >= size:
		return ""
	var step := Vector2i(signi(d.x), signi(d.y))
	var s := ""
	for i in n + 1:
		var p := a + step * i
		s += grid[p.x][p.y]
	return s


## a에서 b까지 고른 칸이 숨긴 단어면 그 단어(처음 찾았을 때만). 끝에서 처음으로 끌어도 된다.
func select(a: Vector2i, b: Vector2i) -> String:
	var s := read(a, b)
	if s == "":
		return ""
	for p in placed:
		var id: String = p["id"]
		if not id in found and (s == id or s.reverse() == id):
			found.append(id)
			return id
	return ""


func cells_of(id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in placed:
		if p["id"] == id:
			for i in int(p["len"]):
				out.append(p["start"] + p["dir"] * i)
	return out


func all_found() -> bool:
	return found.size() >= placed.size()
