# etymology-rpg

A collecting game inspired vocabulary RPG that makes learning English words, meanings, and etymologies fun through exploration, collection, and battles.

어원 영어 단어장([etymology-english-vocabulary](https://github.com/rosymaro/etymology-english-vocabulary))의 단어 데이터로 만드는 수집형 RPG다. 단어를 잡고, 두 단어를 합쳐 진화시키고, 유닛의 장비로 입혀 싸운다. Godot로 만든다.

## 문서

| 문서 | 내용 |
|---|---|
| [docs/design/01-rpg-base.md](docs/design/01-rpg-base.md) | 기본 설계: 전투, 코인, 마법 14개, 유닛 12종, 어근 65개, 스테이지, 마을, 수치 1차 |
| [docs/design/02-rpg-v2.md](docs/design/02-rpg-v2.md) | 2차 설계: 속성 20개, 1~4차 진화, 장비 5칸, 스테이지 10개 |
| [docs/story/00-overview.md](docs/story/00-overview.md) | 이야기 개요, [장면 청사진](docs/story/blueprint.md), [대본](docs/story/script-ko.md), [스토리보드(전투 콘티 포함)](docs/story/storyboard/) |
| [docs/i18n.md](docs/i18n.md) | 다국어 텍스트 관리 규칙 |
| [docs/dev/architecture.md](docs/dev/architecture.md) | 코드 구조와 객체지향 규칙(바뀌는 규칙을 경계 뒤에 두기) |
| [docs/archive/card-game.md](docs/archive/card-game.md) | 이전 카드게임 설계(참고용) |

## 폴더

- `data/words_v2_plan.csv` — 단어 10,000개의 차수·유닛·부위·진화 트리·스테이지·얻는 방법 배정표
- `data/scenes/` — 장면 데이터(누가, 어떤 순서로, 어떤 연출로). 문장은 키만 적는다
- `locale/` — 모든 게임 문장(한국어 `ko` 열, 언어를 늘리면 열 추가)
- `tools/assign/` — 배정표를 다시 만드는 스크립트
- `tools/story/render.py` — 장면 데이터와 문장으로 청사진·대본 문서를 다시 만드는 스크립트

설계 문서는 Claude Docs에서 옮겨 왔다. 앞으로는 이 저장소의 문서가 기준이다.
