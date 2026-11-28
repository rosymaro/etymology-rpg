class_name GameFlow
extends RefCounted
## 게임 흐름(architecture.md 8절): 타이틀 → 이름 → 이야기 → 필드 ↔ 조우·퀴즈 → 전투 준비 → 전투 → 결과.
## 화면은 '무엇이 눌렸다'만 알리고, 다음 화면은 여기서 정한다. 흐름이 바뀌면 이 파일만 고친다.

const MAX_STAGE := 2  ## 만들어 둔(갈 수 있는) 마지막 스테이지. 월드맵 문은 여기까지만 열린다


## 지금 스테이지: 주인공이 있는 구역(GameState.cur_stage, 1~MAX_STAGE). 스테이지 1로 고정해 두던 값을 대신한다
static func cur() -> int:
	var s: GameState = GameData.state if GameData else null
	return clampi(s.cur_stage if s else 1, 1, MAX_STAGE)


## 스테이지 흐름(data/stages.json): 보스 앞뒤 장면, 보상 마법, 알림판 퀘스트, 합류 유닛 …
static var _stages := {}


static func stage_cfg(st: int = 0) -> Dictionary:
	if _stages.is_empty():
		_stages = JsonFile.read("res://data/stages.json")
	return _stages.get(str(st if st > 0 else cur()), {})


## "s01", "s02" …
static func sid(st: int = 0) -> String:
	return "s%02d" % (st if st > 0 else cur())

var main: Main


func _init(m: Main) -> void:
	main = m


## 앱을 켤 때: 하던 곳이 적혀 있으면(다른 앱을 보다 와서 안드로이드가 앱을 다시 켰을 때) 그 화면에서 이어 한다.
## 앱을 제대로 끝냈으면(Main._exit_tree) 지워져 있어 타이틀부터.
func start() -> void:
	var mode := GameData.resume_mode()
	var r := GameData.resume_route()
	match mode:
		"story", "dev", "free":
			GameData.use_save(mode)
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
		"gacha":
			go_gacha()
		"evolve_quiz":
			evolve_quiz(String(r.get("id", "")), int(r.get("i", 0)), r.get("right", []))
		"quiz":
			encounter(_ids(r.get("words", [])), int(r.get("i", 0)), r.get("right", []), r.get("enc", {}))
		"battle":
			var party: Array[int] = []
			for u in r.get("party", []):
				party.append(int(u))
			var roots := {}
			for k in r.get("roots", {}):
				roots[int(k)] = r["roots"][k]
			enc = r.get("enc", {})
			start_battle(party, roots, _ids(r.get("offer", [])), _ids(r.get("words", [])), bool(r.get("boss", false)),
				int(r.get("seed", -1)), int(r.get("step", 0)), r.get("picks", []))
		"prep":
			enc = r.get("enc", {})
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
## free(자유 탐험, 사용자 의견: 테스트 자유도): 그 위에 보스 말고는 단어 전투에 안 들어가고, 지도의 벽·길목에 안 막힌다.
func dev_game(free := false) -> void:
	GameData.use_save("free" if free else "dev")
	GameData.new_game(TranslationServer.translate("ui.dev.name"))
	var s := GameData.state
	s.dev_mode = true
	s.free_roam = free
	var all: Array[String] = []
	for m in GameData.bal.magic["magics"]:
		all.append(str(m["id"]))
	GameData.rules.grant_all(s, all)
	for k in ["s01_ki", "s01_tut_battle", "s01_skit_cheok", "s01_tut_evolve"]:
		_flag(k)
	s.pos = WorldMap.load_default().start(1)
	GameData.save()
	GameData.set_resume("free" if free else "dev")
	go_field(TranslationServer.translate("ui.dev.free_started" if free else "ui.dev.started").format({"count": s.dex_count()}))


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

