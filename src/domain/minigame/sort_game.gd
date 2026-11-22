class_name SortGame
extends Minigame
## 8 성벽 요새 '보초 서기'(통 정렬): 섞인 패를 통에 옮겨 같은 무늬(속성)끼리 모은다. 맨 위 패만 옮긴다.
## 빈 통이나 맨 위가 같은 무늬인 통에만 놓을 수 있다. 한 통을 다 맞출 때마다 1개(그 무늬에 걸린 단어).

var colors: int
var per_tube: int
var tubes: Array = []  ## [통][아래→위] 무늬 번호
var color_attr: Array[int] = []  ## 무늬 번호 -> 속성 번호(그림용)
var done_colors: Dictionary = {}


func _build() -> void:
	colors = mini(int(cfg["colors"]), words.size())
	per_tube = int(cfg["per_tube"])
	var attrs: Array[int] = []
	for w in words:
		var a := w.primary_attr()
		if a > 0 and not a in attrs:
			attrs.append(a)
	for i in colors:
		color_attr.append(attrs[i] if i < attrs.size() else i + 1)
	tubes = []
	for c in colors:
		var t: Array[int] = []
		for k in per_tube:
			t.append(c)
		tubes.append(t)
	for e in int(cfg["empty_tubes"]):
		tubes.append([] as Array[int])
	_scramble(int(cfg["scramble"]))
	if all_sorted():
		_scramble(int(cfg["scramble"]))


## 거꾸로 섞기: 앞으로 할 수 있는 옮기기를 되감아서, 언제나 풀 수 있는 판을 만든다.
func _scramble(steps: int) -> void:
	for s in steps:
		var from := rng.randi_range(0, tubes.size() - 1)
		var to := rng.randi_range(0, tubes.size() - 1)
		if from == to or tubes[from].is_empty() or tubes[to].size() >= per_tube:
			continue
		var t: int = tubes[from][-1]
		# 되감기가 맞으려면, 옮긴 뒤 from이 비었거나 from의 새 맨 위가 같은 무늬여야 한다
		var rest: Array = tubes[from].slice(0, tubes[from].size() - 1)
		if rest.is_empty() or rest[-1] == t:
			tubes[from].pop_back()
			tubes[to].append(t)


func can_move(from: int, to: int) -> bool:
	if from == to or tubes[from].is_empty() or tubes[to].size() >= per_tube:
		return false
	return tubes[to].is_empty() or tubes[to][-1] == tubes[from][-1]


func move(from: int, to: int) -> bool:
	if finished or not can_move(from, to):
		return false
	tubes[to].append(tubes[from].pop_back())
	_check()
	return true


func _check() -> void:
	for t in tubes:
		if t.size() == per_tube:
			var c: int = t[0]
			var full := true
			for x in t:
				if x != c:
					full = false
			if full and not done_colors.has(c):
				done_colors[c] = true
				earn(words[c].id)
	if done_colors.size() >= colors:
		finish()


func all_sorted() -> bool:
	for t in tubes:
		for x in t:
			if x != t[0]:
				return false
		if not t.is_empty() and t.size() != per_tube:
			return false
	return true
