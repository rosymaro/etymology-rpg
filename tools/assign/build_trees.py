"""1차~4차 진화 트리와 유닛·부위 배정을 만든다.
사용: python3 build_trees.py <default_words.json> <trees.json>
"""
import json,collections,random,csv,sys
random.seed(7)
WORDS=sys.argv[1] if len(sys.argv)>1 else 'default_words.json'
OUT=sys.argv[2] if len(sys.argv)>2 else 'trees.json'
d=json.load(open(WORDS,encoding='utf-8'));W={x['id']:x for x in d['words']}
units={1:'facere struere forma parare nasci plere',2:'capere tenere prehendere habere quaerere',3:'spectare videre sentire',4:'legere cernere noscere putare aequus',5:'dicere scribere signum lex ius',6:'cedere venire ire gradus currere sequi locus',7:'ferre portare mittere dare pendere pax gratus',8:'ducere regere agere cura caput',9:'trahere premere jacere tendere petere',10:'vertere tornare plicare movere',11:'stare ponere sedere claudere ligare stringere valere fortis',12:'rumpere caedere cadere finis pars'}
r2u={r:u for u,s in units.items() for r in s.split()}
R={i:{r['rootId'] for r in x['roots']} for i,x in W.items()}
U={i:{r2u[r] for r in R[i] if r in r2u} for i in W}
D={i:list(x['domains']) for i,x in W.items()}
DS={i:set(v) for i,v in D.items()}
F={i:x['frequency'] for i,x in W.items()}
H={i:random.random() for i in W}
BOSS=['destroyer','predator','wizard','hurricane','pirate','dictator','vortex','guardian','dragon','devil']
for b in BOSS: assert b in W,b
pool=[i for i in W if i not in BOSS]
SLOTS=['무기','머리','가슴','장갑','신발']
groups=[(u,s) for u in range(1,13) for s in range(5)]
# ---- T4: per group perfect cover of 20 attrs with dual words
duals=sorted([i for i in pool if len(DS[i])>=2],key=lambda i:(F[i],H[i]))
avail=set(duals[:1400])
acnt=collections.Counter(a for i in avail for a in DS[i])
G={g:[] for g in groups}
def pick_group(g):
    u=g[0]; cov=set(); chosen=[]
    while len(cov)<20:
        unc=[a for a in range(1,21) if a not in cov]
        a=min(unc,key=lambda a:acnt[a])
        cands=[i for i in avail if a in DS[i]]
        def sc(i):
            new=len(DS[i]-cov)
            return (new, u in U[i], -F[i], H[i])
        best=max(cands,key=sc)
        chosen.append(best); avail.discard(best); cov|=DS[best]
        for x in DS[best]: acnt[x]-=1
    return chosen
order=groups[:]; random.shuffle(order)
for g in order: G[g]=pick_group(g)
n4=sum(len(v) for v in G.values()); print('T4 after cover',n4)
# extras to reach 666: rarest remaining duals, to groups with fewest
ext=sorted(avail,key=lambda i:(F[i],H[i]))
k=0
while n4<666:
    i=ext[k];k+=1
    g=min(groups,key=lambda g:(len(G[g]), -(g[0] in U[i])))
    G[g].append(i); n4+=1
T4=[i for g in groups for i in G[g]]
tree_g={i:g for g in groups for i in G[g]}
rest=sorted([i for i in pool if i not in set(T4)],key=lambda i:(F[i],H[i]))
T3,T2,T1=rest[:1332],rest[1332:3996],rest[3996:]
assert len(T1)==5328,len(T1)
# ---- type-level flow matching
from collections import deque,defaultdict
def T(i): return frozenset(DS[i])
def maxflow(P,C):
    pc=collections.Counter(T(p) for p in P); cc=collections.Counter(T(c) for c in C)
    pt=list(pc); ct=list(cc)
    N=2+len(pt)+len(ct); src,snk=0,1
    g=[[] for _ in range(N)]
    def add(u,v,c):
        g[u].append([v,c,len(g[v])]); g[v].append([u,0,len(g[u])-1])
    for k,t in enumerate(pt): add(src,2+k,2*pc[t])
    for k,t in enumerate(ct): add(2+len(pt)+k,snk,cc[t])
    for i,t in enumerate(pt):
        for j,u in enumerate(ct):
            if t&u: add(2+i,2+len(pt)+j,10**9)
    flow=0
    while True:
        lv=[-1]*N; lv[src]=0; q=deque([src])
        while q:
            u=q.popleft()
            for v,c,_ in g[u]:
                if c>0 and lv[v]<0: lv[v]=lv[u]+1; q.append(v)
        if lv[snk]<0: break
        it=[0]*N
        def dfs(u,f):
            if u==snk: return f
            while it[u]<len(g[u]):
                e=g[u][it[u]]; v,c,r=e
                if c>0 and lv[v]==lv[u]+1:
                    d=dfs(v,min(f,c))
                    if d>0:
                        e[1]-=d; g[v][r][1]+=d; return d
                it[u]+=1
            return 0
        while True:
            f=dfs(src,10**12)
            if not f: break
            flow+=f
    quota={}
    for i,t in enumerate(pt):
        for v,c,r in g[2+i]:
            if v>=2+len(pt):
                used=g[v][r][1]
                if used>0: quota[(t,ct[v-2-len(pt)])]=used
    # deficient parent types, surplus child types
    deficit=[t for k,t in enumerate(pt) if g[src][k][1]>0]
    surplus=set(ct[k] for k in range(len(ct)) if [e for e in g[2+len(pt)+k] if e[0]==snk][0][1]>0)
    return flow,quota,deficit,surplus
