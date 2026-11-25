class_name InferenceQuiz
extends RefCounted
## 유추 문제 만들기(06-learning.md 2절 사다리). 단어 + 지금 스테이지 + 조각 익숙함 → 무엇을 보여 주고 숨길지.
## 보기는 뜻 4개(QuizBuilder와 같다). 고른 뒤에는 언제나 풀이(조각 뜻 → 단어 뜻)를 보여 준다(화면).
##
## 문제 종류: "infer"(배운 조각이 든 단어) | "meaning"(아니면 지금처럼 뜻 문제, 풀이로 어원만 보여 준다)
## 단계: A 나눠 주고 조각 뜻도 보임 / B 나눠 주되 배운 조각 뜻은 숨김 / C 이후 나누지 않음(배운 조각은 스스로 찾는다)

var curriculum: Curriculum
var bal: Dictionary
var builder: QuizBuilder
var repo: WordRepository


func _init(words: WordRepository, cur: Curriculum, learning_balance: Dictionary, rng: RandomNumberGenerator) -> void:
	repo = words
	curriculum = cur
	bal = learning_balance
	builder = QuizBuilder.new(words, rng)


func step_of(stage: int) -> String:
	for k in bal["steps"]:
		var r: Array = bal["steps"][k]
		if stage >= int(r[0]) and stage <= int(r[1]):
			return k
	return "E"


static func _next(step: String) -> String:
	return {"A": "B", "B": "C", "C": "D", "D": "E"}.get(step, "E")


## 문제 하나. familiar: 조각 id -> 맞힌 수(GameState.pieces의 right).
## step_bonus: 단계를 그만큼 올린다(뿌리먹이의 어려운 문제, 07-fun 1절).
func question(id: String, stage: int, familiar: Dictionary = {}, step_bonus: int = 0) -> InferenceQuestion:
	var base := builder.question(id)
	var q := InferenceQuestion.new()
	q.word_id = id
	q.options = base.options
	q.answer = base.answer
	var w := repo.get_word(id)
	q.parts = PieceSplit.split(w.id, w.etym)
	var learned := curriculum.learned(stage)
	q.step = step_of(stage)
	for k in step_bonus:
		q.step = _next(q.step)
	q.kind = "meaning"
	for p in q.parts:
		var pid := String(p["piece"])
		p["learned"] = pid != "" and learned.has(pid)
		if p["learned"]:
			q.kind = "infer"
			q.learned.append(pid)
	q.show_split = q.kind == "infer" and q.step in ["A", "B"]
	for p in q.parts:
		var st := q.step
		if p["learned"] and int(familiar.get(p["piece"], 0)) >= int(bal["familiar_right"]):
			st = _next(st)  # 잘 아는 조각은 한 단계 앞당겨 숨긴다
		# 보여 주는가: 조각이 아닌 글자는 뜻이 없다. 안 배운 조각은 언제나 뜻을 보여 준다(도움). 배운 조각은 A에서만.
		p["shown"] = p["piece"] != "" and (not p["learned"] or st == "A")
	return q


## 맞히거나 틀린 뒤 조각 익숙함을 남긴다. pieces: GameState.pieces(id -> {seen, right}).
static func record(pieces: Dictionary, q: InferenceQuestion, ok: bool) -> void:
	for pid in q.learned:
		var r: Dictionary = pieces.get(pid, {"seen": 0, "right": 0})
		r["seen"] = int(r["seen"]) + 1
		if ok:
			r["right"] = int(r["right"]) + 1
		pieces[pid] = r


static func familiar_of(pieces: Dictionary) -> Dictionary:
	var out := {}
	for k in pieces:
		out[k] = int(pieces[k].get("right", 0))
	return out
