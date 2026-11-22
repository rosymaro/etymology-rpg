class_name CoinSource
extends RefCounted
## 코인 던지기. 테스트에서는 FixedCoinSource로 결과를 정해 넣는다(architecture.md 10절).

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng else RandomNumberGenerator.new()


func flip(n: int, heads_chance: float = 0.5) -> Array[bool]:
	var out: Array[bool] = []
	for i in n:
		out.append(_rng.randf() < heads_chance)
	return out


func chance(p: float) -> bool:
	return _rng.randf() < p


func pick(n: int) -> int:
	return _rng.randi_range(0, n - 1)
