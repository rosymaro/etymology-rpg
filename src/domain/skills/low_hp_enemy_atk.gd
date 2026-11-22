class_name LowHpEnemyAtkSkill
extends Skill
## put: 적 체력이 절반 이하면 공격 +. 격돌 시작 때 본다.


func on_clash(_ctx: BattleContext, me: Combatant, foe: Combatant) -> void:
	if foe.hp * 2 <= foe.max_hp_now():
		me.atk += int(params.get("atk", 0))
