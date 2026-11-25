class_name StrikeSilenceMagic
extends BattleMagic
## in-(아닌): 지금 싸우는 적에게 피해를 주고, 그 적은 남은 전투 동안 스킬을 쓰지 못한다(다음 격돌부터).


func cast(ctx: BattleContext, side: int) -> void:
	var target := ctx.cur(ctx.other(side))
	if target == null:
		return
	var dmg := strike_damage(ctx, target)
	hurt(target, dmg)
	target.sealed = true
	ctx.add_log({"t": "magic", "id": id, "side": side, "target": ctx.team(ctx.other(side)).find(target), "damage": dmg})