func name_entered(hero_name: String, look: String = "m") -> void:
	GameData.new_game(hero_name, look)
	GameData.set_resume("story")
	# 사용자 의견: 이름·성별을 고르면 장면이 바뀌어(말뿌리 나무 → 대장간) 대화가 시작된다
	main.play_scene("s01_intro", func() -> void:
		main.play_scene("s01_ki", func() -> void:
			_flag("s01_ki")
			GameData.save()
			go_field(), true), true)


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
		return TranslationServer.translate("ui.quest.%s.hint" % q["id"]).format({"dir": dir_word(item_cave_mouth(String(q.get("item", ""))))})
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
	var q := GameData.quests.get_quest(String(stage_cfg().get("board", "s01_q_word")))
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
	main.notice(TranslationServer.translate("ui.quest.%s.hint" % q["id"]).format(pr), done)


## 보스 앞에서 단어가 모자라다는 말을 들었다(이 스테이지): 몹 단어가 처음 보는 단어 쪽으로 기운다.
static func boss_short_flag() -> String:
	return "boss_short_s%02d" % cur()


func seen(k: String) -> bool:
	return GameData.state.flags.get(k, false)


# ----- 필드에서 일어나는 일 -----

func entered_field() -> void:
	if not seen("s01_tut_battle"):
		_flag("s01_tut_battle")
		main.play_scene("s01_tut_battle", func() -> void: pass)


## 지금 조우의 덧붙임(07-fun 1절): hurt = 필드 사냥으로 깎인 비율(전투에서 적 체력이 그만큼 줄어 나온다),
## hard = 뿌리먹이(유추 문제 단계를 올리고, 다 맞히면 주머니에 큰 보상). 이어 하기를 위해 길(route)에도 적는다.
var enc: Dictionary = {}


## 필드 적과 부딪힘: 단어 n개 조우 퀴즈.
func encounter(word_ids: Array[String], resume_i: int = 0, resume_right: Array = [], opts: Dictionary = {}) -> void:
	enc = opts
	GameData.set_route({"s": "quiz", "words": word_ids, "i": resume_i, "right": resume_right, "enc": enc})
	GameData.vibrate()
	main.show_screen(QuizScreen.new(), {"words": word_ids, "mode": "encounter", "resume_i": resume_i, "resume_right": resume_right,
		"step_bonus": int(GameData.hunt_cfg["eater"]["hard_step"]) if enc.get("hard", false) else 0,
		"done": func(right: Array[bool]) -> void: _after_encounter(word_ids, right)})


## 필드에서 몹에 닿았을 때: 화면을 바꾸지 않고 필드 위 아래쪽 반 화면 창으로 퀴즈를 낸다(사용자 의견: 몹 자리를 그대로).
## 다 맞히면 창만 닫고 짧은 알림으로 얻은 것을 보여 준 뒤 caught()를 부른다(필드는 그대로 이어진다).
## 틀린 단어가 있으면 지금처럼 전투로 간다(화면이 바뀐다).
const POPUP_TOP := 0.4  ## 창이 시작하는 높이(화면 위에서 비율)


func encounter_popup(word_ids: Array[String], opts: Dictionary, caught: Callable) -> void:
	enc = opts
	GameData.set_route({"s": "quiz", "words": word_ids, "i": 0, "right": [], "enc": enc})
	GameData.vibrate()
	var q := QuizScreen.new()
	q.main = main
	q.anchor_top = POPUP_TOP
	q.anchor_bottom = 1.0
	q.anchor_right = 1.0
	main._overlay.add_child(q)
	q.offset_top = 0
	q.offset_bottom = 0
	q.offset_left = 0
	q.offset_right = 0
	q.open({"words": word_ids, "mode": "encounter", "popup": true,
		"step_bonus": int(GameData.hunt_cfg["eater"]["hard_step"]) if enc.get("hard", false) else 0,
		"done": func(right: Array[bool]) -> void:
			q.queue_free()
			if right.has(false):
				_after_encounter(word_ids, right)
				return
			if enc.get("hard", false):
				GameData.hunt_run().pick_orbs(int(GameData.hunt_cfg["eater"]["bonus_orbs"]))
			enc = {}
			var lines: Array[String] = [TranslationServer.translate("ui.result.caught_all")]
			for id in word_ids:
				var ev := GameData.rules.gain_word(GameData.state, id)
				EventBus.word_captured.emit(id)
				lines.append(_event_line(ev))
			GameData.save()
			GameData.set_route({"s": "field"})
			caught.call()
			main.notice("\n".join(lines), _maybe_cheok)})


