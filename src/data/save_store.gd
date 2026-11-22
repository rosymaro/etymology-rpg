class_name SaveStore
extends RefCounted
## 게임 저장(user://save.json). 전투가 끝날 때 자동 저장한다(01-rpg-base '보상').
## 버전이 바뀌면 _migrate에 변환을 더한다.

var path := "user://save.json"


func _init(file_path: String = "user://save.json") -> void:
	path = file_path


func exists() -> bool:
	return FileAccess.file_exists(path)


func save(state: GameState) -> bool:
	return JsonFile.write(path, state.to_dict())


func load_state() -> GameState:
	var d: Variant = JsonFile.read(path)
	if d == null or not d is Dictionary:
		return null
	return GameState.from_dict(_migrate(d))


func erase() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _migrate(d: Dictionary) -> Dictionary:
	# 버전 1이 처음이다. 형식이 바뀌면 여기서 옛 저장을 새 형식으로 바꾼다.
	return d
