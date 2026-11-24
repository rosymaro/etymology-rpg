class_name FactoryGame
extends Minigame
## 말 공방(05-minigames): 세 영역 [에너그램] - [어원 조합] - [단어 뜻]이 옆으로 이어진 한 무대.
## 미니게임 1~10은 이 규칙 하나에 기능을 켜고 끈다(수치·기능은 data/balance/minigames.json "factory" + "fNN").
## 칠판: 이번 판 단어 'ab + duc = abduct → 유괴하다'. 칠판 단어를 모두 확보하면 성공, max_miss번 틀리면 끝.
##
## 벨트: 사각형 한 바퀴를 t(0~1)로 센다. 에너그램 영역이 있으면 t < 0.5가 에너그램 쪽(왼쪽 절반), 나머지가 어원 조합 쪽.
## 어원은 entry_t에서 벨트에 오른다. 에너그램만 있는 게임(2)은 exit_t를 넘으면 벨트 너머로 사라지고 그 단어 몫으로 센다.
##
## 용광로: absorb = 0이면 어원을 넣고 두드려 단어 하나를 만든다(틀리면 1번 틀림, 넣은 어원은 탄다).
## absorb = N이면 단어 N개 몫의 어원을 흡수한다(0/N → N/N). N/N이면 달아오르고, 누르면 단어찾기.
## 단어찾기는 단어 하나에 search_sec초. 시간이 다 되면 못 찾은 단어는 어원이 다시 벨트로 돌아온다(틀림 아님).
##
## 단어 뜻: 만든(찾은) 단어가 칠판 아래 쌓이고, 뜻 shelf_slots칸 진열대의 맞는 칸에 놓으면 확보. 틀리면 1번 틀림.
## 맞게 놓은 칸은 다음 단어의 뜻으로 바뀐다.

const ANAGRAM := "anagram"
const COMBINE := "combine"
const SHELF := "shelf"
const FALLBACK_TRAPS := ["ab", "con", "ex", "pre", "re", "dis", "sub", "trans", "per", "pro", "ob", "inter", "mis", "un"]

## 칠판 단어 상태
const TODO := "todo"  ## 아직 만들지 않음
const SEARCH := "search"  ## 흡수됐고 단어찾기를 기다림(또는 하는 중)
const STACK := "stack"  ## 진열대 앞에 쌓임
const DONE := "done"  ## 확보

var board: Array[Dictionary] = []  ## {id, forms, meaning, state}
var belt: Array[Dictionary] = []  ## {uid, form, t, trap}
var outbox: Array[String] = []  ## 벨트에 오르기를 기다리는 어원(에너그램에서 만든 것, 돌아오는 것)
var furnace: Array[Dictionary] = []  ## 두드리기 전 용광로 안 어원(absorb = 0)
var credit := {}  ## 칠판 순번 -> 이미 받은 어원 형태들(흡수·벨트 너머로)
var batch: Array[int] = []  ## 흡수를 마친 단어(단어찾기를 기다린다)
var hot := false  ## 용광로가 달아올랐다(누르면 단어찾기)
var search: LetterGrid  ## 단어찾기 중이면 글자판
var search_left := 0.0
var search_words: Array[int] = []
var stack: Array[int] = []  ## 진열대 앞에 쌓인 단어(칠판 순번)
var slots: Array[int] = []  ## 진열대 칸마다 보여 주는 뜻(칠판 순번, 비면 -1)
var puzzle := {}  ## 에너그램 문제 {form, letters, trap}
var misses := 0
var traps: Array[String] = []
var last := ""  ## 마지막에 일어난 일(화면 알림용): made, burnt, absorbed, hot, wrong_shelf, shelved, exited…
var _uid := 0


## 그 게임의 설정: 모두 같은 값(factory) 위에 그 게임 값(fNN)을 덮어쓴다.
static func config(balance: Dictionary, id: String) -> Dictionary:
	var c: Dictionary = balance.get("factory", {}).duplicate(true)
	c.merge(balance.get(id, {}), true)
	return c