COV=defaultdict(set)
def assign(P,C,quota,gof,t):
    pool=defaultdict(list)
    for c in C: pool[T(c)].append(c)
    q=dict(quota); kids={}
    for p in sorted(P,key=lambda p:H[p]):
        tp=T(p); ks=[]
        for _ in range(2):
            best=None;bs=None
            for (a,b),n in q.items():
                if a!=tp or n<=0: continue
                cv=COV[(gof[p][0],gof[p][1],t)]
                for c in pool[b][:1500]:
                    sc=(len(DS[c]-cv)>0,(R[c]&R[p])!=set(), gof[p][0] in U[c], len(DS[c]&DS[p]), H[c])
                    if bs is None or sc>bs: bs=sc;best=(c,b)
            c,b=best; pool[b].remove(c); q[(tp,b)]-=1; ks.append(c); COV[(gof[p][0],gof[p][1],t)]|=DS[c]
        kids[p]=ks
    return kids
gof=dict(tree_g)
tiers={i:4 for i in T4}
allkids={}; par={}
P=T4; L=rest[:]
for t in (3,2,1):
    need=2*len(P); C=L[:need]; L=L[need:]
    sw=0
    while True:
        flow,quota,deficit,surplus=maxflow(P,C)
        if flow==need: break
        # swap a deficient parent with a child-tier word that fits under its grandparent
        progressed=False
        for p in [p for p in P if T(p) in deficit]:
            qq=par.get(p)
            xs=[x for x in C if T(x) in surplus and (qq is None or DS[x]&DS[qq])]
            if not xs: continue
            x=max(xs,key=lambda x:(F[x]<=F[p], -F[x]))
            if qq is not None:
                allkids[qq][allkids[qq].index(p)]=x; par[x]=qq; del par[p]; gof[x]=gof[qq]
            else:
                gof[x]=gof[p]
            P[P.index(p)]=x; C[C.index(x)]=p; sw+=1; progressed=True
            break
        if not progressed:
            dp=[p for p in P if T(p) in deficit]
            dset=set().union(*[DS[p] for p in dp])
            for y in P:
                if T(y) in deficit or not (DS[y]&dset): continue
                qq=par.get(y)
                xs=[x for x in C if T(x) in surplus and (qq is None or DS[x]&DS[qq])]
                if not xs: continue
                x=xs[0]
                if qq is not None:
                    allkids[qq][allkids[qq].index(y)]=x; par[x]=qq; del par[y]; gof[x]=gof[qq]
                else: gof[x]=gof[y]
                P[P.index(y)]=x; C[C.index(x)]=y; sw+=1; progressed=True; break
        assert progressed,('stuck',[sorted(t) for t in deficit],[sorted(t) for t in surplus][:20])
    kids=assign(P,C,quota,gof,t)
    rs=sum(1 for p in P for c in kids[p] if R[c]&R[p])
    print(f'{t+1}<-{t} 차수 맞바꿈',sw,'어근 공유',round(rs/(2*len(P)),3))
    nxt=[]
    for p,ks in kids.items():
        allkids[p]=ks
        for c in ks: gof[c]=gof[p]; tiers[c]=t; par[c]=p; nxt.append(c)
    for p in P: tiers[p]=t+1
    P=nxt
assert not L and len(tiers)==9990,len(tiers)
json.dump({'tiers':tiers,'kids':allkids,'g':{i:list(v) for i,v in gof.items()},'boss':BOSS},open(OUT,'w'))
# coverage checks
cov=collections.defaultdict(set)
for i,g in gof.items():
    for a in DS[i]: cov[(g[0],g[1],tiers[i])].add(a)
for t in (1,2,3,4):
    miss=sum(20-len(cov[(u,s,t)]) for u,s in groups)
    print('tier',t,'빈칸(유닛·부위·속성)',miss)
ur=sum(1 for i,g in gof.items() if g[0] in U[i]); print('유닛 어근 일치',ur,len(gof),round(ur/len(gof),3))
