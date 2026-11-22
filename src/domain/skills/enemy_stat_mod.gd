class_name EnemyStatModSkill
extends Skill
## 이번 격돌 상대 능력치 ±(cert 방어 −2, press 공격 −2).


func on_clash(_ctx: BattleContext, _me: Combatant, foe: Combatant) -> void:
	foe.atk = maxi(0, foe.atk + int(params.get("atk", 0)))
	foe.def = maxi(0, foe.def + int(params.get("def", 0)))
