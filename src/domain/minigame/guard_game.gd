class_name GuardGame
extends Minigame
## 8 성벽 요새 '보초 서기'(검문 + 막아서기): 성문 바깥에서 성문을 바라본다. 내 유닛이 성벽 앞에서 좌우(x)로 움직인다.
## - 손님 단어가 뜻 팻말을 들고 성문으로 걸어온다. 팻말이 그 단어의 뜻이면 비켜서 통과시키고, 다른 뜻이면 막아선다.
##   바르게 판정하면 그 단어 1개, 틀리면 실수.
## - 담 넘는 것은 도둑·범죄자 단어(cfg.climber_words)다. 뜻과 상관없이 막아야 한다. 놓치면 실수.
## 좌표는 0~1 비율: x는 왼쪽 → 오른쪽, y는 멀리(0, 아래쪽 들판) → 성벽(1). 막는 선 y = 1에 닿을 때 판정한다.

var gate_x := 0.5
var unit_x := 0.5
var target_x := 0.5
var walkers: Array[Dictionary] = []  ## {kind: "gate"|"climb", w, name(담 넘는 단어), shown, true, x, y, done}
var misses := 0
var events: Array[Dictionary] = []  ## 화면이 읽고 비우는 판정 기록 {kind, ok, w}
var _spawn_gate := 0.0
var _spawn_climb := 0.0
var _next_word := 0


func _build() -> void:
	_spawn_gate = 0.5
	_spawn_climb = float(cfg["climb_every"])


## 유닛이 갈 곳(손가락 위치). 실제로는 unit_speed로 따라간다.
func move_to(x: float) -> void:
	target_x = clampf(x, 0.0, 1.0)


func covers(x: float) -> bool:
	return absf(unit_x - x) <= float(cfg["unit_w"]) / 2.0


func spawn_gate_word() -> void:
	var i := _next_word % words.size()
	_next_word += 1
	var real := rng.randf() < float(cfg["true_chance"])
	var shown := words[i].meaning
	if not real and words.size() > 1:
		var j := (i + 1 + rng.randi_range(0, words.size() - 2)) % words.size()
		if words[j].meaning == shown:
			real = true
		else:
			shown = words[j].meaning
	walkers.append({"kind": "gate", "w": i, "shown": shown, "true": real,
		"x": gate_x + rng.randf_range(-0.35, 0.35), "y": 0.0, "done": false})


func spawn_climber() -> void:
	var x := rng.randf_range(0.05, 0.95)
	if absf(x - gate_x) < float(cfg["gate_w"]):
		x = fposmod(x + 0.4, 0.9) + 0.05
	var names: Array = cfg.get("climber_words", ["thief"])
	walkers.append({"kind": "climb", "w": rng.randi_range(0, words.size() - 1), "name": String(names[rng.randi_range(0, names.size() - 1)]),
		"x": x, "y": 0.0, "done": false})


func _tick(dt: float) -> void:
	var sp := float(cfg["unit_speed"]) * dt
	unit_x = move_toward(unit_x, target_x, sp)
	_spawn_gate -= dt
	if _spawn_gate <= 0.0:
		_spawn_gate = float(cfg["gate_every"])
		spawn_gate_word()
	_spawn_climb -= dt
	if _spawn_climb <= 0.0:
		_spawn_climb = float(cfg["climb_every"])
		spawn_climber()
	for w in walkers:
		if w["done"]:
			continue
		if w["kind"] == "gate":
			w["y"] += dt / float(cfg["walk_time"])
			# 멀리서는 흩어져 오다가 성문 쪽으로 모인다
			w["x"] = lerpf(w["x"], gate_x, clampf(dt * 1.5, 0.0, 1.0))
		else:
			w["y"] += dt / float(cfg["climb_time"])
		if w["y"] >= 1.0:
			_arrive(w)
	walkers = walkers.filter(func(w: Dictionary) -> bool: return not w["done"])


func _arrive(w: Dictionary) -> void:
	w["done"] = true
	var blocked := covers(w["x"])
	if w["kind"] == "climb":
		var ok_c := blocked
		if not ok_c:
			_miss()
		events.append({"kind": "climb", "ok": ok_c, "w": w["w"], "name": w["name"], "x": w["x"]})
		return
	var ok := blocked != bool(w["true"])  # 맞는 짝은 통과(막지 않음), 틀린 짝은 막음
	if ok:
		earn(words[w["w"]].id)
	else:
		_miss()
	events.append({"kind": "gate", "ok": ok, "w": w["w"], "true": w["true"], "blocked": blocked, "shown": w["shown"], "x": w["x"]})


func _miss() -> void:
	misses += 1
	if misses >= int(cfg["max_miss"]):
		finish()
