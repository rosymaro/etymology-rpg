class_name MinigameRegistry
extends RefCounted
## data/minigames.json의 "class" 이름으로 미니게임 규칙 객체를 만든다.


static func _classes() -> Dictionary:
	return {
		"OrderGame": OrderGame,
		"TrapGame": TrapGame,
		"WordSearchGame": WordSearchGame,
		"PipeGame": PipeGame,
		"FishingGame": FishingGame,
		"AnagramGame": AnagramGame,
		"CryptexGame": CryptexGame,
		"GuardGame": GuardGame,
		"OreSlashGame": OreSlashGame,
		"RootLinkGame": RootLinkGame,
	}


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
	g.setup(pool, balance[id], int(balance["max_words"]), rng)
	return g
