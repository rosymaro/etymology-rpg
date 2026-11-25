class_name HealNowMagic
extends BattleMagic
## re-(다시): 지금 싸우는 아군의 체력을 heal + 최대 체력의 hp_pct%(올림)만큼 되찾는다.


func cast(ctx: BattleContext, side: int) -> void:
	var me := ctx.cur(side)
	if me == null:
		return
	var amount := num("heal", ctx) + int(ceil(me.base.hp * float(params.get("hp_pct", 0)) / 100.0))
	ctx.heal(me, amount, false)
	ctx.add_log({"t": "magic", "id": id, "side": side, "who": ctx.team(side).find(me), "heal": amount})
