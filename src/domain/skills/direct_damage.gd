class_name DirectDamageSkill
extends Skill
## it·ven: 격돌 시작 때 상대에게 바로 피해.


func on_clash(_ctx: BattleContext, _me: Combatant, foe: Combatant) -> void:
	foe.hp -= int(params.get("damage", 0))
