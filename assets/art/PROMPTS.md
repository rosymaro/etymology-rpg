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

| 파일 | 프롬프트(공통 스타일 뒤에) |
|---|---|
| `map/s01_world.png` | top-down view of a small craftsman village on the left with dirt paths and cozy round-roofed houses, a wooden fence running vertically with an open gate in the middle, a wide flowery meadow on the right, empty clearings where buildings will be placed, 26:15 wide map, no characters |
| `map/grass_tuft.png` | a single small tuft of grass with two tiny pink flower dots, top-down |
| `building/forge.png` | a cute round blacksmith forge with a glowing furnace and an anvil, small chimney puffing a heart-shaped smoke, 3/4 top-down view |
| `building/tree.png` | a big friendly tree whose roots end in little hanging word cards, some roots cut with a faint crack pattern, 3/4 top-down view |
| `building/board.png` | a wooden workbench with order slips pinned on a board, a tiny conveyor belt beside it, 3/4 top-down view |
| `building/boss.png` | a rounded stone gate on a hill covered with a grey crack pattern spreading like ink, slightly ominous but cute |
| `building/boss_gate_open.png` | the same rounded stone gate, crack pattern gone, small flowers blooming around it |
| `hero/look0.png` | a young apprentice in a simple apron and cap, full body, 3/4 top-down view, standing, friendly smile |
| `hero/look1.png` ~ `look5.png` | the same apprentice wearing (1) a sprout-green little cape (2) an explorer vest with pockets (3) a scholar robe (4) a sage cape with leaf pattern (5) a golden cape; same face and pose as look0 |
| `face/hero_normal.png` | bust portrait of the apprentice from look0, facing slightly right, gentle smile |
| `face/ttukttak_normal.png` | bust portrait of a chubby penguin-chick holding a small hammer and a ruler, apricot accent color, cheerful |
| `face/blacksmith_normal.png` | bust portrait of a round, kind blacksmith with a big mustache and a leather apron, tired but warm |
| `unit/u01.png` ~ `u12.png` | a chubby penguin-chick character, full body, {대표 색} accent color, holding {소품}, battle-ready cute pose (표는 README '유닛 12종') |
| `enemy/field_wanderer.png` | a tiny speech-bubble shaped fairy made of a word card, faded grey colors as if it lost its color, curious face |
| `enemy/attr_NN.png` | the same speech-bubble word fairy, colored with {속성 이름} theme (예: 생명 = leaf and heart, 원소 = fire and water drops, 파동 = sound waves), cute |
| `boss/destroyer.png` | a big clumsy destroyer monster made of broken tools and bricks, exaggerated surprised face, grey crack pattern on its body, more silly than scary |
| `mini/order_belt.png` | side view of a seamless horizontal conveyor belt with rollers, soft grey-violet, wide 1280x200, no objects on it |
| `mini/order_card.png` | a blank rounded rectangle wooden tag, white and very light grey, empty center for text, slight shadow |
| `mini/fish_word.png` | a cute long fish seen from the side, wide pale cream body with an empty space in the middle for text, small tail fin, 240x80 |
| `mini/fish_bait.png` | a small cute bait on a fishing hook, 60x60 |
| `mini/guard_wall.png` | a stone castle wall seen from outside with a round wooden gate in the center, wide banner shape, 1280x190 |
| `mini/guard_traveler.png` | a cute traveler holding a wide blank sign board for text, 240x110 |
| `mini/guard_climber.png` | a sneaky cute figure carrying a ladder, blank space for text in the middle, 180x70 |
| `mini/guard_unit.png` | a cute guard seen from behind holding a wide shield, blocking stance, 200x90 |
| `mini/sprout.png` | a tiny two-leaf sprout popping up, 60x60 |
| `mini/root_wisp.png` | a floating round root spirit with tiny root tendrils, empty pale space in the middle for text, 190x70 |
| `mini/ore_vein.png` | a rounded ore rock with a shining vein, drawn in white and very light grey only |
| `mini/ore_rock.png` | a plain grey round rock with a small grumpy face |
| `ui/order_ticket.png` | a small paper order slip icon with a pin |

## 넣는 법

1. 만든 그림을 위 파일 이름으로 `assets/art/<종류>/`에 넣는다(예: `assets/art/unit/u01.png`).
2. 배경이 남아 있으면 투명으로 지운다.
3. 커밋하면 CI가 APK를 만들고 `debug-latest` 릴리스에 올린다. 폰에서 덮어 설치해 확인한다.