## 얻은 단어 한 줄: 단어 = 뜻 (새 단어 / 이미 가진 단어, 장착, 레벨 업, 새 어근)
func _event_line(ev: Dictionary) -> String:
	var w := GameData.repo.get_word(ev["word"])
	var tr := func(k: String) -> String: return TranslationServer.translate(k)
	var line := "%s = %s  %s" % [w.id, w.meaning, tr.call("ui.result.new") if ev["new"] else tr.call("ui.result.dup")]
	if int(ev["equipped"]) > 0:
		line += "  " + tr.call("ui.result.equipped").format({"name": UiKit.unit_name(ev["equipped"])})
	for u in ev["level_ups"]:
		EventBus.level_up.emit(u[0], u[2])
		if u[0] in GameData.state.joined:
			line += "\n  " + tr.call("ui.result.level_up").format({"name": UiKit.unit_name(u[0]), "level": u[2]})
	for r in ev["roots"]:
		line += "\n  " + tr.call("ui.result.new_root").format({"root": r})
	return line


func _after_encounter(word_ids: Array[String], right: Array[bool]) -> void:
	if not right.has(false):
		if enc.get("hard", false):  # 뿌리먹이를 다 맞혔다: 주머니에 큰 보상
			GameData.hunt_run().pick_orbs(int(GameData.hunt_cfg["eater"]["bonus_orbs"]))
		enc = {}
		_give_words(word_ids, "ui.result.caught_all")
	else:  # 맞힌 단어는 싸우지 않고 잡는다. 틀린 단어만 전투로(사용자 의견: 맞힐 까닭이 있게)
		var caught: Array[String] = []
		var fight: Array[String] = []
		for i in word_ids.size():
			if i < right.size() and right[i]:
				caught.append(word_ids[i])
			else:
				fight.append(word_ids[i])
		for id in caught:
			GameData.rules.gain_word(GameData.state, id)
			EventBus.word_captured.emit(id)
		# 사용자 의견: 틀려서 전투로 들어가면 사냥 레벨과 구슬을 빼앗긴다(코인·단어는 그대로)
		var had := GameData.hunt_run().level() > 0 or int(GameData.hunt_run().bag()["orbs"]) > 0
		GameData.hunt_run().lose_orbs()
		GameData.save()
		go_battle_prep(fight, false)
		var lines: Array[String] = []
		if had:
			lines.append(TranslationServer.translate("ui.hunt.orbs_stolen"))
		if not caught.is_empty():
			lines.append(TranslationServer.translate("ui.quiz.caught_some").format({"words": ", ".join(caught), "n": fight.size()}))
		if not lines.is_empty():
			main.notice("\n\n".join(lines))


