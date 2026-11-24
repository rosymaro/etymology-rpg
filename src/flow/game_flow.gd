class_name GameFlow
extends RefCounted
## 게임 흐름(architecture.md 8절): 타이틀 → 이름 → 이야기 → 필드 ↔ 조우·퀴즈 → 전투 준비 → 전투 → 결과.
## 화면은 '무엇이 눌렸다'만 알리고, 다음 화면은 여기서 정한다. 흐름이 바뀌면 이 파일만 고친다.

const STAGE := 1
const JOIN_CHEOK_AFTER := 5  ## 알기 유닛이 합류하는 포획 수(s01_skit_cheok). 이야기 진행 값이라 여기 둔다

var main: Main


func _init(m: Main) -> void:
	main = m


## 앱을 켤 때: 하던 곳이 적혀 있으면(다른 앱을 보다 와서 앱이 다시 켜졌을 때) 거기서 이어 한다.
func start() -> void:
	match GameData.resume_mode():
		"story", "dev":
			var dev := GameData.resume_mode() == "dev"
			GameData.use_dev_save(dev)
			if GameData.continue_game():
				go_field()
				return
		"mini":
			go_minigames()
			return
	main.show_screen(TitleScreen.new())


func go_title() -> void:
	GameData.set_resume("")
	main.show_screen(TitleScreen.new())


func go_options(back: Callable) -> void:
	main.show_screen(OptionsScreen.new(), {"back": back})


func new_game() -> void:
	GameData.use_dev_save(false)
	GameData.save_store.erase()
	main.show_screen(NameScreen.new())


## 개발자 모드(스토리): 모든 단어·유닛·마법·장비를 갖추고 평가를 위해 바로 필드에서 시작한다. 저장은 따로.
func dev_game() -> void:
	GameData.use_dev_save(true)
	GameData.new_game(TranslationServer.translate("ui.dev.name"))
	var s := GameData.state
	s.dev_mode = true
	var all: Array[String] = []
	for m in GameData.bal.magic["magics"]:
		all.append(str(m["id"]))
	GameData.rules.grant_all(s, all)
	for k in ["s01_ki", "s01_tut_battle", "s01_skit_cheok", "s01_tut_evolve"]:
		_flag(k)
	s.pos = Vector2(950, 760)
	GameData.save()
	GameData.set_resume("dev")
	go_field(TranslationServer.translate("ui.dev.started").format({"count": s.dex_count()}))


# ----- 미니게임 -----

static func _views() -> Dictionary:
	return {
		"order": OrderView, "trap": TrapView, "search": SearchView, "kite": KiteView, "fishing": FishingView,
		"copy": CopyView, "wheel": MoatView, "guard": GuardView, "ore": OreView, "pattern": PatternView,
	}


func go_minigames() -> void:
	GameData.set_resume("mini")
	main.show_screen(MinigameHubScreen.new())


## mode "free": 미니게임 메뉴(보상 없음, 그 마을 단어로). "story": 마을에서(아직 못 얻은 마을 단어로, 끝나면 뜻 문제).
func play_minigame(id: String, mode: String) -> void:
	var def := MinigameRegistry.game_def(id)
	var pool := _minigame_pool(int(def["stage"]), mode == "story", int(def.get("min_etym", 0)))
	if def.get("pool", "") == "root_pair":
		pool = _root_pair_pool(int(def["stage"]))
	var game := MinigameRegistry.make(id, pool, GameData.bal.minigames, GameData.rng)
	main.show_screen(_views()[id].new(), {"id": id, "mode": mode, "game": game})


## 광석 캐기: 그 스테이지 단어(마을 먼저, 필드까지)에서 가장 많이 쓰인 어근 2개를 고르고,
## 그 어근이 든 단어(최대 8개)와 들지 않은 단어로 판을 채운다.
func _root_pair_pool(stage: int) -> Array[WordData]:
	var all: Array[WordData] = GameData.repo.first_tier(stage, "town") + GameData.repo.first_tier(stage, "field")
	var count := {}
	for w in all:
		for e in w.etym:
			var k := OreSlashGame.key(e)
			if k != "" and OreSlashGame.is_stem(k):
				count[k] = int(count.get(k, 0)) + 1
	var ks: Array = count.keys()
	ks.sort_custom(func(a: String, b: String) -> bool: return count[a] > count[b])
	var pick: Array = ks.slice(0, 2)
	var hit: Array[WordData] = []
	var miss: Array[WordData] = []
	for w in all:
		var has := false
		for e in w.etym:
			has = has or OreSlashGame.key(e) in pick
		if has:
			hit.append(w)
		elif not w.etym.is_empty():
			miss.append(w)
	hit.shuffle()
	hit.sort_custom(func(a: WordData, b: WordData) -> bool: return a.obtain == "town" and b.obtain != "town")
	miss.shuffle()
	var need := int(GameData.bal.minigames.get("pool_size", 16))
	var out: Array[WordData] = hit.slice(0, 8)
	for w in miss:
		if out.size() >= need:
			break
		out.append(w)
	return out


