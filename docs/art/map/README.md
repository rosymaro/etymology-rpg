# 지도 배경 미리보기

지금 게임의 지도 배경(지도 그리개 `tools/map/paint/`가 그린 동화책 삽화풍)을 본다. 다시 만들기: `python3 tools/map/paint/preview.py --pieces`. 사람이 새로 그릴 때 참고한다. 그리는 규칙은 `assets/map/README.md`.

- [`overview.jpg`](overview.jpg): 지도 전체를 1/8 크기로 줄인 것. 장 번호 격자가 있다.
- [`preview/`](preview): 장마다 원래 크기(1024×1536px, 지도 끝 장은 더 작다)로 겹을 합친 모습. 이름은 `<열>_<행>.jpg`.
- 지역마다의 풍경·색·분위기(사막, 밀림, 눈, 용암 …)는 `docs/design/art-direction.md`의 '지도' 절 표.

PSD(장마다 겹 ground·grass·mtn·trees·guide)는 크기가 커서(약 780MB) 저장소에 넣지 않는다. 필요하면 만든다:
`python3 tools/map/export_map.py <폴더>`. 이 미리보기도 그때 같이 나온다(`overview.png`, `preview/`).
