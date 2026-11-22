class_name Formula
extends RefCounted
## 밸런스 데이터의 식("2*P", "min(5, L // 10 + 1)", "(v + 1) // 2")을 계산한다.
## Python 시뮬레이터(tools/balance)의 eval과 같은 문법만 쓴다: 숫자, 변수, + - * / // %, 괄호, min max ceil floor abs.

var _toks: Array = []
var _i: int = 0
var _vars: Dictionary = {}


static func value(src: Variant, vars: Dictionary = {}) -> float:
	if src is int or src is float:
		return float(src)
	var f := Formula.new()
	return f._run(str(src), vars)


## 정수로 돌려준다. 식은 정수 결과를 내도록 쓰지만, 실수가 나오면 버린다(Python int()와 같다).
static func int_value(src: Variant, vars: Dictionary = {}) -> int:
	var v := value(src, vars)
	return int(v + 1e-9) if v >= 0.0 else -int(-v + 1e-9)


func _run(src: String, vars: Dictionary) -> float:
	_vars = vars
	_toks = _tokenize(src)
	_i = 0
	var v := _expr()
	if _i != _toks.size():
		push_error("식을 끝까지 읽지 못함: %s" % src)
	return v


func _tokenize(s: String) -> Array:
	var out: Array = []
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == " ":
			i += 1
		elif c.is_valid_int() or c == ".":
			var j := i
			while j < s.length() and (s[j].is_valid_int() or s[j] == "."):
				j += 1
			out.append(float(s.substr(i, j - i)))
			i = j
		elif c.is_valid_identifier() or c == "_":
			var j := i
			while j < s.length() and (s[j].is_valid_identifier() or s[j] == "_" or s[j].is_valid_int()):
				j += 1
			out.append(s.substr(i, j - i))
			i = j
		elif c == "/" and i + 1 < s.length() and s[i + 1] == "/":
			out.append("//")
			i += 2
		else:
			out.append(c)
			i += 1
	return out


func _peek() -> Variant:
	return _toks[_i] if _i < _toks.size() else null


func _next() -> Variant:
	_i += 1
	return _toks[_i - 1]


func _expr() -> float:
	var v := _term()
	while _peek() is String and (_peek() == "+" or _peek() == "-"):
		var op: String = _next()
		var r := _term()
		v = v + r if op == "+" else v - r
	return v


func _term() -> float:
	var v := _unary()
	while _peek() is String and _peek() in ["*", "/", "//", "%"]:
		var op: String = _next()
		var r := _unary()
		match op:
			"*":
				v *= r
			"/":
				v /= r
			"//":
				v = floor(v / r)
			"%":
				v = fposmod(v, r)
	return v


func _unary() -> float:
	if _peek() is String and _peek() == "-":
		_next()
		return -_unary()
	return _primary()


func _primary() -> float:
	var t: Variant = _next()
	if t is float:
		return t
	if t == "(":
		var v := _expr()
		_next()  # ")"
		return v
	if _peek() is String and _peek() == "(":
		_next()
		var args: Array[float] = []
		while not (_peek() is String and _peek() == ")"):
			args.append(_expr())
			if _peek() is String and _peek() == ",":
				_next()
		_next()
		return _call(t, args)
	if not _vars.has(t):
		push_error("식의 변수가 없음: %s" % t)
		return 0.0
	return float(_vars[t])


func _call(name: String, a: Array[float]) -> float:
	match name:
		"min":
			return a.min()
		"max":
			return a.max()
		"ceil":
			return ceil(a[0])
		"floor":
			return floor(a[0])
		"abs":
			return abs(a[0])
	push_error("모르는 함수: %s" % name)
	return 0.0
