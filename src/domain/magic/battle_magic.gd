class_name BattleMagic
extends RefCounted
## 전투 마법의 겉모양(architecture.md 3절). 정의는 data/balance/battle_magic.json.
## [사용자 의견] 마법은 고르는 대상도, 전체에 거는 것도 없다. 공격 마법은 지금 싸우는 적에게, 방어·효과·순서 마법은 지금 싸우는 아군에게
## (pro-만 가장 뒤의 적을 앞으로 꺼낸다). 턴마다 쓰니 하나하나는 약하다.

var id: String
var prefix: String
var kind: String
var params: Dictionary = {}


func configure(def: Dictionary) -> void:
	id = def["id"]
	prefix = def.get("prefix", "")
	kind = def.get("kind", "")
	params = def.get("params", {})


func cast(_ctx: BattleContext, _side: int) -> void:
	pass


## fac 스킬로 한 번 더 걸 때. 기본은 cast와 같다.
func recast(ctx: BattleContext, side: int) -> void:
	cast(ctx, side)


func num(key: String, ctx: BattleContext) -> int:
	return Formula.int_value(params.get(key, 0), {"P": ctx.power})


## 유닛의 지금 체력(아직 안 나왔으면 나올 때의 체력 어림).
static func hp_now(u: Combatant) -> int:
	return u.hp if u.entered else u.base.hp - u.pre_damage


## 공격 마법 피해: damage(P 식) + 상대 지금 체력의 hp_pct%(올림). 후반에도 듣게(사용자 의견).
## 그 접두사가 든 단어는 절반만 받는다(01-rpg-base '공격 마법').
func strike_damage(ctx: BattleContext, target: Combatant) -> int:
	var dmg := num("damage", ctx) + int(ceil(maxi(0, hp_now(target)) * float(params.get("hp_pct", 0)) / 100.0))
	if prefix in target.prefixes:
		dmg = dmg / 2
	return dmg


static func hurt(u: Combatant, dmg: int) -> void:
	if u.entered:
		u.hp -= dmg
	else:
		u.pre_damage += dmg
