class_name RootLinkGame
extends Minigame
## 10 갈라진 탑 '문양 잇기'(갈라진 말뿌리 잇기, 줄긋기): 왼쪽에 단어, 오른쪽에 갈라진 어원 풀이(예: con-(함께) + fer(나르다)).
## 단어와 그 어원을 선으로 이으면 1개. 틀리게 이으면 실수(max_miss번이면 끝). 어원이 둘 이상인 단어만 쓴다.

var left: Array[int] = []  ## 단어 순번(왼쪽 위에서 아래)
var right: Array[int] = []  ## 같은 단어들의 어원 풀이 순서(섞음)
var linked: Dictionary = {}  ## 왼쪽 칸 -> 오른쪽 칸
var misses := 0


func _build() -> void:
	for i in words.size():
		if words[i].etym.size() >= 2 and left.size() < int(cfg["pairs"]):
			left.append(i)
	right = left.duplicate()
	right.shuffle()


static func etym_text(w: WordData) -> String:
	var parts: Array[String] = []
	for e in w.etym:
		parts.append("%s(%s)" % [e.get("root", ""), e.get("meaning", "")])
	return " + ".join(parts)


## 왼쪽 a번 칸과 오른쪽 b번 칸을 잇는다.
func link(a: int, b: int) -> bool:
	if finished or linked.has(a) or b in linked.values() or a >= left.size() or b >= right.size():
		return false
	if left[a] == right[b]:
		linked[a] = b
		earn(words[left[a]].id)
		if linked.size() >= left.size():
			finish()
		return true
	misses += 1
	if misses >= int(cfg["max_miss"]):
		finish()
	return false
