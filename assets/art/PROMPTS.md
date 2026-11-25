# AI 그림 프롬프트

모든 그림에 **공통 스타일**을 앞에 붙이고, 그 뒤에 그림마다의 내용을 붙인다. 한 번에 여러 장을 만들면 모양이 달라지므로, 마음에 드는 그림이 나오면 그 그림을 참조 이미지로 넣고 나머지를 만든다(특히 유닛 12종, 적 20종).

## 공통 스타일 (영어, 모든 그림 앞에)

```
children's picture book illustration, cute chibi style, 2-head-tall proportions, big head small body,
simple dot eyes, soft pink blush on cheeks, rounded shapes with no sharp corners,
soft navy-purple outline (#4b3f72) of even width with round ends, no black lines,
muted pastel palette (sky blue, mint green, apricot, light pink), soft watercolor fill with subtle paper texture,
gentle wide gradients, warm and friendly mood, game asset, centered, transparent background
```

배경이 있는 그림(맵, 벨트)은 마지막의 `transparent background`를 빼고 `seamless` 또는 `top-down view`를 넣는다.

## 하지 말 것 (네거티브)

```
realistic shading, metallic texture, sharp edges, black outline, high contrast primary colors, dark background,
blood, wounds, scary, text, letters, watermark, logo, existing game characters
```

## 그림마다

이름과 크기는 [README.md](README.md)(그림 콘티)가 기준이다. 아래는 공통 스타일 뒤에 붙이는 내용이다.

### 오프닝·타이틀 (배경 있음: `transparent background` 대신 `full scene, portrait 9:16`)

| 파일 | 프롬프트 |
|---|---|
| `title/key_art.png` | a giant friendly tree on a hill whose root tips hold small glowing word cards like lanterns, a young apprentice boy and girl and a chubby penguin chick with a hammer standing under it, upper third left empty for a title, dawn light |
| `opening/op01_tree.png` | a giant magical tree under a night sky, every root tip holds a tiny glowing card like a lantern, warm golden glow, mysterious and gentle, no characters |
| `opening/op02_crack.png` | the same tree at deep navy night, a grey crack pattern spreading over the roots like ink, roots snapping, lonely rather than scary |
| `opening/op03_fall.png` | close view of colorless grey cards falling like autumn leaves, soft bokeh, melancholic |
| `opening/op04_village.png` | morning view from a hill of a cozy craftsman village with round roofs and chimney smoke, a glowing forge, but signboards and notice boards are faded grey |
| `opening/op05_forge_front_m.png` / `_f.png` | in front of a cozy forge in the morning, a big kind blacksmith with a mustache introduces a chubby penguin chick raising a hammer, a young apprentice {boy / girl} in an apron and cap watches |
| `opening/op06_hammer_m.png` / `_f.png` | inside the forge, the apprentice {boy / girl} raises a hammer over an anvil, warm furnace light on the face |
| `opening/op07_defect.png` | close-up of a freshly made object cracking, a blank grey card popping out of the crack, sparks, no text on the card |
| `opening/op08_split.png` | the chubby penguin chick happily holding a grey card split into two pieces, color starting to bloom from the split, blank card faces |

### 주인공 남·여

| 파일 | 프롬프트 |
|---|---|
| `hero/m_down.png` 등 | a young apprentice {boy / girl} in a simple apron and soft cap, full body, 3/4 top-down view, facing {down / up / left / right}, standing, friendly |
| `hero/m_look1~5.png` | the same apprentice wearing (1) a sprout-green little cape (2) an explorer vest with pockets (3) a scholar robe (4) a sage cape with leaf pattern (5) a golden cape; same face and pose |
| `face/hero_m_<표정>.png` | bust portrait of the apprentice {boy / girl}, facing slightly right, {gentle smile / big happy smile / surprised / sad / pouting angry} |

### 유닛(펭귄·병아리 두 모습)

| 파일 | 프롬프트 |
|---|---|
| `unit/penguin/uNN.png` | a chubby baby penguin character, full body, {대표 색} accent color, {소품·모습}, {성격이 보이는 자세}, battle-ready cute pose (README 4절 표) |
| `unit/chick/uNN.png` | a chubby yellow baby chick character with the same {대표 색} accessories, {소품·모습}, {성격이 보이는 자세} |
| `unit/*/palNN.png` | the same character, small full body, 3/4 top-down view, walking, very simple shapes so the prop is readable when small |
| `face/uNN_p_<표정>.png` | bust portrait of the same character, {cheerful / happy / surprised / sad / angry} |

한 유닛은 펭귄 카드를 먼저 만들고, 그것을 참조 이미지로 병아리·동행·얼굴을 만든다. 12유닛은 뚝딱을 참조로 같은 그림체를 맞춘다.

### 보스

| 파일 | 프롬프트 |
|---|---|
| `boss/<id>.png` | a huge but goofy {보스 모습(README 5절)}, exaggerated funny expression, a grey crack pattern spreading on part of its body, more silly than scary, full body |
| `boss/<id>_down.png` | the same boss defeated and dizzy, the crack pattern shattered, colors returning, relieved face |
| `opening/devil_reveal.png` | a tall rounded figure covered in a grey splitting pattern (the one who divides), serious but still soft-shaped, standing at the top of a cracked tower, dramatic sky, full scene |

### 사람(NPC)

| 파일 | 프롬프트 |
|---|---|
| `face/<id>_normal.png` | bust portrait of {인물 모습(README 6절)}, picture book villager, 2.5-head-tall chibi |
| `npc/<id>.png` | the same person, full body, 3/4 top-down view, standing |

### 몹·지도·물건

| 파일 | 프롬프트 |
|---|---|
| `enemy/aNN_<성격>.png` | a tiny faded-grey word fairy whose body is {속성 모티프(README 7절)}, small accents in {속성 색}, a blank light band across the belly for a word, {wander: sleepy half-closed eyes, floating calmly / chase: raised eyebrows, tiny fang, leaning forward with arms up / flee: wide scared eyes, one sweat drop, looking back while running away, tiny sparkles / rush: crouched low, puffing, frowning, head thrust forward ready to charge}, 3/4 top-down view, no symbols or text |
| `enemy/card_aNN.png` | the same word fairy, front view, larger, battle-ready cute pose |
| `enemy/eater.png` | a dark crimson blob with root-like tentacles and yellow eyes, creepy-cute |
| `tile/<이름>.png` | seamless top-down tile of {grass / dirt town floor / stone road / sea / pond water / cliff / forest canopy / mountain / castle wall / ice / hole / cave floor …}, hand-painted, tileable, no characters |
| `building/<id>.png` | a cute {forge with glowing furnace / workbench with order slips / white-roofed hospital with a big clock / big tree with word cards on roots / notice board with three blanks / gacha shop / small round house}, 3/4 top-down view |
| `prop/<id>.png` | a {round push rock / heavy striped rock / pressure plate / treasure chest / chest with a word lock / paper note / toy hammer / glowing orb / coin / word card}, 3/4 top-down view |
