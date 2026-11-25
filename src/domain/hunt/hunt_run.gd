class_name HuntRun
extends RefCounted
## 필드 사냥 한 번의 나들이(07-fun.md 1절). 노드·화면을 모른다. 상태는 GameState.hunt(사전)에 두어 저장·화면 전환에도 남는다.
## hunt = {level, exp, weapons: {id: 단계(0부터)}, speed, magnet, sec, eaters, bag: {orbs, coins, words: []}}
## 사냥으로 얻은 것은 주머니(bag)에 담기고, 마을에 들어가야(bank) 내 것이 된다. 지면 주머니의 절반을 잃는다.

var d: Dictionary
var cfg: Dictionary


func _init(hunt: Dictionary, hunt_cfg: Dictionary) -> void:
	d = hunt
	cfg = hunt_cfg
	if d.is_empty():
		reset()


## 마을을 나설 때: 레벨·강화는 0에서. 주머니는 그대로(마을에 들어가면 비워진다).
func reset() -> void:
	var bag: Dictionary = d.get("bag", {"orbs": 0, "coins": 0, "words": []})
	d.clear()
	d.merge({"level": 0, "exp": 0, "weapons": {}, "speed": 0.0, "magnet": 0.0, "sec": 0.0, "eaters": 0, "bag": bag})
	for w in cfg["start_skills"]:
		d["weapons"][w] = 0


func level() -> int:
	return int(d["level"])


func need() -> int:
	return Formula.int_value(cfg["level_exp"], {"L": level()})


func bag() -> Dictionary:
	return d["bag"]


## 몹을 쓰러뜨렸다: 떨어지는 것 {orbs, coins, word}. 주머니에 담는 것은 줍기(pick_*)에서.
func drops(kind: String, words: Array, rng: RandomNumberGenerator) -> Dictionary:
	var out := {"orbs": int(cfg["orb"].get(kind, 1)), "coins": 0, "word": ""}
	if rng.randf() < float(cfg["coin"]["chance"]):
		out["coins"] = rng.randi_range(int(cfg["coin"]["min"]), int(cfg["coin"]["max"]))
	if not words.is_empty() and rng.randf() < float(cfg["word_chance"]):
		out["word"] = String(words[rng.randi_range(0, words.size() - 1)])
	return out


## 구슬을 주웠다. 레벨이 오르면 true(화면이 보기 3개를 띄운다).
func pick_orbs(n: int) -> bool:
	bag()["orbs"] = int(bag()["orbs"]) + n
	if level() >= int(cfg["max_level"]):
		return false
	d["exp"] = int(d["exp"]) + n
	if int(d["exp"]) >= need():
		d["exp"] = int(d["exp"]) - need()
		d["level"] = level() + 1
		return true
	return false


func pick_coins(n: int) -> void:
	bag()["coins"] = int(bag()["coins"]) + n


func pick_word(id: String) -> void:
	if id != "":
		(bag()["words"] as Array).append(id)


## 레벨업 보기 3개: 가진 어원 스킬 중 아직 안 쓴 무기(new), 쓰는 무기 강화(up), 이동 속도(speed), 구슬 끌기(magnet).
func choices(owned_skills: Array, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for w in owned_skills:
		if not cfg["weapons"].has(w):
			continue
		if not d["weapons"].has(w):
			pool.append({"type": "new", "id": w})
		elif int(d["weapons"][w]) < (cfg["weapons"][w]["dmg"] as Array).size() - 1:
			pool.append({"type": "up", "id": w})
	pool.append({"type": "speed", "id": ""})
	pool.append({"type": "magnet", "id": ""})
	var out: Array[Dictionary] = []
	while out.size() < 3 and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


func apply(c: Dictionary) -> void:
	match String(c["type"]):
		"new":
			d["weapons"][c["id"]] = 0
		"up":
			d["weapons"][c["id"]] = int(d["weapons"][c["id"]]) + 1
		"speed":
			d["speed"] = float(d["speed"]) + float(cfg["speed_up"])
		"magnet":
			d["magnet"] = float(d["magnet"]) + float(cfg["magnet_up"])


## 무기의 지금 수치 {type, cd, dmg, count, range, speed, hit_gap}.
func weapon(id: String) -> Dictionary:
	var w: Dictionary = cfg["weapons"][id]
	var lv := mini(int(d["weapons"].get(id, 0)), (w["dmg"] as Array).size() - 1)
	return {"type": w["type"], "cd": float(w["cd"][lv]), "dmg": int(w["dmg"][lv]), "count": int(w["count"][lv]),
		"range": float(w["range"]), "speed": float(w["speed"]), "hit_gap": float(w.get("hit_gap", 0.5))}


func magnet() -> float:
	return float(cfg["magnet"]) + float(d["magnet"])


func speed_mult() -> float:
	return 1.0 + float(d["speed"])


## 시간이 흐른다. 뿌리먹이가 나올 때가 되면 true(최대 레벨이거나 after_sec, 그 뒤 again_sec마다).
func tick(delta: float) -> bool:
	d["sec"] = float(d["sec"]) + delta
	var e: Dictionary = cfg["eater"]
	var n := int(d["eaters"])
	var due := float(e["after_sec"]) + n * float(e["again_sec"])
	if level() >= int(cfg["max_level"]) and n == 0:
		due = 0.0
	if float(d["sec"]) >= due:
		d["eaters"] = n + 1
		return true
	return false


## 마을에 들어갔다: 주머니를 풀어 내 것으로(구슬 → 유닛 경험치, 코인 → 지갑, 단어 → 도감). 나들이도 새로.
## 돌려주는 값 {orbs, coins, words: [단어 id]} (풀 게 없었으면 orbs·coins 0, words 빈 배열)
func bank(state: GameState, rules: ProgressRules) -> Dictionary:
	var b := bag().duplicate(true)
	var exp := int(b["orbs"]) * int(cfg["bank"]["exp_per_orb"])
	if exp > 0:
		for u in state.joined:
			state.unit_exp[u - 1] += exp
	state.wallet += int(b["coins"])
	for w in b["words"]:
		rules.gain_word(state, String(w))
	d["bag"] = {"orbs": 0, "coins": 0, "words": []}
	reset()
	return b


## 전투에서 졌다: 주머니의 절반(lose_ratio)을 잃고 나들이는 끝.
func lose() -> void:
	var r := float(cfg["bank"]["lose_ratio"])
	var b := bag()
	b["orbs"] = int(floor(int(b["orbs"]) * (1.0 - r)))
	b["coins"] = int(floor(int(b["coins"]) * (1.0 - r)))
	var ws: Array = b["words"]
	b["words"] = ws.slice(0, int(floor(ws.size() * (1.0 - r))))
	reset()
