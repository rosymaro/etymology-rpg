"""1차 단어를 스테이지·필드/마을에 나누고 words_v2_plan.csv를 만든다.
사용: python3 assign_stages.py <default_words.json> <trees.json> <출력 폴더>
"""
import json,collections,csv,hashlib
import sys
WORDS,TREES,OUTDIR=(sys.argv[1:4]+['default_words.json','trees.json','.'][len(sys.argv)-1:])[:3]
d=json.load(open(WORDS,encoding='utf-8'));W={x['id']:x for x in d['words']}
tr=json.load(open(TREES))
tiers=tr['tiers'];kids=tr['kids'];G=tr['g'];BOSS=tr['boss']
units={1:'facere struere forma parare nasci plere',2:'capere tenere prehendere habere quaerere',3:'spectare videre sentire',4:'legere cernere noscere putare aequus',5:'dicere scribere signum lex ius',6:'cedere venire ire gradus currere sequi locus',7:'ferre portare mittere dare pendere pax gratus',8:'ducere regere agere cura caput',9:'trahere premere jacere tendere petere',10:'vertere tornare plicare movere',11:'stare ponere sedere claudere ligare stringere valere fortis',12:'rumpere caedere cadere finis pars'}
r2u={r:u for u,s in units.items() for r in s.split()}
UN={1:'만들기',2:'잡기',3:'보기',4:'알기',5:'말하기',6:'가기',7:'나르기·주기',8:'이끌기',9:'끌기·던지기',10:'돌리기',11:'서기·두기',12:'깨기·자르기'}
AN={1:'생명',2:'영혼',3:'지혜',4:'파동',5:'자연',6:'원소',7:'일상',8:'창조',9:'공간',10:'시간',11:'바람',12:'유대',13:'권위',14:'파멸',15:'번영',16:'영감',17:'신성',18:'형상',19:'심판',20:'질서'}
STAGES={1:('공방 마을',{1},'destroyer'),2:('사냥꾼 초원',{2},'predator'),3:('망루 도서관',{3,4},'wizard'),4:('바람 협곡',{6},'hurricane'),5:('항구 도시',{7},'pirate'),6:('왕성',{5,8},'dictator'),7:('소용돌이 호수',{10},'vortex'),8:('성벽 요새',{9,11},'guardian'),9:('부서진 광산',{12},'dragon'),10:('갈라진 탑',set(),'devil')}
U={i:{r2u[r['rootId']] for r in x['roots'] if r['rootId'] in r2u} for i,x in W.items()}
DS={i:set(x['domains']) for i,x in W.items()}
T1=[i for i,t in tiers.items() if t==1]
# attribute order: T1 words weighted by frequency (easy & many)
score=collections.Counter()
for i in T1:
    for a in DS[i]: score[a]+=W[i]['frequency']-3
order=[a for a,_ in score.most_common()]
OPEN={1:1,2:4,3:8,4:12,5:16,6:20,7:20,8:20,9:20,10:20}
def opened(s): return set(order[:OPEN[s]])
unlock={i:min(s for s in range(1,11) if DS[i]<=opened(s)) for i in T1}
# assign stage: family-match stage >= unlock, else balance
target=len(T1)/10
st={}; cnt=collections.Counter()
fam={s:v[1] for s,v in STAGES.items()}
items=sorted(T1,key=lambda i:(-W[i]['frequency'],hashlib.md5(i.encode()).hexdigest()))
for i in items:
    m=[s for s in range(unlock[i],10) if fam[s]&U[i] and cnt[s]<target*1.15]
    if m: st[i]=m[0]; cnt[m[0]]+=1
for i in items:
    if i in st: continue
    cand=list(range(unlock[i],11))
    s=min(cand,key=lambda s:(cnt[s]>=target, cnt[s]/target if s>unlock[i] else cnt[s]/target-0.3))
    st[i]=s; cnt[s]+=1
# town ~20% per stage: frequent words without family match
town=set()
for s in range(1,11):
    ws=[i for i in T1 if st[i]==s]
    nonfam=sorted([i for i in ws if not (fam[s]&U[i])],key=lambda i:(-W[i]['frequency'],hashlib.md5(i.encode()).hexdigest()))
    town|=set(nonfam[:round(len(ws)*0.2)])
print('속성 여는 순서',[AN[a] for a in order])
for s in range(1,11):
    ws=[i for i in T1 if st[i]==s]
    print(s,STAGES[s][0],'열린속성',OPEN[s],'단어',len(ws),'마을',sum(i in town for i in ws),'장소어근',sum(bool(fam[s]&U[i]) for i in ws),'평균빈도',round(sum(W[i]['frequency'] for i in ws)/len(ws),2))
# tree info
par={c:p for p,v in kids.items() for c in v}
root={}
def top(i):
    while i in par: i=par[i]
    return i
tops=sorted({top(i) for i in tiers},key=lambda i:(G[i][0],G[i][1],i))
tid={t:n+1 for n,t in enumerate(tops)}
SL=['무기','머리','가슴','장갑','신발']
rows=[]
for i,x in W.items():
    if i in BOSS:
        s=[k for k,v in STAGES.items() if v[2]==i][0]
        rows.append([x['word'],x['meaning'],x['frequency'],'/'.join(AN[a] for a in x['domains']),'보스','','','','',s,STAGES[s][0],'보스','',''])
        continue
    t=tiers[i]; u,sl=G[i]
    if t==1: src='마을' if i in town else '필드'; s=st[i]; sn=STAGES[s][0]
    else: src='진화'; s='';sn=''
    rows.append([x['word'],x['meaning'],x['frequency'],'/'.join(AN[a] for a in x['domains']),t,UN[u],SL[sl],tid[top(i)],par.get(i,''),s,sn,src,' + '.join(kids.get(i,[])),'예' if u in U[i] else ''])
rows.sort(key=lambda r:(r[7] if r[7]!='' else 0, -(r[4] if isinstance(r[4],int) else 9)))
with open(OUTDIR+'/words_v2_plan.csv','w',newline='',encoding='utf-8-sig') as f:
    w=csv.writer(f); w.writerow(['word','meaning','frequency','속성(주/보조)','차수','유닛','부위','트리','진화해서 되는 단어','스테이지','장소','얻는 방법','재료(아래 차수 2개)','유닛 어근 일치'])
    w.writerows(rows)
json.dump({'order':order,'st':st,'town':sorted(town)},open(OUTDIR+'/stage.json','w'))
# examples: pick trees with high root share
def rs(t):
    sub=[t]; q=[t]
    while q:
        y=q.pop(); q+=kids.get(y,[]); sub+=kids.get(y,[])
    return sum(1 for c in sub if c in par and set(r['rootId'] for r in W[c]['roots'])&set(r['rootId'] for r in W[par[c]]['roots']))
best=sorted(tops,key=lambda t:-rs(t))[:3]
for t in best:
    def show(y,dep=0):
        print('  '*dep+f"{tiers[y]}차 {W[y]['word']} ({'/'.join(AN[a] for a in W[y]['domains'])}) {W[y]['meaning'][:18]}")
        for c in kids.get(y,[]): show(c,dep+1)
    print('트리',tid[t],UN[G[t][0]],SL[G[t][1]]); show(t)
