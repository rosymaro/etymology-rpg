class_name SwapToBackMagic
extends BattleMagic
## ex-(밖으로): 지금 싸우는 아군과 적을 둘 다 순서 맨 뒤로 보낸다. 지나친 유닛 하나마다 체력이 오른다(hp_per_passed).
## 뒤로 간 유닛은 다시 나올 때 코인을 새로 던지지만 체력은 그때의 체력(+오른 몫)을 그대로 갖는다.


func cast(ctx: BattleContext, side: int) -> void:
	var per := num("hp_per_passed", ctx)
	var moved := []
	for s in [side, ctx.other(side)]:
		var u := ctx.cur(s)
		if u == null:
			continue
		var passed := ctx.waiting(s).size()
		if passed == 0:
			continue
		u.hold_hp = u.hp + per * passed if u.entered else 0
		if not u.entered:
			u.pre_damage -= per * passed
		ctx.send_back(u)
		moved.append([s, ctx.team(s).find(u), passed, per * passed])
	ctx.add_log({"t": "magic", "id": id, "side": side, "moved": moved})
