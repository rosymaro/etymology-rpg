class_name Skill
extends RefCounted
## 어근 스킬의 겉모양(architecture.md 3절). 격돌을 시작할 때 코인 조건을 채우면 on_clash가 불린다.

var root: String
var tier: String = "보통"  ## 코인 조건: 쉬움 보통 어려움(data/game/skill_roots.json)
var params: Dictionary = {}


func configure(root_id: String, p: Dictionary, cond_tier: String = "보통") -> void:
	root = root_id
	params = p
	tier = cond_tier


func on_clash(_ctx: BattleContext, _me: Combatant, _foe: Combatant) -> void:
	pass


## 다른 스킬이 이 스킬을 따라 쓸 수 있는가(form). 기본은 된다.
func copyable() -> bool:
	return true
