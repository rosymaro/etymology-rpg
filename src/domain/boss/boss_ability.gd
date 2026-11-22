class_name BossAbility
extends RefCounted
## 보스 능력의 겉모양(스킬과 같은 꼴). 코인 조건 없이 늘 발동한다. 정의는 data/balance/boss.json.

var params: Dictionary = {}


func configure(p: Dictionary) -> void:
	params = p


## 보스가 싸우는 격돌이 시작될 때(스킬보다 먼저).
func on_clash(_ctx: BattleContext, _boss: Combatant, _foe: Combatant) -> void:
	pass


## 보스가 피해를 받을 때 줄이거나 막는다. 돌려준 값이 실제 피해다.
func modify_incoming(_ctx: BattleContext, _boss: Combatant, attacker: Combatant, dmg: int) -> int:
	return dmg
