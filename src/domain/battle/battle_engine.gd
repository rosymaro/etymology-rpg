class_name BattleEngine
extends RefCounted
## 서바이벌 전투(01-rpg-base '전투: 4 대 4 서바이벌'). tools/balance/engine.py와 같은 순서로 계산한다.
## 1) 마법 발동 2) 출전 순서대로 격돌: 새로 나온 쪽만 코인을 던진다 → 보스 능력 → 스킬 → 라운드 반복
## 라운드: 두 쪽이 동시에 (공격 − 상대 방어 − 감소)만큼, 최소 1 피해. 먼저 공격하는 쪽은 상대를 먼저 친다.

const MAX_ROUNDS := 200

var ctx: BattleContext


func _init(context: BattleContext) -> void:
	ctx = context


func run() -> BattleResult:
	var res := BattleResult.new()
	res.enemy_count = ctx.enemies.size()
	if ctx.magic:
		ctx.cast_magic(Combatant.ALLY)
	var i := 0
	var j := 0
	var a: Combatant = null
	var b: Combatant = null
	while i < ctx.allies.size() and j < ctx.enemies.size():
		if a == null:
			a = ctx.allies[i]
			_enter(a, i)
		if b == null:
			b = ctx.enemies[j]
			_enter(b, j)
		_clash(a, b, i, j)
		if b.hp <= 0:
			res.killed.append(j)
			ctx.add_log({"t": "down", "side": Combatant.ENEMY, "idx": j})
			j += 1
			b = null
		if a.hp <= 0:
			ctx.add_log({"t": "down", "side": Combatant.ALLY, "idx": i})
			i += 1
			a = null
	ctx.add_log({"t": "end", "kills": res.killed.size(), "total": res.enemy_count})
	res.log = ctx.log
	return res


func _enter(u: Combatant, idx: int) -> void:
	u.roll(ctx.coin_source, ctx.formula)
	var r: int = ctx.reroll_next[u.side]
	if r > 0:
		ctx.reroll_next[u.side] = 0
		for k in u.flips.size():
			if r > 0 and not u.flips[k]:
				u.flips[k] = ctx.coin_source.flip(1, u.heads_chance)[0]
				r -= 1
		u.recalc_atk(ctx.formula)
	ctx.add_log({"t": "enter", "side": u.side, "idx": idx, "flips": u.flips.duplicate(),
		"atk": u.atk, "def": u.def, "hp": u.hp})


func _clash(a: Combatant, b: Combatant, i: int, j: int) -> void:
	a.start_clash()
	b.start_clash()
	for pair in [[b, a], [a, b]]:
		var boss: Combatant = pair[0]
		if boss.boss_ability and ctx.is_boss_battle:
			boss.boss_ability.on_clash(ctx, boss, pair[1])
	for pair in [[a, b], [b, a]]:
		var u: Combatant = pair[0]
		if u.skill and not u.sealed and u.heads() >= ctx.formula.skill_min_heads(u.skill.tier, u.coins):
			u.skill.on_clash(ctx, u, pair[1])
			ctx.add_log({"t": "skill", "side": u.side, "root": u.skill.root})
	ctx.add_log({"t": "clash", "a": i, "b": j, "a_atk": a.atk, "a_def": a.def, "a_hp": a.hp,
		"b_atk": b.atk, "b_def": b.def, "b_hp": b.hp})
	var rnd := 0
	while a.hp > 0 and b.hp > 0 and rnd < MAX_ROUNDS:
		rnd += 1
		var da := _damage(a, b, rnd)
		var db := _damage(b, a, rnd)
		if a.first_strike and not b.first_strike:
			b.hp -= da
			if b.hp > 0:
				a.hp -= db
			else:
				db = 0
		elif b.first_strike and not a.first_strike:
			a.hp -= db
			if a.hp > 0:
				b.hp -= da
			else:
				da = 0
		else:
			a.hp -= db
			b.hp -= da
		ctx.add_log({"t": "round", "n": rnd, "to_b": da, "to_a": db, "a_hp": maxi(a.hp, 0), "b_hp": maxi(b.hp, 0)})


func _damage(x: Combatant, y: Combatant, rnd: int) -> int:
	var d := maxi(1, x.atk - y.def - y.reduce)
	if x.double_first and rnd == 1:
		d *= 2
	if y.boss_ability and ctx.is_boss_battle:
		d = y.boss_ability.modify_incoming(ctx, y, x, d)
	return d

