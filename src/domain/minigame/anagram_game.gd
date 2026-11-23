class_name AnagramGame
extends Minigame
## 6 왕성 '필사'(애너그램 + 얼음 깨기): 섞인 글자 타일이 얼음에 갇혀 있다. 두드려 얼음을 깨야(ice_hp번) 끌어서 움직일 수 있다.
## 깬 글자를 끌어 칸에 놓아 바른 철자를 만든다. 뜻과 어원이 힌트. 맞힌 단어마다 1개.
## 칸이 다 차면 판정한다. 틀리면 글자가 아래로 돌아가고(얼음은 깨진 채) tries번이면 다음 단어.

var queue: Array[WordData] = []
var index := 0
var tiles: Array[String] = []  ## 섞인 글자
var ice: Array[int] = []  ## 글자마다 남은 얼음(0이면 깨짐)
var slots: Array[int] = []  ## 칸마다 놓인 타일 순번(-1 = 빈칸)
var tries_left := 0
var last := ""  ## "" | "right" | "wrong" | "skip"
var last_word := ""


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
	ice.clear()
	slots.clear()
	for i in tiles.size():
		ice.append(int(cfg.get("ice_hp", 2)))
		slots.append(-1)
	tries_left = int(cfg["tries"])


## 얼음을 두드린다. 남은 얼음 수를 돌려준다.
func hit(i: int) -> int:
	if finished or i < 0 or i >= ice.size():
		return -1
	ice[i] = maxi(0, ice[i] - 1)
	return ice[i]


func slot_of(i: int) -> int:
	return slots.find(i)


## 타일 i를 칸 k에 놓는다(얼음이 깨진 것만). 칸에 다른 글자가 있으면 그 글자는 아래로 돌아간다.
func put(i: int, k: int) -> bool:
	if finished or i < 0 or i >= tiles.size() or k < 0 or k >= slots.size() or ice[i] > 0:
		return false
	var from := slot_of(i)
	if from >= 0:
		slots[from] = -1
	slots[k] = i
	if not -1 in slots:
		_judge()
	return true


## 칸 k의 글자를 아래로 되돌린다.
func take(k: int) -> void:
	if k >= 0 and k < slots.size():
		slots[k] = -1


func typed() -> String:
	var s := ""
	for i in slots:
		s += tiles[i] if i >= 0 else "_"
	return s


func _judge() -> void:
	last_word = current().id
	if typed() == current().id.to_lower():
		last = "right"
		earn(current().id)
		_advance()
		return
	tries_left -= 1
	for k in slots.size():
		slots[k] = -1
	if tries_left <= 0:
		last = "skip"
		_advance()
	else:
		last = "wrong"


func skip() -> void:
	last_word = current().id if current() else ""
	last = "skip"
	_advance()


func _advance() -> void:
	index += 1
	if index >= queue.size() or finished:
		finish()
	else:
		_load()
