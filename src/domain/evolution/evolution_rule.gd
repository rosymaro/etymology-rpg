class_name EvolutionRule
extends RefCounted
## 진화(02-rpg-v2 '진화'): 마을에서만 한다. 재료 아래의 모든 1차 단어와 결과 단어의 뜻을 모두 맞혀야 성공한다.
## 실패하면 재료는 그대로이고, 틀린 1차 단어 하나가 '다시 잡을 단어'가 된다. 그 단어를 다시 잡으면 재도전할 수 있다.

var repo: WordRepository


func _init(words: WordRepository) -> void:
	repo = words


## 지금 진화할 수 있는 단어(재료를 모두 가졌고, 아직 없고, 다시 잡을 단어가 없는 것).
func available(state: GameState, max_tier: int) -> Array[WordData]:
	var out: Array[WordData] = []
	for t in range(2, max_tier + 1):
		for w in repo.evolutions_up_to(state.stage, t):
			if can_evolve(state, w.id):
				out.append(w)
	return out


func can_evolve(state: GameState, id: String) -> bool:
	var w := repo.get_word(id)
	if w == null or w.tier < 2 or state.has_word(id) or state.recapture.has(id):
		return false
	for m in w.mats:
		if not state.has_word(m):
			return false
	return true


## 퀴즈에 나오는 단어: 아래의 1차 모두 + 결과 단어.
func quiz_words(id: String) -> Array[String]:
	var out: Array[String] = repo.leaves(id).duplicate()
	out.append(id)
	return out


## 실패했을 때 다시 잡을 1차 단어: 틀린 단어 중 1차의 첫째, 1차를 안 틀렸으면 아래 1차의 첫째.
func recapture_target(id: String, wrong: Array[String]) -> String:
	var lv := repo.leaves(id)
	for w in wrong:
		if w in lv:
			return w
	return lv[0]
