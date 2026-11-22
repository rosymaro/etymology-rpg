class_name TestHelpers
extends RefCounted
## 테스트용 작은 단어 묶음과 전투원.


static func repo() -> WordRepository:
	var r := WordRepository.new()
	r.load_dicts([
		{"id": "fa", "meaning": "가", "freq": 5, "attrs": [1, 2], "tier": 1, "unit": 1, "slot": "weapon", "stage": 1, "obtain": "field", "to": "ev2", "skill_roots": ["ple"]},
		{"id": "fb", "meaning": "나", "freq": 7, "attrs": [1], "tier": 1, "unit": 1, "slot": "weapon", "stage": 1, "obtain": "field", "to": "ev2"},
		{"id": "fc", "meaning": "다", "freq": 3, "attrs": [3], "tier": 1, "unit": 4, "slot": "head", "stage": 1, "obtain": "town"},
		{"id": "fd", "meaning": "라", "freq": 5, "attrs": [4], "tier": 1, "unit": 2, "slot": "feet", "stage": 2, "obtain": "field"},
		{"id": "ev2", "meaning": "마", "freq": 5, "attrs": [1], "tier": 2, "unit": 1, "slot": "weapon", "mats": ["fa", "fb"]},
		{"id": "boss1", "meaning": "바", "freq": 5, "attrs": [14], "tier": 0, "stage": 1, "obtain": "boss"},
	])
	return r


static func unit(side: int, atk: int, def: int, hp: int, coins: int = 1, style: String = "atk", k: int = 3) -> Combatant:
	var c := Combatant.new()
	c.side = side
	c.level = 10
	c.coins = coins
	c.coin_value = k
	c.coin_style = style
	c.base = Stats.new(atk, def, hp)
	return c


static func ctx(flips: Array) -> BattleContext:
	var c := BattleContext.new()
	c.formula = StatFormula.new(JsonFile.read("res://data/balance/unit.json"))
	c.coin_source = FixedCoinSource.new(flips)
	c.power = 2
	return c
