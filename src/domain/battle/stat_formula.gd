class_name StatFormula
extends RefCounted
## 유닛·적 능력치 공식(data/balance/unit.json). 01-rpg-base '유닛 능력치 공식', sim-10stage.md 2절.
## 능력치 = 기본 + 레벨당 × (레벨 − 1)(버림) + 코인 항.

var _u: Dictionary


func _init(unit_json: Dictionary) -> void:
	_u = unit_json


func coins(level: int) -> int:
	return Formula.int_value(_u["coins"], {"L": level})


func coin_value(level: int) -> int:
	return Formula.int_value(_u["coin_value"], {"L": level})


## tend: {"atk": "L|M|H", "def": ..., "hp": ...}
func base(tend: Dictionary, level: int) -> Stats:
	return Stats.new(_grow("atk", tend["atk"], level), _grow("def", tend["def"], level), _grow("hp", tend["hp"], level))


func _grow(stat: String, grade: String, level: int) -> int:
	var row: Array = _u[stat][grade]
	return int(row[0]) + int(float(row[1]) * (level - 1) + 1e-9)


## 코인 항: 앞면 결과로 더해지는 공격·체력(01-rpg-base 코인 성향 표).
func coin_terms(style: String, k: int, flips: Array[bool]) -> Stats:
	var n := flips.size()
	var c := func(m: int) -> int:
		var h := 0
		for i in mini(m, n):
			if flips[i]:
				h += 1
		return h
	match style:
		"atk":
			return Stats.new(k * c.call(n), 0, 0)
		"hp":
			return Stats.new(0, 0, 2 * k * c.call(n))
		"skill":
			return Stats.new(k * c.call(maxi(1, n / 2)), 0, 0)
		"stable":
			return Stats.new(k * c.call(1), 0, 0)
		"tails":
			return Stats.new(k * (n - c.call(n)), 0, 0)
		"swing":
			return Stats.new(2 * k * c.call(n), 0, -k * c.call(1))
	return Stats.new()


## 코인 항의 표기: 어느 능력치에 "+kCn"(앞면 1개마다 +k, 코인 n개 중)이 붙는지. coin_terms와 같은 규칙이다.
## 돌려주는 값 {"atk": "+2C3", "hp": ""}. T는 뒷면 수로 센다는 뜻.
func coin_notation(style: String, k: int, n: int) -> Dictionary:
	match style:
		"atk":
			return {"atk": "+%dC%d" % [k, n], "hp": ""}
		"hp":
			return {"atk": "", "hp": "+%dC%d" % [2 * k, n]}
		"skill":
			return {"atk": "+%dC%d" % [k, maxi(1, n / 2)], "hp": ""}
		"stable":
			return {"atk": "+%dC1" % k, "hp": ""}
		"tails":
			return {"atk": "+%dT%d" % [k, n], "hp": ""}
		"swing":
			return {"atk": "+%dC%d" % [2 * k, n], "hp": "-%dC1" % k}
	return {"atk": "", "hp": ""}


## 스킬이 발동하는 최소 앞면 수(unit.json skill_min_heads).
func skill_min_heads(tier: String, n: int) -> int:
	return Formula.int_value(_u["skill_min_heads"].get(tier, "n"), {"n": n})


func role(unit_no: int) -> Dictionary:
	return _u["roles"][str(unit_no)]
