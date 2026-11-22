class_name QuizQuestion
extends RefCounted
## 4지선다 문제 하나(값 객체).

var word_id: String
var options: Array[String] = []  ## 뜻 보기
var answer: int  ## 정답 보기 번호


func is_correct(choice: int) -> bool:
	return choice == answer