func _build() -> void:
	_pick_board()
	max_words = board.size()
	_pick_traps()
	slots.resize(int(cfg.get("shelf_slots", 5)))
	slots.fill(-1)
	if areas() == [SHELF]:  # 단어 뜻만: 칠판 단어가 처음부터 모두 쌓여 있다
		var order: Array[int] = []
		for i in board.size():
			order.append(i)
		_shuffle(order)
		for i in order:
			_to_stack(i)
	_refill_slots()
	if has(ANAGRAM):
		_next_puzzle()


# ----- 설정 -----

func areas() -> Array:
	return cfg.get("areas", [COMBINE])


func has(area: String) -> bool:
	return area in areas()


func absorb_n() -> int:
	return int(cfg.get("absorb", 0))


func feed_auto() -> bool:
	return not has(ANAGRAM)


func _pick_board() -> void:
	var n := int(cfg.get("board", 10))
	var max_len := int(cfg.get("max_len", 12))
	for w in words:
		if board.size() >= n:
			break
		if w.forms().is_empty() or not Minigame.letters_only(w, 3, max_len):
			continue
		var dup := false
		for b in board:
			dup = dup or b["id"] == w.id
		if not dup:
			board.append({"id": w.id, "forms": w.forms(), "meaning": w.meaning, "state": TODO})


## 함정 어원: 이 판에 안 쓰는 단어들의 어원 형태(칠판 단어 어원과 겹치지 않게).
func _pick_traps() -> void:
	var used := {}
	for b in board:
		for f in b["forms"]:
			used[f] = true
	for w in words:
		for f in w.forms():
			if f.length() >= 2 and not used.has(f) and not f in traps:
				traps.append(f)
	if traps.size() < 4:
		for f in FALLBACK_TRAPS:
			if not used.has(f) and not f in traps:
				traps.append(f)
	_shuffle(traps)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x: Variant = a[i]
		a[i] = a[j]
		a[j] = x


# ----- 무엇이 아직 필요한가 -----

## 아직 받아야 할 어원 형태(단어마다). 두드리기 게임은 단어 전체, 흡수·벨트 너머 게임은 받은 것을 뺀 나머지.
func remaining(i: int) -> Array[String]:
	var need: Array[String] = []
	for f in board[i]["forms"]:
		need.append(f)
	for f in credit.get(i, []):
		need.erase(f)
	return need


## 지금 벨트·용광로·기다리는 줄·에너그램 문제에 없어서 더 만들어야 하는 어원(칠판 순서대로, 겹치면 여러 번).
func missing_forms() -> Array[String]:
	var have: Array[String] = []
	for it in belt:
		have.append(it["form"])
	for it in furnace:
		have.append(it["form"])
	for f in outbox:
		have.append(f)
	if not puzzle.is_empty():
		have.append(puzzle["form"])
	var out: Array[String] = []
	for i in board.size():
		if board[i]["state"] != TODO:
			continue
		for f in remaining(i):
			if f in have:
				have.erase(f)
			else:
				out.append(f)
	return out


func todo_count() -> int:
	var n := 0
	for b in board:
		n += 1 if b["state"] == TODO else 0
	return n


func done_count() -> int:
	return earned.size()


# ----- 시간 -----

func _tick(dt: float) -> void:
	if search:  # 단어찾기 중에는 공방이 멈춘다
		search_left -= dt
		if search_left <= 0.0:
			search_left = 0.0
			close_search()
		return
	var speed := float(cfg.get("belt_speed", 0.06))
	var exit_t := float(cfg.get("exit_t", 0.5))
	var fur_t := float(cfg.get("furnace_t", 0.75))
	var gone: Array[Dictionary] = []
	for it in belt:
		var t0: float = it["t"]
		var t1 := t0 + speed * dt
		if has(ANAGRAM) and not has(COMBINE) and t1 >= exit_t:  # 벨트 너머로
			gone.append(it)
			continue
		if absorb_n() > 0 and bool(cfg.get("auto_absorb", false)) and _crossed(t0, t1, fur_t) and _absorb(it["form"]):
			gone.append(it)
			continue
		it["t"] = fmod(t1, 1.0)
	for it in gone:
		belt.erase(it)
		if has(ANAGRAM) and not has(COMBINE):
			_exited(it["form"])
	_feed()


