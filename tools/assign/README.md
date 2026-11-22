# 단어 배정 스크립트

`data/words_v2_plan.csv`를 다시 만든다. 단어장 저장소의 `default_words.json`(domains 포함 버전)이 필요하다.

```
python3 build_trees.py path/to/default_words.json trees.json      # 진화 트리 666개, 유닛·부위 배정 (몇 분 걸림)
python3 assign_stages.py path/to/default_words.json trees.json .  # 스테이지·필드/마을 배정, words_v2_plan.csv
```

같은 입력이면 같은 결과가 나온다(난수 시드 고정).
