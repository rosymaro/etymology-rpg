class_name RewardRule
extends RefCounted
## 전투 보상(01-rpg-base '보상'): 모두 쓰러뜨리면 단어 모두, 일부면 쓰러뜨린 것 중 하나, 하나도 못 쓰러뜨리면 없음.


static func words_won(result: BattleResult, enemy_words: Array[String], coins: CoinSource) -> Array[String]:
	var out: Array[String] = []
	if result.won():
		out.append_array(enemy_words)
	elif result.kills() > 0:
		out.append(enemy_words[result.killed[coins.pick(result.killed.size())]])
	return out