## t0 → t1(1을 넘어 한 바퀴 돌 수 있다)로 가는 동안 at을 지났는가.
static func _crossed(t0: float, t1: float, at: float) -> bool:
	var a := at if at > t0 else at + 1.0
	return t0 < a and a <= t1


## 벨트에 빈자리가 있으면 어원을 올린다(entry_t 둘레가 비어 있을 때만).
func _feed() -> void:
	var entry := float(cfg.get("entry_t", 0.0))
	if not _gap_free(entry):
		return
	if not outbox.is_empty():
		_put_on_belt(outbox.pop_front(), entry, false)
		return
	if not feed_auto() or belt.size() >= int(cfg.get("belt_cap", 12)):
		return
	var need := missing_forms()
	var trap_on := 0
	for it in belt:
		trap_on += 1 if it["trap"] else 0
	var want_trap := trap_on < int(cfg.get("traps", 0)) and not traps.is_empty() and (need.is_empty() or rng.randf() < 0.35)
	if want_trap:
		_put_on_belt(traps[rng.randi_range(0, traps.size() - 1)], entry, true)
	elif not need.is_empty():
		_put_on_belt(need[rng.randi_range(0, mini(need.size(), 4) - 1)], entry, false)


func _gap_free(at: float) -> bool:
	var gap := float(cfg.get("min_gap", 0.07))
	for it in belt:
		var d := absf(float(it["t"]) - at)
		if minf(d, 1.0 - d) < gap:
			return false
	return true


func _put_on_belt(form: String, at: float, trap: bool) -> Dictionary:
	_uid += 1
	var it := {"uid": _uid, "form": form, "t": at, "trap": trap}
	belt.append(it)
	return it


func item(uid: int) -> Dictionary:
	for it in belt:
		if it["uid"] == uid:
			return it
	return {}


## 벨트 위 어원이 어느 영역에 보이는가.
func section(it: Dictionary) -> String:
	if has(ANAGRAM) and has(COMBINE):
		return ANAGRAM if float(it["t"]) < 0.5 else COMBINE
	return ANAGRAM if has(ANAGRAM) else COMBINE


# ----- 에너그램 -----

func _next_puzzle() -> void:
	puzzle = {}
	var need := missing_forms()
	var trap := false
	var form := ""
	var trap_on := bool(cfg.get("anagram_traps", false)) and not traps.is_empty()
	if trap_on and (need.is_empty() or rng.randf() < float(cfg.get("trap_ratio", 0.35))):
		form = traps[rng.randi_range(0, traps.size() - 1)]
		trap = true
	elif not need.is_empty():
		form = need[0]
	if form == "":
		return
	var letters: Array[String] = []
	for ch in form:
		letters.append(ch)
	if form.length() > 1:
		for k in 12:
			_shuffle(letters)
			if "".join(letters) != form:
				break
	puzzle = {"form": form, "letters": letters, "trap": trap}


## 에너그램 답을 낸다. "ok"(벨트로 올라감) | "wrong"(글자 순서가 틀림. 미니게임 2만 1번 틀림) | "none"
func submit(answer: String) -> String:
	if finished or puzzle.is_empty():
		return "none"
	if answer.to_lower() != puzzle["form"]:
		last = "wrong_anagram"
		if bool(cfg.get("anagram_miss", false)):
			_miss()
		return "wrong"
	outbox.append(puzzle["form"])
	last = "anagram_ok"
	_next_puzzle()
	return "ok"


## 쓸모없는 어원은 만들지 않고 넘긴다(필요한 어원이면 나중에 다시 나온다).
func skip() -> bool:
	if not bool(cfg.get("skip", false)) or puzzle.is_empty():
		return false
	_next_puzzle()
	return true


