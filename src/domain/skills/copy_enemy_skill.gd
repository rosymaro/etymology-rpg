class_name CopyEnemySkill
extends Skill
## form: 상대 스킬을 복사해 이번 격돌에 쓴다(조건 없이). 상대가 스킬이 없으면 아무 일도 없다.


func on_clash(ctx: BattleContext, me: Combatant, foe: Combatant) -> void:
	if foe.skill and foe.skill.copyable() and not foe.sealed:
		foe.skill.on_clash(ctx, me, foe)
		ctx.add_log({"t": "skill_copy", "side": me.side, "root": foe.skill.root})


func copyable() -> bool:
	return false
