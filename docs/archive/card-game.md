# 어원 카드게임 설계: 유닛 특수능력


## 규칙 요약

유닛 65장(어근)과 마법 14장(접두사)으로 덱을 짠다. 마법은 늘 자기 효과를 내고, 유닛 위에 걸어 실제 영어 단어가 되면 그 유닛의 특수능력이 **그 턴에만** 발현된다.

- **유닛 = 어근.** 공격·체력으로 싸우는 하수인. 특수능력은 평소에 잠겨 있다.
- **마법 = 접두사.** 아군 유닛 하나에 건다. 조합이 되든 안 되든 마법 효과는 그대로 들어간다.
- **조합 = 실제 단어.** 접두사 + 어근이 실제 단어면(ex + portare = export) 그 턴에 그 유닛의 특수능력이 켜진다. 턴이 끝나면 다시 잠긴다.
- **능력 계열 12개.** 어근 뜻을 12가지 행동으로 묶었다. 같은 계열 안에서도 어근마다 세부 뜻이 달라 효과가 조금씩 다르다(capere는 빼앗기, tenere는 묶어 두기).
- 수치(마나, 공격·체력, 피해량)는 아직 정하지 않았다. 아래 숫자는 자리 표시용이다.
- 유닛 후보: 단어장 상위 100개 어근 중 접두사 14개와 실제 단어 조합이 3개 이상인 65개. 조합은 모두 358개.

## 마법 14장 (접두사)

마법 효과는 접두사 뜻을 그대로 옮겨, 효과만 보아도 뜻이 떠오르게 했다. 모두 아군 유닛 하나에 건다. 조합 유닛 수는 아래 유닛 65장 중 실제 단어가 되는 수다.

| 마법 | 뜻 | 기본 효과 | 조합 유닛 수 | 대표 단어 |
| --- | --- | --- | --- | --- |
| com- | 함께 | 대상과 양옆 아군 유닛 모두 +1/+1 | 44 | compose, collect, conduct |
| re- | 다시, 되돌려 | 이미 공격한 대상도 한 번 더 공격할 수 있다 | 41 | return, reject, reduce |
| ad- | \~쪽으로 | 대상이 이번 턴 돌진(내자마자 공격) | 39 | attract, accept, admit |
| in- | 안으로 | 카드 1장을 뽑는다 (덱에서 들이기) | 38 | import, inject, include |
| ex- | 밖으로 | 대상 공격력 +2 (밖으로 뻗음) | 34 | export, extract, exclude |
| de- | 아래로, 떨어져 | 적 유닛 하나 공격력 −2 | 26 | deposit, decide, depend |
| dis- | 따로 | 적 유닛 하나에 걸린 강화를 떼어 낸다 | 22 | distract, dismiss, disrupt |
| sub- | 아래에 | 대상이 다음 내 턴까지 은신 | 21 | support, submit, suspect |
| pro- | 앞으로 | 대상이 도발(앞에 나서서 막음) | 19 | project, produce, proceed |
| prae- | 미리 | 내 덱 맨 위 2장을 보고 순서를 정한다 | 17 | predict, prevent, prepare |
| in- (아닌) | 아닌, 없는 | 적 유닛 하나의 능력을 이번 턴 무효(침묵) | 16 | invisible, incapable, illegal |
| ob- | 맞서 | 대상이 다음에 공격받으면 반격 피해 +2 | 15 | object, obtain, occur |
| inter- | 사이에 | 대상과 다른 아군 유닛의 자리를 바꾼다 | 14 | interrupt, intercept, interview |
| un- | 아닌, 되돌림 | 대상에 걸린 해로운 효과를 모두 푼다 | 12 | unstable, unjust, uncertain |

in-은 두 장으로 나눠 두었다. 같은 철자라도 뜻이 다르기 때문이다(import는 안으로, impossible은 아닌).

## 유닛 65장 (어근)

특수능력은 모두 "실제 단어가 되는 마법을 받은 그 턴에만" 발현된다. 같은 계열 안에서는 어근의 세부 뜻으로 효과를 갈랐다. "실제 조합"은 그 유닛에 걸면 능력이 켜지는 마법과 그 단어다.

### 1. 만들기 (카드·유닛을 만든다)

