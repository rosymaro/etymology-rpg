class_name NoSkillHealSkill
extends Skill
## leg: 이 전투 동안 양쪽 모두 스킬로 회복할 수 없다.


func on_clash(ctx: BattleContext, _me: Combatant, _foe: Combatant) -> void:
	ctx.no_skill_heal = true
