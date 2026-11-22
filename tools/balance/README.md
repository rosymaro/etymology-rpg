# 밸런스 시뮬레이터

전투 승률을 스테이지별로 뽑는다. 결과와 가정은 [docs/design/sim-10stage.md](../../docs/design/sim-10stage.md).

| 파일 | 하는 일 |
|---|---|
| `engine.py`, `full.py`, `skills.py` | 12지역 때 만든 전투 엔진(4 대 4 서바이벌, 코인, 스킬 65개, 마법 14개, 보스 능력) |
| `progress.py` | `data/words_v2_plan.csv`로 스테이지별 레벨·장비를 추정. `python3 progress.py`로 표를 찍는다 |
| `sim10.py` | progress + `data/balance/*.json`으로 10스테이지 승률을 계산 |

```
python3 tools/balance/sim10.py                 # 지금 JSON 값으로 승률 표
python3 tools/balance/sim10.py --lazy          # 진화를 안 하는 플레이어
python3 tools/balance/sim10.py --gear-model v2 # 장비 첫 가정과 비교
python3 tools/balance/sim10.py --tune          # 목표(필드 75%, 보스 65%)에 맞는 기준 레벨·보스 레벨 차 찾기(3분쯤)
python3 tools/balance/sim10.py --stages 3-5 --trials 500
```

- `--tune`은 값을 찾아 표로만 보여 준다. JSON에 적는 것은 사람이 한다(`docs/design/tuning-log.md`에 이유와 함께).
- 게임 코드(Godot)의 규칙 층이 생기면, 이 엔진 대신 그 규칙을 그대로 쓰는 시뮬레이터로 바꾼다. 그때까지 이 엔진은 수치의 대략적인 기준이다.
