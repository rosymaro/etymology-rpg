class_name JsonFile
extends RefCounted
## res:// 또는 user:// 의 JSON 파일을 읽고 쓴다.


static func read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("파일을 열 수 없음: %s" % path)
		return null
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data == null:
		push_error("JSON을 읽을 수 없음: %s" % path)
	return data


static func write(path: String, data: Variant) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("파일에 쓸 수 없음: %s" % path)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true
