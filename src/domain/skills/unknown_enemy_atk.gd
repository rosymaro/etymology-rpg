class_name UnknownEnemyAtkSkill
extends Skill
## not: 도감에 없는 적이면 공격 +. 적이 쓰면 늘 발동한다(적에게는 도감이 없다).


func on_clash(ctx: BattleContext, me: Combatant, foe: Combatant) -> void:
	if me.side == Combatant.ENEMY or not ctx.in_dex.call(foe.word_id):
		me.atk += int(params.get("atk", 0))
