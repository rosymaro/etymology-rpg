class_name InferenceQuestion
extends QuizQuestion
## 유추 문제 하나(값 객체). parts = PieceSplit 결과에 learned(배운 조각인가), shown(뜻을 보여 주는가)을 더한 것.

var kind := "meaning"  ## infer | meaning
var step := "A"
var show_split := false  ## 단어를 조각으로 나눠 보여 주는가
var parts: Array[Dictionary] = []
var learned: Array[String] = []  ## 이 단어 속 배운 조각 id


## 풀이 글: "in(안에) + form(모양) + ation → 알림"
func explain(meaning: String) -> String:
	var bits: Array[String] = []
	for p in parts:
		if String(p["piece"]) != "":
			bits.append("%s(%s)" % [p["text"], p["meaning"]])
		else:
			bits.append(String(p["text"]))
	return " + ".join(bits) + " → " + meaning
