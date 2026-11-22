class_name DamageReduceSkill
extends Skill
## struct: 이번 격돌 동안 받는 피해 −amount.


func on_clash(_ctx: BattleContext, me: Combatant, _foe: Combatant) -> void:
	me.reduce += int(params.get("amount", 0))