## 마을 미니게임(스테이지 1: 주문 제작). 마을 단어는 이것으로만 얻는다(01-rpg-base '마을과 특수 행위').
func town_minigame() -> void:
	var j: Dictionary = stage_cfg().get("join", {})
	if cur() > 1 and not j.is_empty() and not seen(String(j["flag"])):  # 스테이지 2: 덥석이 합류하면(s02_seung) 사냥꾼이 발자국 글자를 알려 준다
		main.notice(TranslationServer.translate("ui.field.board_locked_" + sid()).format({"n": int(j["after"])}))
		return
	play_minigame(MinigameRegistry.for_stage(cur())["id"], "story")


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
	GameData.set_route({"s": "prep", "words": word_ids, "boss": boss, "enc": enc})
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
		"seed": seed, "step": step, "picks": picks, "enc": enc})
	var s := GameData.state
	for u in roots:
		s.chosen_roots[u] = roots[u]
	var ctx := GameData.setup.make_context(s, party, roots, "")
	ctx.offer = offer
	for m in GameData.bal.magic["magics"]:
		ctx.magic_defs[m["id"]] = m
	var ids := word_ids
	if boss:
		ids = GameData.setup.boss_enemies(ctx, s, cur())
	else:
		GameData.setup.field_enemies(ctx, word_ids, cur())
		var hurt := float(enc.get("hurt", 0.0))
		if hurt > 0.0:  # 필드 사냥으로 깎아 둔 몹: 적 체력이 그만큼 줄어 나온다
			for e in ctx.enemies:
				e.pre_damage += int(floor(e.base.hp * hurt))
	var engine := BattleEngine.new(ctx)
	engine.begin()
	main.show_screen(BattleScreen.new(), {"ctx": ctx, "engine": engine, "words": ids, "boss": boss,
		"party": party, "resume_step": step, "picks": picks, "roots": roots})


func battle_finished(result: BattleResult, word_ids: Array[String], boss: bool, history: Array[Dictionary] = []) -> void:
	GameData.set_route({"s": "field"})  # 전투는 끝났다. 다시 켜도 같은 전투를 또 하지 않는다
	var won := RewardRule.words_won(result, word_ids, GameData.coin_source)
	if not result.won():  # 졌다: 받을 단어는 받고, 결과를 본 뒤 병원에서 깨어난다(04-meta 9절)
		_to_hospital()
	if boss:
		if result.won():
			_boss_won()
			return
		GameData.save()
		_after_result()
		return
	if won.is_empty():
		GameData.save()
		if _lost:
			_after_result()
			return
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


var _lost := false  ## 방금 전투에서 졌다: 결과 뒤 병원에서 깨어난다


## 진 자리: 병원 문 앞으로 옮기고, 쉬기를 시작한다(진짜 시계).
func _to_hospital() -> void:
	_lost = true
	enc = {}
	GameData.hunt_run().lose()  # 주머니의 코인·단어를 모두 잃는다(사용자 의견)
	var s := GameData.state
	s.pos = WorldMap.load_default().spot(cur(), "hospital")
	s.place = "town"
	s.cave = ""
	GameData.rules.start_rest(s, int(Time.get_unix_time_from_system()), int(GameData.field["rest_sec"]))
	GameData.save()


func rest_left() -> int:
	return GameData.rules.rest_left(GameData.state, int(Time.get_unix_time_from_system()))


func _after_result() -> void:
	var lost := _lost
	_lost = false
	go_field()
	var hs := String(stage_cfg().get("hospital", ""))
	if lost and hs != "":
		main.play_scene(hs, _maybe_cheok)
	elif lost:
		main.notice(TranslationServer.translate("ui.field.nurse"), _maybe_cheok)
	else:
		_maybe_cheok()


## 그 스테이지 단어를 몇 개 잡으면 유닛이 합류한다(data/stages.json join).
## 스테이지 1: 단어 5개 → 척척(s01_skit_cheok, 끝에 알림판 퀘스트가 열린다). 스테이지 2: 단어 3개 → 덥석(s02_seung, 발자국 글자 미니게임)
func _maybe_cheok() -> void:
	var s := GameData.state
	var j: Dictionary = stage_cfg().get("join", {})
	if j.is_empty() or seen(String(j["flag"])):
		return
	var have := s.dex_count() if cur() == 1 else GameData.repo.first_tier(cur()).filter(func(w: WordData) -> bool: return s.has_word(w.id)).size()
	if have < int(j["after"]):
		return
	_flag(String(j["flag"]))
	var u := int(j["unit"])
	if not u in s.joined:
		s.joined.append(u)
	GameData.save()
	var after := String(stage_cfg().get("after_join", ""))
	main.play_scene(String(j["scene"]), func() -> void:
		main.notice(TranslationServer.translate("ui.join").format({"name": UiKit.unit_name(u)}), func() -> void:
			if after != "" and not seen(after):
				_flag(after)
				GameData.save()
				main.play_scene(after, func() -> void: pass)))


