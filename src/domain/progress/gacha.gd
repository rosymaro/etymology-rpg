class_name Gacha
extends RefCounted
## 말 뽑기(07-fun.md 7절). 노드·화면을 모른다. 코인을 내고 열린 스테이지(1 ~ state.stage)의 1차 단어 중 무작위로 뽑는다.
## 무게 = weight 식(f = 단어 빈도): 빈도가 낮을수록 드물다. 10번 뽑기는 드문 단어(빈도 ≤ rare_freq)를 하나 이상 보장한다.

var repo: WordRepository
var rules: ProgressRules
var cfg: Dictionary


func _init(words: WordRepository, progress: ProgressRules, gacha_cfg: Dictionary) -> void:
	repo = words
	rules = progress
	cfg = gacha_cfg


func pool(state: GameState) -> Array[WordData]:
	var out: Array[WordData] = []
	for st in range(1, maxi(1, state.stage) + 1):
		out.append_array(repo.first_tier(st))
	return out


func _weight(w: WordData) -> int:
	return maxi(1, Formula.int_value(cfg["weight"], {"f": w.freq}))


func is_rare(w: WordData) -> bool:
	return w.freq <= int(cfg["rare_freq"])


func _draw_one(p: Array[WordData], rng: RandomNumberGenerator, rare_only := false) -> WordData:
	var cand := p.filter(func(w: WordData) -> bool: return is_rare(w)) if rare_only else p
	if cand.is_empty():
		cand = p
	var total := 0
	for w in cand:
		total += _weight(w)
	var r := rng.randi_range(1, total)
	for w in cand:
		r -= _weight(w)
		if r <= 0:
			return w
	return cand[-1]


## n번(1 또는 10) 뽑는다. 코인이 모자라면 빈 배열. 돌려주는 값: [{id, new, rare, event}](event = gain_word 결과)
func pull(state: GameState, n: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var price := int(cfg["price10"]) if n >= 10 else int(cfg["price"]) * n
	if state.wallet < price:
		return []
	state.wallet -= price
	var p := pool(state)
	var got: Array[WordData] = []
	for k in n:
		got.append(_draw_one(p, rng))
	if n >= 10 and not got.any(func(w: WordData) -> bool: return is_rare(w)):
		got[rng.randi_range(0, got.size() - 1)] = _draw_one(p, rng, true)
	var out: Array[Dictionary] = []
	for w in got:
		var is_new := not state.has_word(w.id)
		out.append({"id": w.id, "new": is_new, "rare": is_rare(w), "event": rules.gain_word(state, w.id)})
	return out