| 유닛 | 뜻 | 특수능력 | 실제 조합 |
| --- | --- | --- | --- |
| facere | 만들다, 하다 | 내 손패의 마법 1장을 복사해 손패에 넣는다 | effect, affect, defect, profit, infect |
| struere | 짓다, 쌓다 | 0/3 벽 유닛을 옆에 소환한다 (쌓기) | construct, industry, destroy, obstruction |
| forma | 모양, 틀 | 다른 아군 유닛 하나의 공격·체력을 이 유닛과 같게 만든다 | inform, reform, conform |
| parare | 준비하다 | 다음 내 턴 마법 비용 −1 | prepare, repair, apparel |
| nasci | 태어나다 | 내 덱에서 무작위 유닛 1장을 바로 내놓는다 | innate, renaissance, international |
| plere | 채우다 | 내 손패를 최대 3장까지 채운다 | supply, comply, implement |

### 2. 잡기 (상대 것을 잡거나 붙든다)

| 유닛 | 뜻 | 특수능력 | 실제 조합 |
| --- | --- | --- | --- |
| capere | 잡다, 취하다 | 상대 손패에서 무작위 1장을 빼앗는다 | accept, except, concept, receipt, intercept, occupy |
| tenere | 붙들다, 유지하다 | 적 유닛 하나를 다음 상대 턴까지 묶어 둔다(공격 불가) | contain, retain, detain, sustain, obtain |
| prehendere | 움켜쥐다 | 적 유닛 하나를 이번 턴 내 편으로 부린다 | comprise, enterprise, apprentice |
| habere | 가지다, 쥐다 | 적 유닛 하나의 능력을 이번 턴 빌려 쓴다 | enable, exhibit, prohibit, disable, inability |
| quaerere | 찾다, 구하다 | 내 덱에서 원하는 카드 1장을 찾아 손패에 넣는다 | require, acquire, conquer, inquest |

### 3. 보기 (숨은 것을 본다)

| 유닛 | 뜻 | 특수능력 | 실제 조합 |
| --- | --- | --- | --- |
| spectare | 바라보다 | 상대 손패를 모두 본다 | inspect, respect, expect, suspect, prospect |
| videre | 보다 | 숨어 있는 적(은신)을 드러내고, 내 덱 맨 위 1장을 본다 | provide, review, advise, evident, invisible, preview |
| sentire | 느끼다 | 이번 턴 내 유닛이 받는 피해를 미리 알고 첫 피해를 피한다 | consent, resent, dissent, insensitive |

### 4. 알기·가려내기 (골라서 나눈다)

| 유닛 | 뜻 | 특수능력 | 실제 조합 |
| --- | --- | --- | --- |
| legere | 모으다, 고르다, 읽다 | 내 덱 위 3장 중 1장을 골라 가진다 | collect, elect, intellect, diligent |
| cernere | 가려내다, 정하다 | 적 유닛과 아군 유닛 중 하나씩 골라 서로 맞서게 한다 | discern, concern, decree, uncertain |
| noscere | 알게 되다 | 상대가 다음에 낼 마법 1장을 보고, 그 마법 비용 +1 | recognize, cognitive, acquaintance, ignore |
| putare | 셈하다 | 양쪽 유닛 수를 세어, 차이만큼 카드를 뽑는다 | count, dispute, deputy, reputed |
| aequus | 같은, 고른 | 양쪽 영웅 체력을 두 값의 가운데로 맞춘다 | adequate, unequal, inequality |

### 5. 말하기·쓰기 (선언하고 지정한다)

| 유닛 | 뜻 | 특수능력 | 실제 조합 |
| --- | --- | --- | --- |
| dicere | 말하다 | 카드 종류(유닛/마법)를 선언한다. 상대는 다음 턴에 그 종류를 낼 수 없다 | predict, indicate, dedicate, addict, condition |
| scribere | 쓰다 | 이번 턴 낸 마법 1장을 이 유닛에 새겨, 다음 내 턴에 한 번 더 발동한다 | describe, subscribe, prescribe, inscribe |
| signum | 표시 | 적 유닛 하나에 표식을 단다. 표식이 붙은 유닛은 내 유닛에게 피해를 2배로 받는다 | design, assign, resign, insignificant |
| lex | 법 | 이번 턴과 다음 상대 턴, 양쪽 모두 턴당 카드 2장까지만 낼 수 있다 | colleague, delegation, illegal |
| ius | 법, 올바름 | 이번 턴 내가 받은 피해만큼 그 피해를 준 유닛에게 돌려준다 | adjust, prejudice, injury, unjust |

### 6. 가기·오기 (자리와 순서를 옮긴다)

