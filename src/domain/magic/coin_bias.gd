class_name CoinBiasMagic
extends BattleMagic
## in-(안으로): 지금 싸우는 아군의 뒷면 코인을 앞면이 잘 나오게(heads_chance) 다시 던진다. 남은 전투 내내 그 확률로 던진다.


func cast(ctx: BattleContext, side: int) -> void:
	var u := ctx.cur(side)
	if u == null:
		return
	var p := float(params.get("heads_chance", 0.75))
	u.heads_chance = p
	var before := u.flips.duplicate()
	for k in u.flips.size():
		if not u.flips[k]:
			u.flips[k] = ctx.coin_source.flip(1, p)[0]
	u.recalc_atk(ctx.formula)
	ctx.add_log({"t": "magic", "id": id, "side": side, "who": ctx.team(side).find(u), "flips0": before, "flips1": u.flips.duplicate()})
