# 밸런스 시뮬레이터

전투 승률을 스테이지별로 뽑는다. 결과와 가정은 [docs/design/sim-10stage.md](../../docs/design/sim-10stage.md).

| 파일 | 하는 일 |
|---|---|
| `engine.py`, `full.py`, `skills.py` | 12지역 때 만든 전투 엔진(4 대 4 서바이벌, 코인, 스킬 65개, 마법 14개, 보스 능력). 능력치 공식은 `data/balance/unit.json`에서 읽는다 |
| `progress.py` | `data/words_v2_plan.csv`로 스테이지별 레벨·장비를 추정. `python3 progress.py`로 표를 찍는다 |
| `sim10.py` | progress + `data/balance/*.json`으로 10스테이지 승률을 계산 |
| `final.py` | 마지막 전투(devil)를 레벨·장비 차수별로 확인. `--search`로 `boss.json` `final` 후보를 찾는다 |

```
python3 tools/balance/sim10.py                 # 지금 JSON 값으로 승률 표
python3 tools/balance/sim10.py --max-tier 3    # 3차까지만 진화하는 플레이어(--lazy = 진화 안 함)
python3 tools/balance/sim10.py --gear-model light # 낮춘 장비 값과 비교
python3 tools/balance/final.py                 # 마지막 전투: 60·4차, 60·3차, 55·3차 …
python3 tools/balance/sim10.py --tune          # 목표(필드 75%, 보스 65%)에 맞는 기준 레벨·보스 레벨 차 찾기(3분쯤)
python3 tools/balance/sim10.py --stages 3-5 --trials 500
```

- `--tune`은 값을 찾아 표로만 보여 준다. JSON에 적는 것은 사람이 한다(`docs/design/tuning-log.md`에 이유와 함께).
- 게임 코드(Godot)의 규칙을 그대로 쓰는 시뮬레이터가 생겼다(아래). 위 파이썬 엔진은 1차 기준으로 남긴다.

## Godot 시뮬레이터(게임 규칙 그대로)

```
godot --headless -s tools/balance/hunt_sim.gd -- 240 6          # 필드 사냥: 동행 조합마다 막은 몹·뚫린 몹(목표 뚫림 20%)
godot --headless -s tools/balance/hunt_sim.gd -- 180 4 single   # 유닛 하나씩(무기 세기 비교), solo = 뚝딱 혼자
godot --headless -s tools/balance/battle_sim.gd -- 300 2-10     # 전투 승률: 마법 없음 / 아무거나 / 생각(때를 골라 씀), 필드·보스
godot --headless -s tools/balance/battle_sim.gd -- 150 3-9 each # 마법 하나씩만 쓸 때 승률이 얼마나 오르나
godot --headless -s tools/balance/battle_sim.gd -- 150 2-10 tune # 목표(필드 75%, 보스 65%)에 맞는 적 기준 레벨·보스 level_delta 찾기(10분쯤)
```

결과와 가정은 [sim-10stage.md](../../docs/design/sim-10stage.md) 7절.
