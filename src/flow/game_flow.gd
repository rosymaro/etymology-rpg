class_name GameFlow
extends RefCounted
## 게임 흐름(architecture.md 8절): 타이틀 → 이름 → 이야기 → 필드 ↔ 조우·퀴즈 → 전투 준비 → 전투 → 결과.
## 화면은 '무엇이 눌렸다'만 알리고, 다음 화면은 여기서 정한다. 흐름이 바뀌면 이 파일만 고친다.

const STAGE := 1
const MAX_STAGE := 1  ## 만들어 둔(갈 수 있는) 마지막 스테이지. 월드맵 문은 여기까지만 열린다
const JOIN_CHEOK_AFTER := 5  ## 알기 유닛이 합류하는 포획 수(s01_skit_cheok). 이야기 진행 값이라 여기 둔다

var main: Main


func _init(m: Main) -> void:
	main = m


## 앱을 켤 때: 하던 곳이 적혀 있으면(다른 앱을 보다 와서 안드로이드가 앱을 다시 켰을 때) 그 화면에서 이어 한다.
## 앱을 제대로 끝냈으면(Main._exit_tree) 지워져 있어 타이틀부터.
func start() -> void:
	var mode := GameData.resume_mode()
	var r := GameData.resume_route()
	match mode:
		"story", "dev":
			GameData.use_dev_save(mode == "dev")
			if GameData.continue_game():
				_restore(r)
				return
		"mini":
			if r.get("s", "") == "minigame":
				play_minigame(String(r["id"]), "free")
			else:
				go_minigames()
			return
	main.show_screen(TitleScreen.new())


static func _ids(a) -> Array[String]:
	var out: Array[String] = []
	for x in a:
		out.append(String(x))
	return out


## 적어 둔 화면을 다시 연다. 퀴즈는 처음 문제부터, 전투는 전투 준비부터(진행 중인 판의 세부는 남기지 않는다).
func _restore(r: Dictionary) -> void:
	match String(r.get("s", "field")):
		"dex":
			go_dex()
		"party":
			go_party()
		"forge":
			go_forge()
		"evolve_quiz":
			evolve_quiz(String(r.get("id", "")), int(r.get("i", 0)), r.get("right", []))
		"quiz":
			encounter(_ids(r.get("words", [])), int(r.get("i", 0)), r.get("right", []))
		"battle":
			var party: Array[int] = []
			for u in r.get("party", []):
				party.append(int(u))
			var roots := {}
			for k in r.get("roots", {}):
				roots[int(k)] = r["roots"][k]
			start_battle(party, roots, _ids(r.get("offer", [])), _ids(r.get("words", [])), bool(r.get("boss", false)),
				int(r.get("seed", -1)), int(r.get("step", 0)), r.get("picks", []))
		"prep":
			go_battle_prep(_ids(r.get("words", [])), bool(r.get("boss", false)))
		"options":
			var back: Dictionary = r.get("back", {"s": "field"})
			go_options(func() -> void: _restore(back))
		"minigame":
			play_minigame(String(r.get("id", "")), String(r.get("mode", "story")))
		_:
			go_field()


func go_title() -> void:
	GameData.set_resume("")
	main.show_screen(TitleScreen.new())


func go_options(back: Callable) -> void:
	GameData.set_route({"s": "options", "back": GameData.resume_route()})
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
	s.pos = WorldMap.load_default().start(1)
	GameData.save()
	GameData.set_resume("dev")
	go_field(TranslationServer.translate("ui.dev.started").format({"count": s.dex_count()}))


# ----- 미니게임 -----

## 미니게임 화면: 말 공방 10개 모두 한 화면(FactoryView)이다.
static func _view(_id: String) -> GDScript:
	return FactoryView


func go_minigames() -> void:
	GameData.set_resume("mini")
	GameData.set_route({"s": "mini_hub"})
	main.show_screen(MinigameHubScreen.new())


## mode "free": 미니게임 메뉴(보상 없음, 그 마을 단어로). "story": 마을에서(아직 못 얻은 마을 단어로, 끝나면 뜻 문제).
func play_minigame(id: String, mode: String) -> void:
	GameData.set_route({"s": "minigame", "id": id, "mode": mode})
	var def := MinigameRegistry.game_def(id)
	if def.is_empty():  # 없어진 옛 미니게임(이어 하기 기록 등)
		go_minigames() if mode == "free" else go_field()
		return
	var pool := _factory_pool(int(def["stage"]), mode == "story")
	var game := MinigameRegistry.make(id, pool, GameData.bal.minigames, GameData.rng)
	main.show_screen(_view(id).new(), {"id": id, "mode": mode, "game": game})


