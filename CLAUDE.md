# CLAUDE.md

어원 단어장 데이터로 만드는 수집형 RPG(Godot 4, GDScript).

## 작업 전에 읽을 것
- 설계: `docs/design/01-rpg-base.md`, `docs/design/02-rpg-v2.md`
- 이야기: `docs/story/00-overview.md`
- **코드 규칙: `docs/dev/architecture.md`** — 규칙이 자주 바뀌므로 객체지향으로, 바뀌는 부분은 경계(인터페이스) 뒤에 둔다
- 문장: `docs/i18n.md` — 화면 글자는 모두 `locale/*.csv`의 키로

## 빌드·테스트
- 방법은 `docs/dev/build.md`. 커밋 전에 GUT 테스트가 통과해야 한다:
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`
- 단어장 앱 저장소는 읽기만 한다(`tools/data/build_game_data.py`).

## 고정 디버그 서명 — 수정 금지
사용자가 명시적으로 요청하지 않는 한 다음을 수정·삭제·재생성하지 않는다. 빌드가 서명 때문에 실패하면 고치지 말고 원인을 사용자에게 알린다.
- `keystore/debug.keystore`, `keystore/debug.sha256`
- `.gitignore`의 `!keystore/debug.keystore` 예외
- `.github/workflows/android-debug.yml`의 "Verify signing key (fixed debug keystore)", "Verify APK signature" 단계
이 키스토어는 디버그 빌드에만 쓴다. 릴리스 서명에는 절대 쓰지 않는다.

## 지킬 것
- 층을 지킨다: 데이터 → 규칙 → 진행 → 표현. 규칙 층은 노드·화면·`tr()`을 모른다.
- 숫자(밸런스)는 `data/balance/`, 문장은 `locale/`. 코드에 직접 쓰지 않는다.
- 규칙 층에는 단위 테스트를 단다. 커밋 전에 테스트가 통과해야 한다.
- 설계와 코드가 다르면 설계 문서를 먼저 고치고 코드를 맞춘다.
- 장면·대사를 고치면 `python3 tools/story/render.py`와 `python3 tools/story/storyboard.py`로 문서와 스토리보드를 다시 만든다.