## 에너그램 쪽 벨트 위 어원을 쓰레기통에 버린다.
func trash(uid: int) -> bool:
	var it := item(uid)
	if it.is_empty() or not bool(cfg.get("trash", false)) or section(it) != ANAGRAM:
		return false
	belt.erase(it)
	last = "trashed"
	if puzzle.is_empty():
		_next_puzzle()
	return true


## 벨트 너머로 사라진 어원을 그 어원이 필요한 단어 몫으로 센다(가장 많이 모인 단어 먼저).
func _exited(form: String) -> void:
	var i := _credit_to(form)
	last = "exited"
	if i >= 0 and remaining(i).is_empty():
		_complete(i)
	if puzzle.is_empty():
		_next_puzzle()


func _credit_to(form: String) -> int:
	var best := -1
	for i in board.size():
		if board[i]["state"] != TODO or not form in remaining(i):
			continue
		if best < 0 or remaining(i).size() < remaining(best).size():
			best = i
	if best >= 0:
		var c: Array = credit.get(best, [])
		c.append(form)
		credit[best] = c
	return best


# ----- 용광로 -----

## 어원 조합 쪽 벨트에서 집어 용광로에 넣는다. absorb = 0: 넣어 두고 두드린다. absorb > 0: 바로 흡수하거나 튕겨 낸다.
## 돌려주는 값: "in" | "absorbed" | "miss"(필요 없는 어원) | "hot"(먼저 단어찾기) | "full" | "none"
func put(uid: int) -> String:
	var it := item(uid)
	if finished or it.is_empty() or section(it) != COMBINE:
		return "none"
	if absorb_n() > 0:
		if hot or search:
			return "hot"
		if _absorb(it["form"]):
			belt.erase(it)
			return "absorbed"
		last = "rejected"
		_miss()
		return "miss"
	if furnace.size() >= int(cfg.get("furnace_max", 4)):
		return "full"
	belt.erase(it)
	furnace.append(it)
	return "in"


## 용광로에서 꺼내 벨트로 돌려놓는다.
func take_out(k: int) -> void:
	if k < 0 or k >= furnace.size():
		return
	outbox.append(furnace[k]["form"])
	furnace.remove_at(k)


## 두드린다: 넣은 어원(순서 상관없이)이 아직 안 만든 칠판 단어와 같으면 그 단어가 된다. 아니면 타고 1번 틀림.
## 만든 단어의 칠판 순번(실패면 -1).
func hammer() -> int:
	if finished or furnace.is_empty() or absorb_n() > 0:
		return -1
	var got: Array[String] = []
	for it in furnace:
		got.append(it["form"])
	got.sort()
	furnace.clear()
	for i in board.size():
		if board[i]["state"] != TODO:
			continue
		var need: Array[String] = []
		for f in board[i]["forms"]:
			need.append(f)
		need.sort()
		if need == got:
			last = "made"
			_complete(i)
			return i
	last = "burnt"
	_miss()
	return -1


## 흡수: 그 어원이 필요한 단어 몫으로 받는다. 단어 하나 몫이 다 차면 흡수 수가 오르고, absorb개(남은 단어가 적으면 그만큼)면 달아오른다.
func _absorb(form: String) -> bool:
	if hot or search:
		return false
	var i := _credit_to(form)
	if i < 0:
		return false
	last = "absorbed"
	if remaining(i).is_empty():
		board[i]["state"] = SEARCH
		batch.append(i)
		if batch.size() >= mini(absorb_n(), batch.size() + todo_count()):
			hot = true
			last = "hot"
	return true


## 흡수 표시(0/5 → 5/5).
func absorb_shown() -> Vector2i:
	return Vector2i(batch.size(), mini(absorb_n(), batch.size() + todo_count()))