## 말 공방 단어(05-minigames): 그 스테이지 1차 단어(마을 먼저, 필드까지) 중 어원 형태가 있는 것.
## 이야기 모드는 아직 못 얻은 단어를 앞에 둔다(앞에서부터 칠판이 된다). 나머지는 함정 어원 재료.
## [의견] 어원이 둘 이상인 단어를 먼저 쓴다(say = say처럼 어원과 단어가 같으면 배울 것이 적다). 어원 하나뿐인 단어도 모자라면 쓴다(사용자 의견).
func _factory_pool(stage: int, story: bool) -> Array[WordData]:
	var fresh: Array[WordData] = []
	var old: Array[WordData] = []
	for w in GameData.repo.first_tier(stage, "town") + GameData.repo.first_tier(stage, "field"):
		if w.forms().is_empty():
			continue
		if story and GameData.state and GameData.state.has_word(w.id):
			old.append(w)
		else:
			fresh.append(w)
	fresh.shuffle()
	old.shuffle()
	# 어원이 둘 이상인 단어를 먼저(칠판에서 어원 조합이 보이게). 하나뿐인 단어는 모자랄 때 쓴다
	var rich := func(w: WordData) -> bool: return w.forms().size() >= 2
	return fresh.filter(rich) + old.filter(rich) + fresh.filter(func(w: WordData) -> bool: return not rich.call(w)) \
		+ old.filter(func(w: WordData) -> bool: return not rich.call(w))


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
	GameData.set_route({"s": "field"})
	main.show_screen(FieldScreen.new(), {"msg": msg})


func _flag(k: String) -> void:
	GameData.state.flags[k] = true


## 월드맵에서 열린 스테이지 문: 그 스테이지 보스를 이겼고, 다음 스테이지가 만들어져 있을 때(스토리에 맞는 길만).
## 퀘스트 길목(다리·절벽)은 그 퀘스트를 마치면 열린다(04-meta.md 8절).
func open_gates() -> Dictionary:
	var out := GameData.quests.open_gates(GameData.state)
	for st in range(1, 10):
		out[st] = seen("boss_s%02d" % st) and st + 1 <= MAX_STAGE
	return out


# ----- 퀘스트(04-meta.md 8절) -----

## 닫힌 퀘스트 길목에 닿음. 할 수 있으면 장면을 보고 길이 열린다("" 돌려줌, 끝나면 done), 아니면 귀띔 글.
func quest_gate(gate: String, done: Callable) -> String:
	var q := GameData.quests.by_gate(gate)
	if q.is_empty():
		return ""
	if not GameData.quests.visible(GameData.state, q):  # 아직 이야기가 거기까지 오지 않았다
		return TranslationServer.translate("ui.quest.%s.locked" % q["id"])
	var roots := GameData.rules.owned_roots(GameData.state)
	if not GameData.quests.finish(GameData.state, q["id"], roots):
		return TranslationServer.translate("ui.quest.%s.hint" % q["id"])
	GameData.vibrate(true)
	GameData.save()
	main.play_scene(String(q["scene"]), func() -> void:
		done.call()
		main.notice(_done_text(q["id"])))
	return ""


## 마을 알림판: 처음엔 퀘스트를 받고(장면), 단어를 다 모아 오면 마친다.
## 퀘스트를 마친 알림 + 다음 퀘스트로 이어지는 소식(있으면).
func _done_text(id: String) -> String:
	var tx := TranslationServer.translate("ui.quest.done").format({"title": TranslationServer.translate("ui.quest.%s.title" % id)})
	var key := "ui.quest.%s.next" % id
	var nx := TranslationServer.translate(key)
	return tx + ("\n" + nx if nx != key else "")


func notice_board(done: Callable) -> void:
	var s := GameData.state
	var q := GameData.quests.get_quest("s01_q_word")
	if not GameData.quests.visible(s, q):
		main.notice(TranslationServer.translate("ui.quest.board_empty"), done)
		return
	if GameData.quests.done(s, q["id"]):
		main.notice(TranslationServer.translate("ui.quest.board_done"), done)
		return
	if not seen(q["id"] + "_got"):
		_flag(q["id"] + "_got")
		GameData.save()
		main.play_scene(String(q["scene"]), done)
		return
	if GameData.quests.finish(s, q["id"], []):
		GameData.vibrate(true)
		GameData.save()
		main.notice(TranslationServer.translate("ui.quest.board_fill") + "\n" + _done_text(q["id"]), done)
		return
	var pr := GameData.quests.progress(s, q, [])
	main.notice(TranslationServer.translate("ui.quest.s01_q_word.hint").format(pr), done)


func seen(k: String) -> bool:
	return GameData.state.flags.get(k, false)


# ----- 필드에서 일어나는 일 -----

func entered_field() -> void:
	if not seen("s01_tut_battle"):
		_flag("s01_tut_battle")
		main.play_scene("s01_tut_battle", func() -> void: pass)


