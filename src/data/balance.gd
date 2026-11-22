class_name Balance
extends RefCounted
## data/balance/*.json 묶음. 규칙 층은 수치를 여기서만 읽는다(architecture.md 9절).

var unit: Dictionary
var gear: Dictionary
var enemy: Dictionary
var tendency: Dictionary
var boss: Dictionary
var magic: Dictionary
var skills: Dictionary
var progress: Dictionary
var minigames: Dictionary
var skill_roots: Dictionary  ## 어근 id -> {family, tier}


static func load_default() -> Balance:
	var b := Balance.new()
	b.unit = JsonFile.read("res://data/balance/unit.json")
	b.gear = JsonFile.read("res://data/balance/gear.json")
	b.enemy = JsonFile.read("res://data/balance/enemy.json")
	b.tendency = JsonFile.read("res://data/balance/enemy_tendency.json")
	b.boss = JsonFile.read("res://data/balance/boss.json")
	b.magic = JsonFile.read("res://data/balance/battle_magic.json")
	b.skills = JsonFile.read("res://data/balance/skills.json")
	b.progress = JsonFile.read("res://data/balance/progress.json")
	b.minigames = JsonFile.read("res://data/balance/minigames.json")
	for r in JsonFile.read("res://data/game/skill_roots.json")["roots"]:
		b.skill_roots[r["id"]] = r
	return b


func stage_curve(stage: int) -> Dictionary:
	for c in enemy["stage_curve"]:
		if int(c["stage"]) == stage:
			return c
	return enemy["stage_curve"][-1]


func boss_def(stage: int) -> Dictionary:
	for b in boss["bosses"]:
		if int(b["stage"]) == stage:
			return b
	return {}


func magic_def(id: String) -> Dictionary:
	for m in magic["magics"]:
		if m["id"] == id:
			return m
	return {}


func skill_def(root: String) -> Dictionary:
	return skills["skills"].get(root, {})


func root_family(root: String) -> int:
	return int(skill_roots.get(root, {}).get("family", 0))


func root_tier(root: String) -> String:
	return str(skill_roots.get(root, {}).get("tier", "보통"))


func magic_power(avg_level: int) -> int:
	return Formula.int_value(unit["magic_power"], {"L": avg_level})
