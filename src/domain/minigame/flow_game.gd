class_name FlowGame
extends Minigame
## 10 갈라진 탑 '문양 잇기'(선 잇기): 같은 문양 조각 두 개를 선으로 잇는다. 선끼리 겹치면 안 되고 모든 칸을 채운다.
## 판은 칸을 모두 지나는 한 줄(해밀턴 경로)을 무작위로 만들고 잘라서 만든다. 그래서 늘 풀 수 있다.
## 이어진 선마다 그 문양에 갇혀 있던 단어 1개.

var size: int
var pairs: int
var ends: Array = []  ## [쌍] = [Vector2i, Vector2i]
var paths: Array = []  ## [쌍] = Array[Vector2i] (처음 끝점부터)
var owner: Dictionary = {}  ## Vector2i -> 쌍 번호(선이 지나는 칸)
var solution: Array = []
var _active := -1


func _build() -> void:
	size = int(cfg["size"])
	pairs = mini(int(cfg["pairs"]), words.size())
	var path := _hamilton(int(cfg["shuffle"]))
	var lens := _cut(path.size(), pairs, int(cfg["min_len"]))
	var i := 0
	for k in pairs:
		var seg: Array[Vector2i] = []
		for j in lens[k]:
			seg.append(path[i])
			i += 1
		solution.append(seg)
		ends.append([seg[0], seg[-1]])
		paths.append([] as Array[Vector2i])


## 지그재그 경로에서 시작해 '뒤로 물기(backbite)'를 되풀이해 섞는다.
func _hamilton(steps: int) -> Array[Vector2i]:
	var p: Array[Vector2i] = []
	for r in size:
		for c in size:
			p.append(Vector2i(r, c if r % 2 == 0 else size - 1 - c))
	for s in steps:
		if rng.randf() < 0.5:
			p.reverse()
		var end := p[-1]
		var nb: Array[Vector2i] = []
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
			var n: Vector2i = end + d
			if n.x >= 0 and n.y >= 0 and n.x < size and n.y < size and n != p[-2]:
				nb.append(n)
		if nb.is_empty():
			continue
		var pick := nb[rng.randi_range(0, nb.size() - 1)]
		var k := p.find(pick)
		var np: Array[Vector2i] = []
		for j in k + 1:
			np.append(p[j])
		for j in range(p.size() - 1, k, -1):
			np.append(p[j])
		p = np
	return p


func _cut(total: int, k: int, min_len: int) -> Array[int]:
	var lens: Array[int] = []
	lens.resize(k)
	lens.fill(min_len)
	for x in total - min_len * k:
		lens[rng.randi_range(0, k - 1)] += 1
	return lens


func endpoint_of(p: Vector2i) -> int:
	for k in ends.size():
		if p == ends[k][0] or p == ends[k][1]:
			return k
	return -1


## 끝점에서 선을 새로 시작한다(그 쌍의 옛 선은 지운다).
func begin(p: Vector2i) -> bool:
	var k := endpoint_of(p)
	if finished or k < 0:
		return false
	_clear(k)
	_active = k
	paths[k] = [p] as Array[Vector2i]
	owner[p] = k
	return true


## 지금 선을 이웃 칸으로 늘인다. 바로 앞 칸으로 돌아가면 한 칸 지운다.
func extend(p: Vector2i) -> bool:
	if finished or _active < 0:
		return false
	var path: Array[Vector2i] = paths[_active]
	var last := path[-1]
	if absi(p.x - last.x) + absi(p.y - last.y) != 1:
		return false
	if path.size() >= 2 and p == path[-2]:
		owner.erase(path.pop_back())
		return true
	if is_connected_pair(_active):
		return false
	var ep := endpoint_of(p)
	if owner.has(p) or (ep >= 0 and ep != _active):
		return false
	path.append(p)
	owner[p] = _active
	return true


func end_stroke() -> void:
	_active = -1
	if all_done():
		_award()
		finish()


func is_connected_pair(k: int) -> bool:
	var path: Array = paths[k]
	if path.size() < 2:
		return false
	var a: Vector2i = ends[k][0]
	var b: Vector2i = ends[k][1]
	return (path[0] == a and path[-1] == b) or (path[0] == b and path[-1] == a)


func connected_count() -> int:
	var n := 0
	for k in pairs:
		if is_connected_pair(k):
			n += 1
	return n


func all_done() -> bool:
	return connected_count() == pairs and owner.size() == size * size


## 그만두면 지금 이어진 선만큼 얻는다.
func give_up() -> void:
	_award()
	finish()


func _award() -> void:
	for k in pairs:
		if is_connected_pair(k):
			earn(words[k].id)


func _clear(k: int) -> void:
	for c in paths[k]:
		owner.erase(c)
	paths[k] = [] as Array[Vector2i]