| 유닛 | 뜻 | 특수능력 | 실제 조합 |
| --- | --- | --- | --- |
| cedere | 가다, 물러서다 | 이 유닛을 손패로 물리고, 비용을 돌려받는다 | proceed, succeed, exceed, access, concede, recess |
| venire | 오다 | 내 무덤의 유닛 1장을 돌아오게 한다 | prevent, invent, event, advent, intervene, revenue |
| ire | 가다 | 이 유닛이 적 유닛을 무시하고 영웅을 바로 공격한다 | exit, initial, sudden |
| gradus | 걸음, 단계 | 이 유닛의 단계를 1 올린다(영구 +1/+1). 걸릴 때마다 쌓인다 | progress, degree, aggressive, ingredient, congress |
| currere | 달리다 | 이번 턴 이 유닛은 두 번 공격한다 | occur, recur, incur, concurrent, excursion, precursor |
| sequi | 뒤따르다 | 다른 아군 유닛이 공격하면 이 유닛도 같은 대상을 따라 공격한다 | pursue, execute, consecutive, subsequent |
| locus | 장소 | 적 유닛 하나를 원하는 자리로 옮긴다 | allocate, relocate, allow |

### 7. 나르기·주기 (카드와 힘을 주고받는다)

| 유닛 | 뜻 | 특수능력 | 실제 조합 |
| --- | --- | --- | --- |
| ferre | 나르다, 지니다 | 이 유닛에 걸린 효과를 다른 아군 유닛에 옮겨 붙인다 | refer, offer, prefer, confer, suffer, differ |
| portare | 나르다 | 내 손패 1장을 상대 손패로 내보내거나(ex-), 상대 무덤에서 1장을 들여온다(in-) | export, import, support, report, deport |
| mittere | 보내다, 놓아주다 | 적 유닛 하나를 상대 손패로 돌려보낸다 | dismiss, admit, submit, commit, emit, omit, promise |
| dare | 주다 | 다른 아군 유닛에게 이 유닛의 공격력만큼 공격력을 준다 | add, edit, render |
| pendere | 달다, 지불하다 | 내 영웅 체력을 내고 그만큼 카드를 뽑는다 | spend, depend, suspend, compensate |
| pax | 평화, 갚다 | 이번 턴 양쪽 모두 공격할 수 없고, 내 영웅 체력을 회복한다 | appease, repay, unpaid |
| gratus | 기쁘게 하는 | 내 모든 유닛의 체력을 회복한다 | agree, congratulate, disgrace, ungrateful |

### 8. 이끌기·다스리기 (다른 유닛을 움직인다)

| 유닛 | 뜻 | 특수능력 | 실제 조합 |
| --- | --- | --- | --- |
| ducere | 이끌다 | 다른 아군 유닛 모두 이번 턴 공격력 +1 (이끌기) | produce, conduct, reduce, induce, educate, deduce |
| regere | 다스리다, 바로잡다 | 적 유닛 하나의 공격 대상을 내가 정한다 | direct, correct, erect, address, redirect |
| agere | 하다, 몰다 | 이번 턴 이미 행동한 아군 유닛 하나를 다시 행동하게 한다 | react, interact, enact, proactive, inactive |
| cura | 돌봄 | 다른 아군 유닛 하나를 다음 내 턴까지 피해를 받지 않게 한다 | accurate, ensure, proxy |
| caput | 머리 | 이 유닛이 살아 있는 동안 아군 유닛 모두 체력 +1 (이번 턴) | achieve, recap, precipitation |

### 9. 끌기·밀기·던지기 (거리를 바꾼다)

| 유닛 | 뜻 | 특수능력 | 실제 조합 |
| --- | --- | --- | --- |
| trahere | 끌다 | 적 유닛 하나를 이 유닛 앞으로 끌어와 서로 싸우게 한다 | attract, extract, contract, distract, subtract, retract |
| premere | 누르다 | 적 유닛 하나를 누른다: 다음 상대 턴까지 공격력 0 | express, impress, suppress, depression |
| jacere | 던지다 | 이 유닛의 공격력만큼 원하는 대상에게 피해를 던진다(공격 없이) | project, reject, inject, object, subject, eject |
| tendere | 뻗다, 늘이다 | 이번 턴 이 유닛의 공격이 대상 양옆 유닛에게도 뻗친다 | extend, attend, intend, contend, pretend |
| petere | 노리다, 찾다 | 적 하나를 노린다: 그 대상에게는 도발과 은신을 무시하고 공격한다 | compete, repeat, appetite, impetus |

### 10. 돌리기·바꾸기 (상태를 뒤집는다)

