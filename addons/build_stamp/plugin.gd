@tool
extends EditorPlugin
## 내보내기(APK)마다 빌드 시각을 넣는다. 앱은 이 값이 지난번과 다르면 업데이트된 것으로 보고 타이틀부터 시작한다.

var _exp: StampExport


func _enter_tree() -> void:
	_exp = StampExport.new()
	add_export_plugin(_exp)


func _exit_tree() -> void:
	remove_export_plugin(_exp)
	_exp = null


class StampExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "build_stamp"

	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		add_file("res://build_stamp.txt", str(int(Time.get_unix_time_from_system())).to_utf8_buffer(), false)
