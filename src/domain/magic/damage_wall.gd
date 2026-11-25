class_name DamageWallMagic
extends BattleMagic
## inter-(사이에): 지금 싸우는 아군 앞에 벽: 다음 rounds 턴 동안 받는 피해가 reduce만큼 준다.


func cast(ctx: BattleContext, side: int) -> void:
	var me := ctx.cur(side)
	if me == null:
		return
	me.wall = num("reduce", ctx)
	me.wall_rounds = num("rounds", ctx)
	ctx.add_log({"t": "magic", "id": id, "side": side, "who": ctx.team(side).find(me), "reduce": me.wall})
