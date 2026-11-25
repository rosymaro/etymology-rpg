class_name ShieldMagic
extends BattleMagic
## ad-(더하여): 이번 격돌 동안 지금 싸우는 아군이 받는 피해가 shield만큼 준다(방어 +shield와 같다).


func cast(ctx: BattleContext, side: int) -> void:
	var me := ctx.cur(side)
	if me == null:
		return
	var s := num("shield", ctx)
	me.reduce += s
	ctx.add_log({"t": "magic", "id": id, "side": side, "who": ctx.team(side).find(me), "shield": s})
