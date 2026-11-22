class_name BattleMagic
extends RefCounted
## 전투 마법의 겉모양(architecture.md 3절). 정의는 data/balance/battle_magic.json.

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
