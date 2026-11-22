class_name AnagramGame
extends Minigame
## 6 왕성 '필사'(애너그램): 섞인 글자 타일을 바른 철자로 늘어놓는다. 뜻과 어원이 힌트. 맞힌 단어마다 1개.

var queue: Array[WordData] = []
var index := 0
var tiles: Array[String] = []  ## 섞인 글자
var used: Array[int] = []  ## 고른 타일 순번
var tries_left := 0
var last_ok := false


func _build() -> void:
	for w in words:
		if Minigame.letters_only(w, int(cfg["min_len"]), int(cfg["max_len"])):
			queue.append(w)
		if queue.size() >= int(cfg["words"]):
			break
	if queue.is_empty():
		finish()
		return
	_load()


func current() -> WordData:
	return queue[index] if index < queue.size() else null


func _load() -> void:
	var s := current().id.to_lower()
	tiles.clear()
	for ch in s:
		tiles.append(ch)
	var guard := 0
	while "".join(tiles) == s and guard < 20:
		tiles.shuffle()
		guard += 1
	used.clear()
	tries_left = int(cfg["tries"])


func typed() -> String:
	var s := ""
	for i in used:
		s += tiles[i]
	return s


## 타일을 하나 고른다. 다 고르면 맞는지 본다. 돌려주는 값: "" 진행 중, "right", "wrong", "skip"
func pick(i: int) -> String:
	if finished or i in used:
		return ""
	used.append(i)
	if used.size() < tiles.size():
		return ""
	if typed() == current().id.to_lower():
		earn(current().id)
		_advance()
		return "right"
	tries_left -= 1
	used.clear()
	if tries_left <= 0:
		_advance()
		return "skip"
	return "wrong"


func undo() -> void:
	if not used.is_empty():
		used.pop_back()


func skip() -> void:
	_advance()


func _advance() -> void:
	index += 1
	if index >= queue.size() or finished:
		finish()
	else:
		_load()
