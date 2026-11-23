class_name TrapGame
extends Minigame
## 2 사냥꾼 초원 '덫 놓기'(지켜보고 덫 놓기): 땅 위에서 단어 5개가 저마다 정해진 길(좌우, 원, 지그재그, 네모, 8자 …)로 돈다.
## 1. 지켜보기(watch): 내 캐릭터는 덤불에 숨어 지켜본다. 단어들의 길을 기억한다.
## 2. 덫 놓기(place): 캐릭터가 움직이면(땅을 누르거나 덫을 끌면) 단어들이 숨는다. 뜻이 적힌 덫을 단어가 지나갈 자리에 놓는다.
## 3. 사냥(hunt): 다시 숨으면 단어들이 처음부터 똑같이 움직인다. 덫의 뜻과 같은 뜻의 단어가 덫을 지나면 잡힌다(1개).
##    뜻이 다른 덫은 그냥 지나간다. 한 바퀴(period)가 끝나면 판이 끝난다.
## 좌표는 0~1 비율. 덤불(숨는 곳)은 아래 가운데.

const KINDS := ["line_h", "circle", "zigzag", "square", "eight", "line_v"]
const HIDE := Vector2(0.5, 0.93)

var paths: Array[Dictionary] = []  ## {w, kind, c, r, phase}
var phase := "watch"  ## watch | place | hunt
var t := 0.0  ## 단어들의 시간(사냥 때 0부터 다시)
var traps: Array[Dictionary] = []  ## {w(뜻의 단어), pos, used}
var tray: Array[int] = []  ## 아직 놓지 않은 덫(뜻의 단어 순번)
var caught: Array[bool] = []
var hero := HIDE
var hero_target := HIDE
var events: Array[Dictionary] = []  ## 잡힘 {w, pos}


func _build() -> void:
	var n := mini(int(cfg["words"]), words.size())
	var kinds := KINDS.duplicate()
	kinds.shuffle()
	# 판을 3×2 칸으로 나눠 단어마다 한 칸(겹치지 않게)
	var cells: Array[Vector2] = []
	for r in 2:
		for c in 3:
			cells.append(Vector2(0.2 + c * 0.3, 0.22 + r * 0.33))
	cells.shuffle()
	for i in n:
		paths.append({"w": i, "kind": kinds[i % kinds.size()], "c": cells[i] + Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03)),
			"r": rng.randf_range(0.09, 0.12), "phase": rng.randf()})
		caught.append(false)
		tray.append(i)
	tray.shuffle()


func period() -> float:
	return float(cfg["period"])


## 단어 i가 시간 tt에 있는 자리.
func pos(i: int, tt: float) -> Vector2:
	var p := paths[i]
	var u := fposmod(tt / period() + float(p["phase"]), 1.0)
	var c: Vector2 = p["c"]
	var r: float = p["r"]
	var a := u * TAU
	match p["kind"]:
		"line_h":
			return c + Vector2(sin(a) * r * 1.2, 0)
		"line_v":
			return c + Vector2(0, sin(a) * r)
		"circle":
			return c + Vector2(cos(a) * r, sin(a) * r * 0.8)
		"zigzag":
			return c + Vector2(sin(a) * r * 1.2, sin(a * 3.0) * r * 0.5)
		"eight":
			return c + Vector2(sin(a) * r * 1.2, sin(a * 2.0) * r * 0.6)
		_:  # square: 네 변을 차례로
			var k := u * 4.0
			var side := int(k)
			var f := k - side
			var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
			var from: Vector2 = corners[side % 4]
			var to: Vector2 = corners[(side + 1) % 4]
			return c + from.lerp(to, f) * Vector2(r, r * 0.8)


## 지금 단어가 보이는가(덫을 놓는 동안은 숨는다)
func visible() -> bool:
	return phase != "place"


## 캐릭터를 움직인다. 지켜보는 중이면 단어들이 숨는다.
func move_hero(p: Vector2) -> void:
	if finished or phase == "hunt":
		return
	phase = "place"
	hero_target = p


## 덫 하나를 p에 놓는다(tray의 k번째). 캐릭터가 그 자리로 간다.
func place_trap(k: int, p: Vector2) -> bool:
	if finished or phase == "hunt" or k < 0 or k >= tray.size():
		return false
	move_hero(p)
	traps.append({"w": tray[k], "pos": p, "used": false})
	tray.remove_at(k)
	return true


## 놓은 덫을 다시 집는다.
func pick_trap(i: int) -> bool:
	if phase != "place" or i < 0 or i >= traps.size():
		return false
	tray.append(traps[i]["w"])
	move_hero(traps[i]["pos"])
	traps.remove_at(i)
	return true


## 다시 숨는다 → 사냥 시작.
func hide() -> bool:
	if phase != "place":
		return false
	phase = "hunt"
	t = 0.0
	hero_target = HIDE
	return true


func _tick(dt: float) -> void:
	hero = hero.move_toward(hero_target, float(cfg["hero_speed"]) * dt)
	if phase == "place":
		return
	t += dt
	if phase != "hunt":
		return
	for i in paths.size():
		if caught[i]:
			continue
		var p := pos(i, t)
		for tr in traps:
			if tr["used"] or p.distance_to(tr["pos"]) > float(cfg["catch_r"]):
				continue
			if words[tr["w"]].meaning == words[i].meaning:  # 뜻이 맞는 덫에만 걸린다
				tr["used"] = true
				caught[i] = true
				earn(words[i].id)
				events.append({"w": i, "pos": tr["pos"]})
				break
	if t >= period() or not false in caught:
		finish()
