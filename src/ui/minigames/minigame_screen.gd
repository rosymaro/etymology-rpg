class_name MinigameScreen
extends Screen
## 미니게임 화면의 바탕: 위쪽 띠(이름, 남은 시간, 얻은 수), 규칙 객체 돌리기, 끝난 뒤 처리.
## mode "free"(미니게임 메뉴, 보상 없음) | "story"(마을, 끝나면 얻은 단어마다 뜻 문제).

const ATTR_COLORS := ["f4a6a6", "c9b6e4", "a8d8ea", "ffd59e", "b5e5b5", "f7c59f", "d6d6b0", "f2b5d4", "aec6f0",
	"e8c8a0", "c4e8f2", "f0b8b8", "d8c4f0", "e0a0a0", "f5e3a3", "b8e0d2", "fff1a8", "cfd8a8", "c8b8a8", "b0c8e8"]

var game: Minigame
var game_id := ""
var mode := "free"
var body: Control
var _head: Label
var _sub: Label
var _ended := false


func open(args: Dictionary) -> void:
	game_id = args["id"]
	mode = args.get("mode", "free")
	game = args["game"]
	UiKit.fill_bg(self, UiKit.PAPER)
	var top := UiKit.hbox(12)
	top.position = Vector2(16, 10)
	add_child(top)
	_head = UiKit.label("", 22)
	top.add_child(_head)
	var quit := UiKit.button(t("ui.mini.quit"), _quit, UiKit.PINK, 20)
	quit.custom_minimum_size = Vector2(110, 48)
	add_child(quit)
	UiKit.pin(quit, 1, 0, -16, 10)
	_sub = UiKit.wrap(UiKit.label(t("ui.mini.rule." + game_id), 20, UiKit.INK.lightened(0.25)))
	_sub.position = Vector2(16, 62)
	_sub.custom_minimum_size = Vector2(688, 0)  # 세로 화면 폭(720 - 양옆 16)
	add_child(_sub)
	body = Control.new()
	body.anchor_right = 1.0
	body.anchor_bottom = 1.0
	body.offset_top = 150
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(body)
	build()
	refresh()


## 게임마다 화면을 만든다.
func build() -> void:
	pass


## 규칙 상태가 바뀌면 다시 그린다.
func refresh() -> void:
	pass


func _process(delta: float) -> void:
	if _ended:
		return
	game.update(delta)
	var time := "" if not game.cfg.has("duration") else "  ·  " + t("ui.mini.time").format({"s": int(ceil(game.time_left))})
	_head.text = "%s%s  ·  %s" % [t("name.minigame." + game_id), time,
		t("ui.mini.score").format({"n": game.score(), "max": game.max_words})]
	tick(delta)
	if game.finished:
		_end()


func tick(_delta: float) -> void:
	pass


func changed() -> void:
	refresh()
	if game.finished:
		_end()


func _quit() -> void:
	game.finish()
	_end()


func _end() -> void:
	if _ended:
		return
	_ended = true
	GameData.vibrate(game.score() > 0)
	if show_review():
		var next := UiKit.button(t("ui.mini.next"), _proceed, UiKit.LEAF, 26)
		next.custom_minimum_size = Vector2(220, 72)
		add_child(next)
		UiKit.thumb(next, 1.0)  # 엄지 자리
		return
	await get_tree().create_timer(0.6).timeout
	_proceed()


## 끝난 판을 그대로 두고 답을 보여 줄지(학습용). true면 '다음'을 눌러야 넘어간다.
func show_review() -> bool:
	return false


func _proceed() -> void:
	if mode == "story":
		main.flow.minigame_finished(game_id, game.earned)
	else:
		main.show_screen(MinigameResultScreen.new(), {"id": game_id, "earned": game.earned})


static func attr_color(attr: int) -> Color:
	return Color(ATTR_COLORS[(attr - 1) % ATTR_COLORS.size()]) if attr > 0 else UiKit.GRAY


func word(id: String) -> WordData:
	return GameData.repo.get_word(id)
