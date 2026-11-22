class_name Match3Game
extends Minigame
## 5 항구 도시 '낚시'(3개 맞추기): 이웃한 물고기를 바꿔 같은 물고기 3개 이상을 줄지어 터뜨린다.
## 터뜨린 물고기만큼 낚싯줄 게이지가 차고, 게이지가 찰 때마다 1개. 바꾸기 횟수 제한.

var size: int
var kinds: int
var board: Array = []  ## [r][c] 0..kinds-1
var moves_left: int
var gauge := 0
var last_cleared := 0


func _build() -> void:
	size = int(cfg["size"])
	kinds = int(cfg["kinds"])
	moves_left = int(cfg["moves"])
	board = []
	for r in size:
		var row: Array[int] = []
		for c in size:
			var k := rng.randi_range(0, kinds - 1)
			while (c >= 2 and row[c - 1] == k and row[c - 2] == k) or (r >= 2 and board[r - 1][c] == k and board[r - 2][c] == k):
				k = rng.randi_range(0, kinds - 1)
			row.append(k)
		board.append(row)


func set_board(b: Array) -> void:
	board = b
	size = b.size()


func _swap(a: Vector2i, b: Vector2i) -> void:
	var t: int = board[a.x][a.y]
	board[a.x][a.y] = board[b.x][b.y]
	board[b.x][b.y] = t


## 줄지어 3개 이상인 칸들.
func matches() -> Dictionary:
	var hit := {}
	for r in size:
		for c in size:
			var k: int = board[r][c]
			if k < 0:
				continue
			if c + 2 < size and board[r][c + 1] == k and board[r][c + 2] == k:
				for i in 3:
					hit[Vector2i(r, c + i)] = true
			if r + 2 < size and board[r + 1][c] == k and board[r + 2][c] == k:
				for i in 3:
					hit[Vector2i(r + i, c)] = true
	return hit


## 이웃한 두 칸을 바꾼다. 맞는 줄이 안 생기면 되돌리고 false.
func swap(a: Vector2i, b: Vector2i) -> bool:
	if finished or (absi(a.x - b.x) + absi(a.y - b.y)) != 1:
		return false
	_swap(a, b)
	if matches().is_empty():
		_swap(a, b)
		return false
	moves_left -= 1
	last_cleared = 0
	var hit := matches()
	while not hit.is_empty():
		last_cleared += hit.size()
		for p in hit:
			board[p.x][p.y] = -1
		_fall()
		hit = matches()
	gauge += last_cleared
	var per := int(cfg["gauge_per_word"])
	while gauge >= per and earned.size() < max_words and earned.size() < words.size():
		gauge -= per
		earn(words[earned.size()].id)
	if moves_left <= 0:
		finish()
	return true


func _fall() -> void:
	for c in size:
		var col: Array[int] = []
		for r in range(size - 1, -1, -1):
			if board[r][c] >= 0:
				col.append(board[r][c])
		for r in range(size - 1, -1, -1):
			var i := size - 1 - r
			board[r][c] = col[i] if i < col.size() else rng.randi_range(0, kinds - 1)
