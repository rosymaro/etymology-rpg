extends Node
## 전역 객체(autoload) 셋 중 하나: 저장 상태와 규칙 객체를 갖는다(architecture.md 7절).

const UNIT_CHARS: Array[String] = ["ttukttak", "deopseok", "hilkkeum", "cheokcheok", "jojal", "ssaeng",
	"yeongcha", "daejang", "hwik", "bingeul", "kkumjjeok", "wajang"]

var repo: WordRepository
var bal: Balance
var rules: ProgressRules
var evolution: EvolutionRule
var coin_source: CoinSource
var setup: BattleSetup
var quests: QuestBook
var curriculum: Curriculum
var learning: Dictionary = {}  ## data/balance/learning.json
var hunt_cfg: Dictionary = {}  ## data/balance/field_hunt.json
var field: Dictionary = {}  ## data/balance/field.json
var state: GameState
var save_prefix := "user://"  ## 테스트는 다른 앞머리를 써서 진짜 저장을 건드리지 않는다
var save_store := SaveStore.new()
var settings := SettingsStore.new()
var rng := RandomNumberGenerator.new()
var feedback: Dictionary = {}
var resume_path := "user://resume.cfg"  ## 다른 앱을 보다 돌아왔을 때 이어서 할 곳(04-meta.md)
## 테스트·화면 캡처에서는 이어 하기를 끈다(앞 테스트가 남긴 곳으로 시작하지 않게). 이어 하기 테스트만 켠다.
var resume_enabled := _resume_allowed()
## 튜토리얼(08-tutorial.md): 테스트·화면 캡처에서는 끈다(튜토리얼 테스트만 켠다).
var tutorials_enabled := _resume_allowed()


func _ready() -> void:
	rng.randomize()
	settings.load_settings()
	feedback = JsonFile.read("res://data/feedback.json")
	repo = WordRepository.load_default()
	bal = Balance.load_default()
	rules = ProgressRules.new(repo, bal)
	evolution = EvolutionRule.new(repo)
	coin_source = CoinSource.new(rng)
	setup = BattleSetup.new(repo, bal, rules, coin_source)
	quests = QuestBook.load_default()
	curriculum = Curriculum.load_default()
	learning = JsonFile.read("res://data/balance/learning.json")
	hunt_cfg = JsonFile.read("res://data/balance/field_hunt.json")
	field = JsonFile.read("res://data/balance/field.json")
	TranslationServer.set_locale("ko")


## 개발자 모드는 따로 저장해서 스토리 저장을 건드리지 않는다.
func use_dev_save(dev: bool) -> void:
	save_store = SaveStore.new(save_prefix + ("dev_save.json" if dev else "save.json"))


func new_game(hero_name: String) -> void:
	state = GameState.new()
	state.hero_name = hero_name


func continue_game() -> bool:
	state = save_store.load_state()
	return state != null


func save() -> void:
	if state:
		save_store.save(state)


static func _resume_allowed() -> bool:
	for a in OS.get_cmdline_args():
		if a.ends_with("gut_cmdln.gd"):
			return false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			return false
	return true


## 지금 하던 곳을 적어 둔다. mode: "story" | "dev" | "mini" | ""(타이틀). 앱이 다시 켜지면 여기로 돌아간다.
## 빈 mode는 이어 하기를 지운다(타이틀로 돌아갔거나 앱을 제대로 끝냈을 때).
func set_resume(mode: String) -> void:
	if not resume_enabled:
		return
	_write_resume(mode, {} if mode == "" else resume_route())


## 어느 화면이었는지: {"s": "field"|"dex"|"party"|"forge"|"options"|"quiz"|"prep"|"evolve_quiz"|"minigame"|"mini_hub", …}
func set_route(route: Dictionary) -> void:
	if not resume_enabled or resume_mode() == "":
		return
	_write_resume(resume_mode(), route)


## 지금 화면의 진행(퀴즈 몇 번째, 전투 몇 단계)만 고쳐 적는다. 화면 종류 s가 다르면 그대로 둔다.
func patch_route(s: String, d: Dictionary) -> void:
	var r := resume_route()
	if not resume_enabled or r.get("s", "") != s:
		return
	r.merge(d, true)
	_write_resume(resume_mode(), r)


func _write_resume(mode: String, route: Dictionary) -> void:
	var cf := ConfigFile.new()
	cf.set_value("resume", "mode", mode)
	cf.set_value("resume", "route", JSON.stringify(route))
	cf.save(resume_path)


func resume_mode() -> String:
	if not resume_enabled:
		return ""
	var cf := ConfigFile.new()
	if cf.load(resume_path) != OK:
		return ""
	return String(cf.get_value("resume", "mode", ""))


func resume_route() -> Dictionary:
	var cf := ConfigFile.new()
	if not resume_enabled or cf.load(resume_path) != OK:
		return {}
	var r = JSON.parse_string(String(cf.get_value("resume", "route", "{}")))
	return r if r is Dictionary else {}


## 진동(04-meta.md 2절). 옵션에서 끌 수 있다.
func vibrate(long: bool = false) -> void:
	if settings.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(int(feedback["long_ms" if long else "short_ms"]))


## 대사 안의 {hero}를 주인공 이름으로.
func say(key: String) -> String:
	return TranslationServer.translate(key).format({"hero": state.hero_name if state else ""})


var puzzles := {}  ## 퍼즐 id -> PushPuzzle(돌 자리는 화면이 바뀌어도 남는다, 저장은 안 함)


## 필드 사냥 나들이(상태는 state.hunt에 있어서 화면이 바뀌어도, 저장해도 남는다).
func hunt_run() -> HuntRun:
	return HuntRun.new(state.hunt, hunt_cfg)
