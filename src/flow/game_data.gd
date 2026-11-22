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
var state: GameState
var save_prefix := "user://"  ## 테스트는 다른 앞머리를 써서 진짜 저장을 건드리지 않는다
var save_store := SaveStore.new()
var settings := SettingsStore.new()
var rng := RandomNumberGenerator.new()
var feedback: Dictionary = {}


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


## 진동(04-meta.md 2절). 옵션에서 끌 수 있다.
func vibrate(long: bool = false) -> void:
	if settings.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(int(feedback["long_ms" if long else "short_ms"]))


## 대사 안의 {hero}를 주인공 이름으로.
func say(key: String) -> String:
	return TranslationServer.translate(key).format({"hero": state.hero_name if state else ""})
