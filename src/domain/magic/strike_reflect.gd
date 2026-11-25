class_name StrikeReflectMagic
extends BattleMagic
## ob-(맞서): 지금 싸우는 적에게 피해를 주고, 이번 격돌 동안 아군이 받는 피해의 reflect_pct%를 그 적에게 되돌린다.


func cast(ctx: BattleContext, side: int) -> void:
	var target := ctx.cur(ctx.other(side))
	var me := ctx.cur(side)
	if target == null or me == null:
		return
	var dmg := strike_damage(ctx, target)
	hurt(target, dmg)
	me.reflect = float(params.get("reflect_pct", 50)) / 100.0
	ctx.add_log({"t": "magic", "id": id, "side": side, "target": ctx.team(ctx.other(side)).find(target), "damage": dmg})
