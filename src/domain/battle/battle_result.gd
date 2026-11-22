class_name BattleResult
extends RefCounted
## 전투 결과(값 객체). killed = 쓰러뜨린 적의 순번.

var killed: Array[int] = []
var enemy_count: int
var log: Array[Dictionary] = []


func won() -> bool:
	return killed.size() == enemy_count


func kills() -> int:
	return killed.size()