| 유닛 | 뜻 | 특수능력 | 실제 조합 |
| --- | --- | --- | --- |
| vertere | 돌리다 | 적 유닛 하나의 공격력과 체력을 맞바꾼다 | convert, reverse, divert, adverse, inverse |
| tornare | 돌리다(선반) | 이 유닛이 이번 턴 받은 피해를 모두 되돌린다(턴 시작 상태로) | return, detour, contour, attorney |
| plicare | 접다, 펼치다 | 접기(re-·com-): 이 유닛을 카드로 접어 손패에. 펼치기(ex-·dis-·ad-): 손패의 유닛 1장을 비용 없이 펼친다 | apply, deploy, imply, reply, exploit, complicate |
| movere | 움직이다 | 아군 유닛들의 자리를 원하는 대로 다시 배치한다 | remove, promote, emotion |

### 11. 서기·두기·지키기 (버티고 막는다)

| 유닛 | 뜻 | 특수능력 | 실제 조합 |
| --- | --- | --- | --- |
| stare | 서다 | 다음 내 턴까지 이 유닛은 죽지 않는다(체력 1 아래로 안 떨어짐) | resist, insist, assist, exist, substance, obstacle |
| ponere | 놓다, 두다 | 손패의 카드 1장을 엎어 둔다. 상대가 그 종류를 내면 자동으로 발동 | compose, oppose, deposit, propose, expose, suppose |
| sedere | 앉다 | 이 유닛이 자리에 앉는다: 이번 턴 공격하지 않고 체력을 모두 회복 | reside, president, assess, subsidy, obsession |
| claudere | 닫다 | 상대 마법 1장을 다음 턴 동안 닫아 둔다(낼 수 없음) | include, exclude, conclude, disclose |
| ligare | 묶다 | 이 유닛과 다른 아군 유닛을 묶는다: 피해를 나눠 받는다 | rely, ally, obligation |
| stringere | 조이다 | 적 유닛 모두 다음 상대 턴에 능력을 쓸 수 없다 | restrict, constraint, district, prestige |
| valere | 힘이 있다, 가치 있다 | 이 유닛의 공격력을 내 손패 수만큼 올린다 | prevail, evaluate, avail, invalid |
| fortis | 강한 | 이 유닛 체력 +3, 다음 피해 1번을 막는 보호막 | effort, enforce, comfort |

### 12. 깨기·자르기 (부수고 나눈다)

| 유닛 | 뜻 | 특수능력 | 실제 조합 |
| --- | --- | --- | --- |
| rumpere | 깨다 | 적 유닛 하나의 보호막·도발·강화를 모두 깬다 | interrupt, disrupt, corrupt, eruption |
| caedere | 자르다 | 적 유닛 하나의 체력을 반으로 자른다 | decide, precise, concise, excise |
| cadere | 떨어지다 | 체력이 가장 낮은 적 유닛 1장을 떨어뜨린다(파괴) | accident, incident, occasion, decay |
| finis | 끝, 경계 | 이번 턴 끝에 상대 유닛 중 공격력이 이 유닛보다 낮은 것을 모두 끝낸다 | define, refine, infinite, confine, unfinished |
| pars | 부분, 몫 | 이 유닛을 두 개로 나눈다(공격·체력을 반씩) | depart, apart, proportion, compartment, impartial |

## 덱 구성과 레벨 디자인 때 볼 점

레벨 디자인은 나중에 다시 보기로 했으니, 능력을 짠 때 눈에 띈 점만 적어 둔다.

- **강해 보이는 능력:** capere(손패 빼앗기), cadere(파괴), finis(여러 장 끝내기), lex(카드 제한), pax(공격 금지). 비용을 높이거나 조합 단어가 적은 쪽에 두는 것이 좋다.
- **마법 불균형:** com-은 유닛 44장과 조합되고 un-은 12장뿐이다. 조합이 많은 마법은 기본 효과를 약하게, 적은 마법은 강하게 맞춘다.
- **접두사에 따라 달라지는 능력:** portare(ex-는 내보내기, in-은 들여오기), plicare(접기·펼치기). 단어 뜻과 가장 잘 맞는 방식이라, 다른 유닛에도 넓힐 수 있다.
- **덱 규칙 초안:** 30장, 같은 카드 2장까지, 유닛과 마법 비율은 자유. 조합을 노리는 덱은 유닛이 자주 만나는 접두사를 모으게 된다.
- **빠진 어근:** 상위 100개 중 조합이 3개 미만인 35개(log, graph, manus 등)는 빼두었다. 고대 영어 접두사(out-, over-, under-) 마법을 더하면 일부를 다시 넣을 수 있다.
- **조합 단어 목록:** 표의 단어는 대표 예시다. 게임이 판정에 쓸 전체 358개 조합은 단어장 데이터에서 바로 뽑을 수 있다.