## 처음 그 구역에 들어섰을 때(필드가 부른다): 그 스테이지의 첫 장면(data/stages.json intro). 봤으면 false.
func enter_stage(st: int, done: Callable) -> bool:
	var sc := String(stage_cfg(st).get("intro", ""))
	if sc == "" or seen(sc):
		return false
	_flag(sc)
	GameData.save()
	main.play_scene(sc, done)
	return true


## 그 스테이지 마을에 처음 들어섰을 때 장면(마을 이야기). 봤으면 false.
func enter_town(done: Callable) -> bool:
	var sc := String(stage_cfg().get("town", ""))
	if sc == "" or seen(sc):
		return false
	_flag(sc)
	GameData.save()
	main.play_scene(sc, done)
	return true


## 물건 퀘스트의 물건이 든 동굴 입구(큰 지도 px). 없으면 Vector2.INF.
static func item_cave_mouth(item: String) -> Vector2:
	var wm := WorldMap.load_default()
	for c in wm.caves:
		var cm: Dictionary = wm.cave_maps.get(c["id"], {})
		for it in cm.get("items", []):
			if String(it["id"]) == item and not (c["mouths"] as Array).is_empty():
				var m: Array = c["mouths"][0]
				return (Vector2(float(m[0]), float(m[1])) + Vector2(0.5, 0.5)) * wm.tile
	return Vector2.INF


## 마을에서 본 방향 낱말(동쪽, 북서쪽 …). 지도가 바뀌어도 귀띔이 맞게(사용자 의견: 어느 동굴인지 모르겠다)
static func dir_word(p: Vector2) -> String:
	if p == Vector2.INF:
		return ""
	var d := p - WorldMap.load_default().start(cur())
	var a := wrapf(rad_to_deg(atan2(-d.y, d.x)), 0.0, 360.0)
	var keys := ["e", "ne", "n", "nw", "w", "sw", "s", "se"]
	return TranslationServer.translate("ui.dir." + keys[int(round(a / 45.0)) % 8])


## 마을 아이(퀘스트 동굴, 07-fun 5절): 처음엔 부탁, 장난감 망치를 찾아 오면 마친다.
func kid_talk(done: Callable) -> void:
	var st := GameData.state
	var q := GameData.quests.get_quest("s01_q_hammer")
	var tr := func(k: String) -> String: return TranslationServer.translate(k)
	if q.is_empty() or not GameData.quests.visible(st, q):
		main.notice(tr.call("ui.npc.s01_4"), done)
		return
	if GameData.quests.done(st, q["id"]):
		main.notice(tr.call("ui.kid.done"), done)
		return
	if not seen(q["id"] + "_got"):
		_flag(q["id"] + "_got")
		GameData.save()
		main.notice(tr.call("ui.kid.ask").format({"dir": dir_word(item_cave_mouth("toy_hammer"))}), done)
		return
	if GameData.quests.finish(st, q["id"], []):
		give_treasure(String(q.get("reward", "")))
		main.notice(tr.call("ui.kid.thanks") + "\n" + _done_text(q["id"]), done)
		return
	main.notice(tr.call("ui.kid.wait").format({"dir": dir_word(item_cave_mouth("toy_hammer"))}), done)


