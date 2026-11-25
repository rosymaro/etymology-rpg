class_name PullFromBackMagic
extends BattleMagic
## pro-(앞으로): 가장 뒤에서 기다리는 적을 앞으로 꺼내 지금 싸우게 한다(사용자 의견: 뒤에 숨은 보스에게 쓴다).
## 끌려 나오며 약해진다: 피해(damage + 체력의 hp_pct%)와 지나친 유닛 하나마다 공격 -atk_per_passed.
## 지금 싸우던 적은 그 바로 뒤로 물러난다. 성공 확률 chance_pct%(실패하면 마법만 쓰인다).


func cast(ctx: BattleContext, side: int) -> void:
	var foe_side := ctx.other(side)
	var wait := ctx.waiting(foe_side)
	if wait.is_empty():
		ctx.add_log({"t": "magic", "id": id, "side": side, "failed": true})
		return
	var ok := ctx.coin_source.chance(float(params.get("chance_pct", 60)) / 100.0)
	if not ok:
		ctx.add_log({"t": "magic", "id": id, "side": side, "failed": true})
		return
	var back: Combatant = wait[wait.size() - 1]
	var now := ctx.cur(foe_side)
	var passed := wait.size()
	if now and now.entered:
		now.hold_hp = now.hp
	ctx.bring_front(back)
	var dmg := strike_damage(ctx, back)
	var down := num("atk_per_passed", ctx) * passed
	if back.entered and back.hold_hp > 0:  # 전에 물러났던 적: 다시 나올 때의 체력에서 뺀다
		back.hold_hp = maxi(1, back.hold_hp - dmg)
	else:
		hurt(back, dmg)
	back.perm_atk -= down
	if back.entered:
		back.atk = maxi(0, back.atk - down)
	ctx.add_log({"t": "magic", "id": id, "side": side, "target": ctx.team(foe_side).find(back), "damage": dmg, "atk_down": down, "passed": passed})
