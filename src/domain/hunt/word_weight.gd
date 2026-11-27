class_name WordWeight
extends RefCounted
## 몹 단어가 나올 무게(사용자 의견): 잡은 횟수만큼 줄고, cap번 이상 잡으면 floor에서 멈춘다(복습이 되게 아예 없어지지는 않는다).
## 수치는 data/balance/field_hunt.json caught_decay {cap, floor}. 노드·화면을 모른다.


## base(빈도 무게) × 줄어든 몫. 0번이면 그대로, cap번 이상이면 floor배로 고정, 그 사이는 곧게 준다.
static func weight(base: float, caught: int, cfg: Dictionary) -> float:
	var cap := maxi(1, int(cfg.get("cap", 10)))
	var floor_m := float(cfg.get("floor", 0.15))
	var k := clampf(float(caught) / cap, 0.0, 1.0)
	return base * lerpf(1.0, floor_m, k)