## 성 집사(성 퀘스트 s01_q_castle, 사용자 의견: 성의 이야기와 퀘스트): 처음엔 '유니콘 근위대' 장면,
## 성 안 서고의 모양 도장을 가져오면 '같은 모양 옷' 장면 뒤 마친다.
func steward_talk(done: Callable) -> void:
	var st := GameData.state
	var q := GameData.quests.get_quest("s01_q_castle")
	var tr := func(k: String) -> String: return TranslationServer.translate(k)
	if q.is_empty() or not GameData.quests.visible(st, q):
		main.notice(tr.call("ui.steward.hello"), done)
		return
	if GameData.quests.done(st, q["id"]):
		main.notice(tr.call("ui.steward.done"), done)
		return
	if not seen(q["id"] + "_got"):
		_flag(q["id"] + "_got")
		GameData.save()
		main.play_scene("s01_castle", done)
		return
	if GameData.quests.finish(st, q["id"], []):
		give_treasure(String(q.get("reward", "")))
		GameData.save()
		main.play_scene(String(q.get("scene", "s01_castle_done")), func() -> void:
			main.notice(_done_text(q["id"]), done))
		return
	main.notice(tr.call("ui.steward.wait"), done)


# ----- 보물(07-fun 6절) -----

## 보물 상자 내용("coin:80" | "word:id" | "exp:300")을 준다. 돌려주는 값: 알림 글.
func give_treasure(reward: String) -> String:
	var s := GameData.state
	var kv := reward.split(":")
	var v := kv[1] if kv.size() > 1 else ""
	var text := ""
	match kv[0]:
		"coin":
			s.wallet += int(v)
			text = TranslationServer.translate("ui.treasure.coin").format({"n": v})
		"word":
			GameData.rules.gain_word(s, v)
			text = TranslationServer.translate("ui.treasure.word").format({"word": v, "meaning": GameData.repo.get_word(v).meaning})
		"exp":
			for u in s.joined:
				s.unit_exp[u - 1] += int(v)
			text = TranslationServer.translate("ui.treasure.exp").format({"n": v})
	GameData.save()
	GameData.vibrate(true)
	return text


# ----- 마을 -----

## 말 뽑기(07-fun 7절, 마을 광장).
func go_gacha() -> void:
	GameData.set_route({"s": "gacha"})
	main.show_screen(GachaScreen.new())


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
	var g := GameData.rules.boss_gate(GameData.state, cur())
	if seen("boss_" + sid()):
		main.notice(TranslationServer.translate("ui.boss.already").format({"boss": GameData.repo.boss_word(cur()).id}))
		return
	if not g["open"]:
		_flag(boss_short_flag())  # 사용자 의견: 이때부터 이 스테이지에서 처음 보는 단어가 더 자주 나온다
		GameData.save()
		main.notice(TranslationServer.translate("ui.boss.gate").format(g) + "\n" + TranslationServer.translate("ui.boss.fresh_up"))
		return
	var left := GameData.quests.boss_blockers(GameData.state, cur())
	if not left.is_empty():
		main.notice(TranslationServer.translate("ui.quest.boss_wait").format(
			{"title": TranslationServer.translate("ui.quest.%s.title" % left[0]["id"])}))
		return
	GameData.vibrate(true)
	main.play_scene(String(stage_cfg().get("boss_before", "s01_jeon")), func() -> void: go_battle_prep([] as Array[String], true))


func _boss_won() -> void:
	var s := GameData.state
	var st := cur()
	_flag("boss_" + sid(st))
	var bw := GameData.repo.boss_word(st)
	GameData.rules.gain_word(s, bw.id)
	for m in stage_cfg(st).get("rewards", []):
		if not m in s.magics:
			s.magics.append(m)
	s.stage = maxi(s.stage, st + 1)
	GameData.save()
	EventBus.boss_defeated.emit(st)
	GameData.vibrate(true)
	var mags: Array[String] = []
	for m in stage_cfg(st).get("rewards", []):
		mags.append(String(m) + "-")
	var key := "ui.stage.clear" if st >= MAX_STAGE else "ui.stage.clear_next"
	main.play_scene(String(stage_cfg(st).get("boss_after", "s01_gyeol")), func() -> void:
		go_field()
		main.notice(TranslationServer.translate(key).format({"n": st, "next": st + 1, "magics": "·".join(mags)})))
