class_name Stats
extends RefCounted
## 공격·방어·체력 묶음(값 객체).

var atk: int
var def: int
var hp: int


func _init(a: int = 0, d: int = 0, h: int = 0) -> void:
	atk = a
	def = d
	hp = h


func plus(o: Stats) -> Stats:
	return Stats.new(atk + o.atk, def + o.def, hp + o.hp)


func _to_string() -> String:
	return "%d/%d/%d" % [atk, def, hp]
