class_name FixedCoinSource
extends CoinSource
## 정해진 순서로 앞(true)/뒤(false)를 돌려준다. 다 쓰면 뒷면. chance()는 always_chance를 돌려준다.

var _queue: Array[bool] = []
var always_chance := false


func _init(flips: Array = []) -> void:
	super(null)
	for f in flips:
		_queue.append(bool(f))


func flip(n: int, _heads_chance: float = 0.5) -> Array[bool]:
	var out: Array[bool] = []
	for i in n:
		out.append(_queue.pop_front() if not _queue.is_empty() else false)
	return out


func chance(_p: float) -> bool:
	return always_chance


func pick(_n: int) -> int:
	return 0
