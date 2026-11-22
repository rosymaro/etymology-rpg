class_name RecastMagicSkill
extends Skill
## fac: 이번 전투에 건 마법을 한 번 더 발동한다(아군만, 전투에 한 번).

var _used := false


func on_clash(ctx: BattleContext, me: Combatant, _foe: Combatant) -> void:
	if _used or me.side != Combatant.ALLY or ctx.magic == null:
		return
	_used = true
	ctx.magic.recast(ctx, me.side)


func copyable() -> bool:
	return false
