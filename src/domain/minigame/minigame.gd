class_name Minigame
extends RefCounted
## 미니게임 규칙의 겉모양(architecture.md 3절 '미니게임'). 화면 없이 돌아가고 테스트한다.
## words = 이 판에 쓰는 단어(보상 후보). earned = 이 판에서 얻은 단어(최대 max_words개).

var words: Array[WordData] = []
var cfg: Dictionary = {}
var rng: RandomNumberGenerator
var max_words := 5
var earned: Array[String] = []
var finished := false
var time_left := 0.0  ## 시간 제한이 없으면 0


func setup(pool: Array[WordData], game_cfg: Dictionary, max_w: int, random: RandomNumberGenerator) -> void:
	words = pool
	cfg = game_cfg
	max_words = max_w
	rng = random
	time_left = float(cfg.get("duration", 0))
	_build()


func _build() -> void:
	pass


## 시간이 흐른다. 시간 제한이 있는 게임은 0이 되면 끝난다.
func update(dt: float) -> void:
	if finished:
		return
	if cfg.has("duration"):
		time_left -= dt
		if time_left <= 0.0:
			time_left = 0.0
			finish()
	_tick(dt)


func _tick(_dt: float) -> void:
	pass


func earn(word_id: String) -> void:
	if earned.size() < max_words and not word_id in earned and word_id != "":
		earned.append(word_id)
	if earned.size() >= max_words:
		finish()


func finish() -> void:
	finished = true


func score() -> int:
	return earned.size()


func word_at(i: int) -> WordData:
	return words[i % words.size()] if not words.is_empty() else null


## 영어 글자만 있는 단어(철자 퍼즐용).
static func letters_only(w: WordData, min_len: int, max_len: int) -> bool:
	var s := w.id.to_lower()
	if s.length() < min_len or s.length() > max_len:
		return false
	for ch in s:
		if ch < "a" or ch > "z":
			return false
	return true
