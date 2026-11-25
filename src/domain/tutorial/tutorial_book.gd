class_name TutorialBook
extends RefCounted
## 처음 하는 것마다 튜토리얼(08-tutorial.md). 어떤 튜토리얼을 보였는지만 안다(노드·화면을 모른다).
## 본(또는 건너뛴) 튜토리얼은 state.flags["tut_<id>"] = true. 옵션의 '튜토리얼 다시 보기'는 모두 지운다.


static func seen(state: GameState, id: String) -> bool:
	return bool(state.flags.get("tut_" + id, false))


static func mark(state: GameState, id: String) -> void:
	state.flags["tut_" + id] = true


## 보여야 하는가: 켜져 있고(테스트·캡처에서는 끈다), 아직 안 봤고, 개발자 모드가 아닐 때.
static func should(state: GameState, id: String, enabled: bool) -> bool:
	return enabled and not state.dev_mode and not seen(state, id)


static func reset_all(state: GameState) -> void:
	for k in state.flags.keys():
		if String(k).begins_with("tut_"):
			state.flags.erase(k)
