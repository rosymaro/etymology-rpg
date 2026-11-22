# 빌드, 테스트, 폰에 설치

## 버전

| 도구 | 버전 |
|---|---|
| Godot | 4.7.2-stable(표준판, .NET 아님) |
| GUT(테스트) | 9.7.1, `addons/gut`에 들어 있다 |
| 안드로이드 | arm64-v8a, 가로 화면, 디버그 APK |

## 테스트

```
godot --headless --import --quit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

규칙 층(`src/domain`, `src/data`)은 화면 없이 돌아가므로 모두 단위 테스트를 단다. 커밋 전에 통과해야 한다.

## 디버그 APK (CI)

`.github/workflows/android-debug.yml`이 PR과 `main` 푸시마다 돈다.

1. Godot와 내보내기 템플릿을 공식 릴리스에서 받는다.
2. 프로젝트를 불러오고(import) GUT 테스트를 돌린다.
3. 고정 디버그 키스토어의 지문을 `keystore/debug.sha256`과 비교한다.
4. `export_presets.cfg`의 "Android" 설정으로 APK를 만들고, APK 서명 지문을 다시 비교한다.
5. APK를 Actions 결과물(`etymology-rpg-debug-apk`)로 올린다.

폰에는 Actions 실행 화면에서 결과물을 내려받아 설치한다. 처음 한 번만 '알 수 없는 앱 설치'를 허용하면 된다.

## 고정 디버그 키스토어

CI나 어느 PC에서 빌드해도 서명이 같아야, 폰에 깔린 앱 위에 새 빌드를 지우지 않고 덮어 설치할 수 있다(저장 데이터가 남는다).

| 항목 | 값(디버그 전용, 공개되어도 됨) |
|---|---|
| 파일 | `keystore/debug.keystore` (PKCS12) |
| store/key 비밀번호 | `android` |
| alias | `androiddebugkey` |
| 인증서 SHA-256 | `keystore/debug.sha256` |

- 키스토어를 다시 만들거나 바꾸지 않는다. 바꾸면 폰에서 덮어 설치가 깨진다.
- 이 키는 디버그 빌드에만 쓴다. Play 스토어용 릴리스 키는 저장소에 넣지 않는다.

## 데이터

- 게임 단어 데이터 `data/game/words.json`은 `tools/data/build_game_data.py`로 만든다. 단어장 앱 저장소(`etymology-english-vocabulary`)의 `words.json`·`roots.json`을 **읽기만** 한다. 결과 파일은 이 저장소에 커밋해서, 빌드 때 단어장 저장소가 없어도 된다.
- 밸런스 값은 `data/balance/`. 고친 뒤에는 `python3 tools/balance/sim10.py`로 승률을 다시 본다.
