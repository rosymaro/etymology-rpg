class_name MinigameRegistry
extends RefCounted
## data/minigames.json의 "class" 이름으로 미니게임 규칙 객체를 만든다.


static func _classes() -> Dictionary:
	return {"FactoryGame": FactoryGame}


static func games() -> Array:
	return JsonFile.read("res://data/minigames.json")["games"]


static func game_def(id: String) -> Dictionary:
	for g in games():
		if g["id"] == id:
			return g
	return {}


static func for_stage(stage: int) -> Dictionary:
	for g in games():
		if int(g["stage"]) == stage:
			return g
	return {}


static func make(id: String, pool: Array[WordData], balance: Dictionary, rng: RandomNumberGenerator) -> Minigame:
	var def := game_def(id)
	var g: Minigame = _classes()[def["class"]].new()
	var cfg: Dictionary = FactoryGame.config(balance, id) if def["class"] == "FactoryGame" else balance[id]
	g.setup(pool, cfg, int(balance["max_words"]), rng)
	return g
