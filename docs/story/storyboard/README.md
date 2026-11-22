# 스토리보드

`index.html`은 콘티와 빌려 온 개념 그림을 그리는 페이지다. `storyboard.json`을 읽어 브라우저에서 그린다(GitHub 미리보기에서는 실행되지 않는다).

- 게시된 페이지: https://claude.ai/artifact/MbwQaQcK1M2wiZ8aVZGUNe (비공개, 소유자만 열 수 있음)
- 로컬에서 보기: 이 폴더에서 `python3 -m http.server` 뒤 `http://localhost:8000` 열기
- 데이터 다시 만들기(저장소 루트에서): `python3 tools/story/storyboard.py`
- 컷 데이터는 `data/scenes/*.json`의 `conti`에 있다. 컷 하나는 샷(`wide`/`mid`/`close`), 배경, 등장인물 위치(`x`는 화면 가로 %), 효과, 말풍선으로 보여 줄 대사 번호(`say`), 설명(`note`)이다.
- 빌려 온 개념 그림은 원작 화면이 아니라 개념을 설명하는 그림이다.