## 01-rpg-base: 미니게임 단어는 그 마을에 배정된 단어 중 아직 못 얻은 것에서 고른다. 모자라면 얻은 것도 섞는다.
## min_etym > 0이면 어원 조각이 그만큼 있는 단어를 앞에 둔다(문양 잇기). 마을 단어로 모자라면 그 스테이지 필드 단어에서 채운다.
func _minigame_pool(stage: int, story: bool, min_etym: int = 0) -> Array[WordData]:
	var town := GameData.repo.first_tier(stage, "town")
	var fresh: Array[WordData] = []
	var old: Array[WordData] = []
	if min_etym > 0:
		var rich: Array[WordData] = []
		for w in town + GameData.repo.first_tier(stage, "field"):
			if w.etym.size() >= min_etym:
				rich.append(w)
		rich.shuffle()
		rich.sort_custom(func(a: WordData, b: WordData) -> bool: return a.obtain == "town" and b.obtain != "town")
		var out: Array[WordData] = []
		for w in rich:
			if out.size() >= int(GameData.bal.minigames.get("pool_size", 16)):
				break
			out.append(w)
		return out
	for w in town:
		if story and GameData.state and GameData.state.has_word(w.id):
			old.append(w)
		else:
			fresh.append(w)
	fresh.shuffle()
	old.shuffle()
	var need := int(GameData.bal.minigames.get("pool_size", 16))
	while fresh.size() < need and not old.is_empty():
		fresh.append(old.pop_back())
	if fresh.size() < need:
		for w in GameData.repo.first_tier(stage):
			if fresh.size() >= need:
				break
			if not w in fresh:
				fresh.append(w)
	return fresh


## 마을 미니게임이 끝남: 얻은 단어마다 뜻 4지선다, 맞힌 단어만 갖는다(01-rpg-base '단어 시험').
func minigame_finished(_id: String, earned: Array[String]) -> void:
	if earned.is_empty():
		go_field(TranslationServer.translate("ui.board.none"))
		return
	main.show_screen(QuizScreen.new(), {"words": earned, "mode": "minigame",
		"done": func(right: Array[bool]) -> void:
			var got: Array[String] = []
			for i in earned.size():
				if right[i]:
					got.append(earned[i])
			if got.is_empty():
				go_field(TranslationServer.translate("ui.board.none"))
			else:
				_give_words(got, "ui.result.minigame")})

func name_entered(hero_name: String) -> void:
	GameData.new_game(hero_name)
	GameData.set_resume("story")
	main.play_scene("s01_intro", func() -> void:
		main.play_scene("s01_ki", func() -> void:
			_flag("s01_ki")
			GameData.save()
			go_field()))


func continue_game() -> void:
	GameData.use_dev_save(false)
	if GameData.continue_game():
		GameData.set_resume("story")
		go_field()
	else:
		new_game()


func go_field(msg: String = "") -> void:
	main.show_screen(FieldScreen.new(), {"msg": msg})


func _flag(k: String) -> void:
	GameData.state.flags[k] = true


func seen(k: String) -> bool:
	return GameData.state.flags.get(k, false)


# ----- 필드에서 일어나는 일 -----

func entered_field() -> void:
	if not seen("s01_tut_battle"):
		_flag("s01_tut_battle")
		main.play_scene("s01_tut_battle", func() -> void: pass)


## 필드 적과 부딪힘: 단어 n개 조우 퀴즈.
func encounter(word_ids: Array[String]) -> void:
	GameData.vibrate()
	main.show_screen(QuizScreen.new(), {"words": word_ids, "mode": "encounter",
		"done": func(right: Array[bool]) -> void: _after_encounter(word_ids, right)})


func _after_encounter(word_ids: Array[String], right: Array[bool]) -> void:
	if not right.has(false):
		_give_words(word_ids, "ui.result.caught_all")
	else:
		go_battle_prep(word_ids, false)


## 마을 미니게임(스테이지 1: 주문 제작). 마을 단어는 이것으로만 얻는다(01-rpg-base '마을과 특수 행위').
func town_minigame() -> void:
	play_minigame(MinigameRegistry.for_stage(STAGE)["id"], "story")


## (옛) 게시판 퀴즈. 미니게임이 생겨 쓰지 않지만 테스트를 위해 남긴다.
func board_quiz(word_ids: Array[String]) -> void:
	main.show_screen(QuizScreen.new(), {"words": word_ids, "mode": "board",
		"done": func(right: Array[bool]) -> void:
			var got: Array[String] = []
			for i in word_ids.size():
				if right[i]:
					got.append(word_ids[i])
			if got.is_empty():
				go_field(TranslationServer.translate("ui.board.none"))
			else:
				_give_words(got, "ui.result.board")})


