class_name FirstStrikeNowMagic
extends BattleMagic
## prae-(미리): 이번 격돌 동안 지금 싸우는 아군이 먼저 친다. 먼저 쓰러뜨리면 되맞지 않는다.


func cast(ctx: BattleContext, side: int) -> void:
	var me := ctx.cur(side)
	if me == null:
		return
	me.first_strike = true
	ctx.add_log({"t": "magic", "id": id, "side": side, "who": ctx.team(side).find(me)})