## 달아오른 용광로를 누르면 단어찾기가 열린다.
func open_search() -> bool:
	if not hot or search:
		return false
	var ids: Array[String] = []
	search_words = batch.duplicate()
	for i in search_words:
		ids.append(String(board[i]["id"]).to_lower())
	search = LetterGrid.make(ids, int(cfg.get("grid_min", 8)), int(cfg.get("grid_max", 13)), bool(cfg.get("search_reverse", false)), rng)
	search_left = float(cfg.get("search_sec", 15)) * ids.size()
	return true


## 단어찾기에서 고른다. 찾은 단어의 칠판 순번(아니면 -1).
func search_select(a: Vector2i, b: Vector2i) -> int:
	if search == null:
		return -1
	var id := search.select(a, b)
	if id == "":
		return -1
	var hit := -1
	for i in search_words:
		if String(board[i]["id"]).to_lower() == id:
			hit = i
	if hit >= 0:
		last = "found"
		_complete(hit)  # 찾자마자 확보(단어 뜻이 있으면 쌓임)
	if search and search.all_found():
		close_search()
	return hit


## 단어찾기를 닫는다: 못 찾은 단어는 어원이 벨트로 돌아온다(찾은 단어는 찾을 때 이미 확보했다).
func close_search() -> void:
	if search == null:
		return
	for i in search_words:
		if board[i]["state"] == SEARCH:  # 못 찾은 단어
			board[i]["state"] = TODO
			credit.erase(i)
			if not feed_auto():
				for f in board[i]["forms"]:
					outbox.append(f)
	search = null
	search_words.clear()
	batch.clear()
	hot = false
	last = "search_closed"


# ----- 단어 뜻 -----

## 만든 단어: 단어 뜻 영역이 있으면 쌓이고, 없으면 바로 확보.
func _complete(i: int) -> void:
	if has(SHELF):
		_to_stack(i)
	else:
		board[i]["state"] = DONE
		earn(board[i]["id"])


func _to_stack(i: int) -> void:
	board[i]["state"] = STACK
	stack.append(i)
	# 진열대에 그 뜻이 없으면, 아직 쌓이지 않은 단어 뜻 칸 하나를 이 단어 뜻으로 바꾼다
	if not i in slots:
		var k := slots.find(-1)
		if k < 0:
			for s in slots.size():
				if slots[s] >= 0 and not slots[s] in stack:
					k = s
					break
		if k >= 0:
			slots[k] = i


## 빈 진열대 칸을 채운다: 쌓인 단어 뜻 먼저, 그다음 아직 만들지 않은 단어 뜻.
func _refill_slots() -> void:
	for k in slots.size():
		if slots[k] >= 0:
			continue
		var pick := -1
		for i in stack:
			if not i in slots:
				pick = i
				break
		if pick < 0:
			for i in board.size():
				if board[i]["state"] in [TODO, SEARCH] and not i in slots:
					pick = i
					break
		slots[k] = pick


## 쌓인 단어 i를 진열대 칸 k에 놓는다. 뜻이 맞으면 확보(그 칸은 다음 뜻으로), 틀리면 1번 틀림.
func place(i: int, k: int) -> bool:
	if finished or not i in stack or k < 0 or k >= slots.size() or slots[k] < 0:
		return false
	if String(board[slots[k]]["meaning"]) != String(board[i]["meaning"]):
		last = "wrong_shelf"
		_miss()
		return false
	if slots[k] != i:  # 뜻이 같은 다른 단어 칸이면 칸을 바꿔 준다
		var other := slots.find(i)
		if other >= 0:
			slots[other] = slots[k]
	slots[k] = -1
	stack.erase(i)
	board[i]["state"] = DONE
	last = "shelved"
	earn(board[i]["id"])
	_refill_slots()
	return true


# ----- 공통 -----

func _miss() -> void:
	misses += 1
	if misses >= int(cfg.get("max_miss", 3)):
		finish()


func success() -> bool:
	return not board.is_empty() and earned.size() >= board.size()


## 칠판 한 줄: "ab + duc = abduct → 유괴하다; 납치하다"
func board_line(i: int) -> String:
	var b: Dictionary = board[i]
	return "%s = %s → %s" % [" + ".join(b["forms"]), b["id"], b["meaning"]]