func go_battle_prep(word_ids: Array[String], boss: bool) -> void:
	main.show_screen(BattlePrepScreen.new(), {"words": word_ids, "boss": boss})


## 전투 준비가 끝남: 마법과 어근이 정해졌다.
func start_battle(party: Array[int], roots: Dictionary, magic_id: String, word_ids: Array[String], boss: bool) -> void:
	var s := GameData.state
	for u in roots:
		s.chosen_roots[u] = roots[u]
	var ctx := GameData.setup.make_context(s, party, roots, magic_id)
	var ids := word_ids
	if boss:
		ids = GameData.setup.boss_enemies(ctx, s, STAGE)
	else:
		GameData.setup.field_enemies(ctx, word_ids, STAGE)
	var result := BattleEngine.new(ctx).run()
	main.show_screen(BattleScreen.new(), {"ctx": ctx, "result": result, "words": ids, "boss": boss,
		"party": party})


func battle_finished(result: BattleResult, word_ids: Array[String], boss: bool, history: Array[Dictionary] = []) -> void:
	var won := RewardRule.words_won(result, word_ids, GameData.coin_source)
	if boss:
		if result.won():
			_boss_won()
			return
		go_field(TranslationServer.translate("ui.boss.lost"))
		GameData.save()
		return
	if won.is_empty():
		GameData.save()
		go_field(TranslationServer.translate("ui.result.none"))
	else:
		_give_words(won, "ui.result.won" if result.won() else "ui.result.partial", history)


func _give_words(ids: Array[String], title_key: String, history: Array[Dictionary] = []) -> void:
	var events: Array = []
	for id in ids:
		events.append(GameData.rules.gain_word(GameData.state, id))
		EventBus.word_captured.emit(id)
	GameData.save()
	main.show_screen(ResultScreen.new(), {"events": events, "title": title_key, "history": history,
		"done": func() -> void: _after_result()})


func _after_result() -> void:
	var s := GameData.state
	if not seen("s01_skit_cheok") and s.dex_count() >= JOIN_CHEOK_AFTER:
		_flag("s01_skit_cheok")
		if not 4 in s.joined:
			s.joined.append(4)
		GameData.save()
		go_field()
		main.play_scene("s01_skit_cheok", func() -> void:
			main.notice(TranslationServer.translate("ui.join").format({"name": UiKit.unit_name(4)})))
		return
	go_field()


# ----- 마을 -----

func go_forge() -> void:
	if not seen("s01_tut_evolve"):
		_flag("s01_tut_evolve")
		main.play_scene("s01_tut_evolve", func() -> void: main.show_screen(EvolveScreen.new()))
		return
	main.show_screen(EvolveScreen.new())


func evolve_quiz(word_id: String) -> void:
	var words := GameData.evolution.quiz_words(word_id)
	main.show_screen(QuizScreen.new(), {"words": words, "mode": "evolve", "target": word_id,
		"done": func(right: Array[bool]) -> void: _after_evolve(word_id, words, right)})


func _after_evolve(word_id: String, words: Array[String], right: Array[bool]) -> void:
	if not right.has(false):
		GameData.vibrate(true)
		_give_words([word_id] as Array[String], "ui.evolve.success")
		return
	var wrong: Array[String] = []
	for i in words.size():
		if not right[i]:
			wrong.append(words[i])
	var target := GameData.evolution.recapture_target(word_id, wrong)
	GameData.state.recapture[word_id] = target
	GameData.save()
	EventBus.evolution_failed.emit(target)
	main.show_screen(EvolveScreen.new())
	main.notice(TranslationServer.translate("ui.evolve.fail").format({"word": target}))


func go_dex() -> void:
	main.show_screen(DexScreen.new())


func go_party() -> void:
	main.show_screen(PartyScreen.new())


# ----- 보스 -----

func boss_gate() -> void:
	var g := GameData.rules.boss_gate(GameData.state, STAGE)
	if seen("boss_s01"):
		main.notice(TranslationServer.translate("ui.boss.already"))
		return
	if not g["open"]:
		main.notice(TranslationServer.translate("ui.boss.gate").format(g))
		return
	GameData.vibrate(true)
	main.play_scene("s01_jeon", func() -> void: go_battle_prep([] as Array[String], true))


func _boss_won() -> void:
	var s := GameData.state
	_flag("boss_s01")
	var bw := GameData.repo.boss_word(STAGE)
	GameData.rules.gain_word(s, bw.id)
	for m in ["sub", "re", "com"]:
		if not m in s.magics:
			s.magics.append(m)
	s.stage = maxi(s.stage, STAGE + 1)
	GameData.save()
	EventBus.boss_defeated.emit(STAGE)
	GameData.vibrate(true)
	main.play_scene("s01_gyeol", func() -> void:
		go_field()
		main.notice(TranslationServer.translate("ui.stage.clear")))