## 필드 적과 부딪힘: 단어 n개 조우 퀴즈.
func encounter(word_ids: Array[String], resume_i: int = 0, resume_right: Array = []) -> void:
	GameData.set_route({"s": "quiz", "words": word_ids, "i": resume_i, "right": resume_right})
	GameData.vibrate()
	main.show_screen(QuizScreen.new(), {"words": word_ids, "mode": "encounter", "resume_i": resume_i, "resume_right": resume_right,
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
	GameData.set_route({"s": "prep", "words": word_ids, "boss": boss})
	main.show_screen(BattlePrepScreen.new(), {"words": word_ids, "boss": boss})


## 전투 준비가 끝남: 이번 전투의 마법(offer, 턴마다 하나씩)과 어근이 정해졌다.
## seed: 전투 무작위의 씨앗. 이어 하기는 같은 씨앗과 같은 마법 선택(picks: [[id, ok], …] 턴 순)으로 같은 전투를 다시 계산하고
## step 단계까지 건너뛴다.
func start_battle(party: Array[int], roots: Dictionary, offer: Array[String], word_ids: Array[String], boss: bool,
		seed: int = -1, step: int = 0, picks: Array = []) -> void:
	if seed < 0:
		seed = randi()
	GameData.rng.seed = seed
	GameData.set_route({"s": "battle", "party": party, "roots": roots, "offer": offer, "words": word_ids, "boss": boss,
		"seed": seed, "step": step, "picks": picks})
	var s := GameData.state
	for u in roots:
		s.chosen_roots[u] = roots[u]
	var ctx := GameData.setup.make_context(s, party, roots, "")
	ctx.offer = offer
	for m in GameData.bal.magic["magics"]:
		ctx.magic_defs[m["id"]] = m
	var ids := word_ids
	if boss:
		ids = GameData.setup.boss_enemies(ctx, s, STAGE)
	else:
		GameData.setup.field_enemies(ctx, word_ids, STAGE)
	var engine := BattleEngine.new(ctx)
	engine.begin()
	main.show_screen(BattleScreen.new(), {"ctx": ctx, "engine": engine, "words": ids, "boss": boss,
		"party": party, "resume_step": step, "picks": picks, "roots": roots})


func battle_finished(result: BattleResult, word_ids: Array[String], boss: bool, history: Array[Dictionary] = []) -> void:
	GameData.set_route({"s": "field"})  # 전투는 끝났다. 다시 켜도 같은 전투를 또 하지 않는다
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
		_give_words(won, "ui.result.won" if result.won() else "ui.result.partial", history, true)


## joy: 새 어근을 익힌 유닛이 차례로 나와 기뻐한 뒤 결과를 보여 준다(전투 '결과 보기').
func _give_words(ids: Array[String], title_key: String, history: Array[Dictionary] = [], joy := false) -> void:
	var events: Array = []
	for id in ids:
		events.append(GameData.rules.gain_word(GameData.state, id))
		EventBus.word_captured.emit(id)
	GameData.save()
	GameData.set_route({"s": "field"})  # 단어는 이미 받았다. 결과 화면 뒤는 필드
	var show_result := func() -> void:
		main.show_screen(ResultScreen.new(), {"events": events, "title": title_key, "history": history,
			"done": func() -> void: _after_result()})
	if joy:
		_root_joy(root_joy_list(events), show_result)
	else:
		show_result.call()


## 새로 익힌 어근을 유닛(어근 계열)별로 모은다: [[유닛 번호, [어근…]], …] 유닛 번호 순. 함께 다니는 유닛만.
static func root_joy_list(events: Array) -> Array:
	var by := {}
	for ev in events:
		for r in ev.get("roots", []):
			var u := GameData.bal.root_family(String(r))
			if u > 0 and u in GameData.state.joined:
				if not by.has(u):
					by[u] = []
				by[u].append(String(r))
	var units := by.keys()
	units.sort()
	var out: Array = []
	for u in units:
		out.append([u, by[u]])
	return out


func _root_joy(list: Array, done: Callable) -> void:
	if list.is_empty():
		done.call()
		return
	var head: Array = list.pop_front()
	main.show_screen(RootJoyScreen.new(), {"unit": head[0], "roots": head[1],
		"done": func() -> void: _root_joy(list, done)})


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
	GameData.set_route({"s": "forge"})
	if not seen("s01_tut_evolve"):
		_flag("s01_tut_evolve")
		main.play_scene("s01_tut_evolve", func() -> void: main.show_screen(EvolveScreen.new()))
		return
	main.show_screen(EvolveScreen.new())


func evolve_quiz(word_id: String, resume_i: int = 0, resume_right: Array = []) -> void:
	GameData.set_route({"s": "evolve_quiz", "id": word_id, "i": resume_i, "right": resume_right})
	var words := GameData.evolution.quiz_words(word_id)
	main.show_screen(QuizScreen.new(), {"words": words, "mode": "evolve", "target": word_id, "resume_i": resume_i, "resume_right": resume_right,
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
	GameData.set_route({"s": "dex"})
	main.show_screen(DexScreen.new())


func go_party() -> void:
	GameData.set_route({"s": "party"})
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
	var left := GameData.quests.boss_blockers(GameData.state, STAGE)
	if not left.is_empty():
		main.notice(TranslationServer.translate("ui.quest.boss_wait").format(
			{"title": TranslationServer.translate("ui.quest.%s.title" % left[0]["id"])}))
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
