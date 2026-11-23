class_name GuardGame
extends Minigame
## 8 성벽 요새 '보초 서기'(검문, 참·거짓 가리기): 성문으로 단어와 뜻이 하나씩 온다.
## 맞는 짝이면 '통과', 틀린 짝이면 '막기'. 바르게 판정하면 그 단어 1개. 틀리게 판정하면 바른 뜻을 보여 주고 실수.

var travelers: Array[Dictionary] = []  ## {w: 단어 순번, shown: 보여 주는 뜻, true: 맞는 짝인가}
var index := 0
var misses := 0
var last := {}  ## 방금 판정 {ok, traveler}


func _build() -> void:
	var n := mini(int(cfg["travelers"]), words.size())
	for i in n:
		var real := rng.randf() < float(cfg["true_chance"])
		var shown := words[i].meaning
		if not real:
			var j := (i + 1 + rng.randi_range(0, words.size() - 2)) % words.size()
			if words[j].meaning == shown:
				real = true
			else:
				shown = words[j].meaning
		travelers.append({"w": i, "shown": shown, "true": real})


func current() -> Dictionary:
	return travelers[index] if index < travelers.size() else {}


## pass_gate = true면 통과, false면 막기.
func judge(pass_gate: bool) -> bool:
	if finished or index >= travelers.size():
		return false
	var t := travelers[index]
	var ok: bool = pass_gate == bool(t["true"])
	last = {"ok": ok, "traveler": t}
	if ok:
		earn(words[t["w"]].id)
	else:
		misses += 1
		if misses >= int(cfg["max_miss"]):
			finish()
	index += 1
	if index >= travelers.size():
		finish()
	return ok
