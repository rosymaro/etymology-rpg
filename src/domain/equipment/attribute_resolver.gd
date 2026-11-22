class_name AttributeResolver
extends RefCounted
## 켜지는 속성 고르기(02-rpg-v2): 장비 5칸의 주·보조 속성을 1점씩 센다. 가장 많은 속성이 켜진다.
## 동점이면 무기 → 머리 → 가슴 → 장갑 → 신발 순서로 주속성이 먼저 나오는 것. 3~4개 = 약(1), 5개 = 강(2), 그 밑은 꺼짐(0).

var weak := 3
var strong := 5


func _init(thresholds: Dictionary = {}) -> void:
	weak = int(thresholds.get("weak", 3))
	strong = int(thresholds.get("strong", 5))


## {"attr": 속성 번호(꺼지면 0), "count": 개수, "tier": 0|1|2}
func resolve(eq: Equipment, repo: WordRepository) -> Dictionary:
	var cnt := {}
	var ws: Array[WordData] = []
	for s in Equipment.SLOTS:
		var id := eq.get_in(s)
		if id != "" and repo.has(id):
			var w := repo.get_word(id)
			ws.append(w)
			for a in w.attrs:
				cnt[a] = cnt.get(a, 0) + 1
	if cnt.is_empty():
		return {"attr": 0, "count": 0, "tier": 0}
	var m: int = cnt.values().max()
	var best := 0
	for w in ws:
		if cnt.get(w.primary_attr(), 0) == m:
			best = w.primary_attr()
			break
	if best == 0:
		for a in cnt:
			if cnt[a] == m:
				best = a
				break
	var tier := 2 if m >= strong else (1 if m >= weak else 0)
	return {"attr": best if tier > 0 else 0, "count": m, "tier": tier}
