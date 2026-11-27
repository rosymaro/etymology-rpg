class_name InferenceQuiz
extends RefCounted
## 유추 문제 만들기(06-learning.md 2절 사다리). 단어 + 지금 스테이지 + 조각 익숙함 → 무엇을 보여 주고 숨길지.
## 보기는 뜻 4개(QuizBuilder와 같다). 고른 뒤에는 언제나 풀이(조각 뜻 → 단어 뜻)를 보여 준다(화면).
##
## 문제 종류: "infer"(배운 조각이 든 단어) | "meaning"(아니면 뜻 문제). 조각 익숙함 기록에 쓴다.
## 단계(사용자 의견, 보스를 잡을수록 도움을 거둔다): A 나눠 주고 조각 뜻도 보임 / B 나눠 주되 조각 뜻은 ? / C 단어만
## 경계는 learning.json step_bosses(그 스테이지 보스를 잡기 전까지 그 단계).

var curriculum: Curriculum
var bal: Dictionary
var builder: QuizBuilder
var repo: WordRepository


func _init(words: WordRepository, cur: Curriculum, learning_balance: Dictionary, rng: RandomNumberGenerator) -> void:
	repo = words
	curriculum = cur
	bal = learning_balance
	builder = QuizBuilder.new(words, rng)


## 이긴 보스(GameState.flags의 boss_sNN)로 단계를 정한다.
func step_of(flags: Dictionary) -> String:
	var sb: Dictionary = bal["step_bosses"]
	for k in ["A", "B"]:
		if not flags.get("boss_s%02d" % int(sb[k]), false):
			return k
	return "C"


static func _next(step: String) -> String:
	return {"A": "B"}.get(step, "C")


## 문제 하나. stage: 지금 스테이지(배운 조각 → 문제 종류), flags: 이긴 보스(GameState.flags).
## step_bonus: 단계를 그만큼 올린다(뿌리먹이의 어려운 문제, 07-fun 1절).
func question(id: String, stage: int, flags: Dictionary = {}, step_bonus: int = 0) -> InferenceQuestion:
	var base := builder.question(id)
	var q := InferenceQuestion.new()
	q.word_id = id
	q.options = base.options
	q.answer = base.answer
	var w := repo.get_word(id)
	q.parts = PieceSplit.split(w.id, w.etym)
	var learned := curriculum.learned(stage)
	q.step = step_of(flags)
	for k in step_bonus:
		q.step = _next(q.step)
	q.kind = "meaning"
	var has_piece := false
	for p in q.parts:
		var pid := String(p["piece"])
		has_piece = has_piece or pid != ""
		p["learned"] = pid != "" and learned.has(pid)
		if p["learned"]:
			q.kind = "infer"
			q.learned.append(pid)
		# 조각이 아닌 글자는 뜻이 없다. 조각 뜻은 A에서만 보인다
		p["shown"] = pid != "" and q.step == "A"
	q.show_split = has_piece and q.step in ["A", "B"]
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
