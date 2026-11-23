class_name MemoryGame
extends Minigame
## 2 사냥꾼 초원 '덫 놓기'(짝 맞추기·카드 뒤집기): 풀숲에 덫(카드)이 엎어져 있다. 한 덫에는 영어 단어, 다른 덫에는 그 뜻.
## 두 개를 열어 단어와 뜻이 짝이면 걸린다(1개). 아니면 잠깐 보여 준 뒤 다시 덮는다. 시간 제한.

var cards: Array[Dictionary] = []  ## {w: 단어 순번, side: "word"|"meaning", open, done}
var _first := -1
var mismatch: Array[int] = []  ## 방금 틀린 두 장(화면이 잠깐 보여 주고 close_mismatch로 덮는다)
var tries := 0


func _build() -> void:
	var n := mini(int(cfg["pairs"]), words.size())
	for i in n:
		cards.append({"w": i, "side": "word", "open": false, "done": false})
		cards.append({"w": i, "side": "meaning", "open": false, "done": false})
	cards.shuffle()


func pairs() -> int:
	return cards.size() / 2


func label(i: int) -> String:
	var w := words[cards[i]["w"]]
	return w.id if cards[i]["side"] == "word" else w.meaning


## 덫 하나를 연다. 돌려주는 값: "open"(첫 장), "match", "miss", ""(못 엶)
func flip(i: int) -> String:
	if finished or i < 0 or i >= cards.size() or cards[i]["open"] or cards[i]["done"]:
		return ""
	if not mismatch.is_empty():
		close_mismatch()
	cards[i]["open"] = true
	if _first < 0:
		_first = i
		return "open"
	var a := _first
	_first = -1
	tries += 1
	if cards[a]["w"] == cards[i]["w"]:
		cards[a]["done"] = true
		cards[i]["done"] = true
		earn(words[cards[i]["w"]].id)
		if _all_done():
			finish()
		return "match"
	mismatch = [a, i]
	return "miss"


func close_mismatch() -> void:
	for k in mismatch:
		cards[k]["open"] = false
	mismatch.clear()


func _all_done() -> bool:
	for c in cards:
		if not c["done"]:
			return false
	return true
