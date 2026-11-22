class_name RerollNextSkill
extends Skill
## par: 다음 동료가 격돌을 시작할 때 뒷면 코인을 다시 던진다.


func on_clash(ctx: BattleContext, me: Combatant, _foe: Combatant) -> void:
	ctx.reroll_next[me.side] += int(params.get("count", 1))
