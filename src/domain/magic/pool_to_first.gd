class_name PoolToFirstMagic
extends BattleMagic
## sub-(아래에서 받쳐): 기다리는 아군이 저마다 체력의 give_ratio만큼을 지금 싸우는 아군에게 보탠다. 받는 쪽은 그 boost_pct%를 얻는다.
## 보탠 만큼 기다리는 아군은 나올 때 체력이 줄어 있다. 방어 마법이라 걸기 전에 조합 뜻 고르기를 통과해야 한다(화면).


func cast(ctx: BattleContext, side: int) -> void:
	var u := ctx.cur(side)
	if u == null:
		return
	var r := float(params.get("give_ratio", 0.5))
	var total := 0
	for w in ctx.waiting(side):
		var hp := w.hp if w.entered else w.base.hp - w.pre_damage
		var g := int(floor(maxi(0, hp) * r))
		if g <= 0:
			continue
		if w.entered:
			w.hp -= g
			w.hold_hp = w.hp
		else:
			w.pre_damage += g
		total += g
	u.hp += int(floor(total * float(params.get("boost_pct", 100)) / 100.0))  # 받쳐 주면 더 단단해진다
	ctx.add_log({"t": "magic", "id": id, "side": side, "who": ctx.team(side).find(u), "gain": total})
