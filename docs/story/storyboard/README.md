# 스토리보드

`page.html`은 콘티와 빌려 온 개념 그림을 그리는 페이지 본문(Claude 아티팩트로 게시하는 원본), `index.html`은 거기에 HTML 뼈대를 붙인 GitHub Pages용 파일이다. 둘 다 `storyboard.json`을 읽어 브라우저에서 그린다. `page.html`만 고치고 `tools/story/storyboard.py`로 `index.html`을 다시 만든다.

- 게시된 페이지: https://claude.ai/artifact/MbwQaQcK1M2wiZ8aVZGUNe (비공개, 소유자만 열 수 있음)
- GitHub Pages(켜면): https://rosymaro.github.io/etymology-rpg/story/storyboard/
- 로컬에서 보기: 이 폴더에서 `python3 -m http.server` 뒤 `http://localhost:8000` 열기
- 데이터 다시 만들기(저장소 루트에서): `python3 tools/story/storyboard.py`
- 컷 데이터는 `data/scenes/*.json`의 `conti`에 있다. 컷 하나는 샷(`wide`/`mid`/`close`), 배경, 등장인물 위치(`x`는 맵 가로 %, `y`는 맵 세로 %로 위가 0), 효과, 말풍선으로 보여 줄 대사 번호(`say`), 설명(`note`)이다.
- 빌려 온 개념 그림은 원작 화면이 아니라 개념을 설명하는 그림이다.
