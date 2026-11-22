import random,math
import json as _json, os as _os
UNIT=_json.load(open(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)),'../../data/balance/unit.json'),encoding='utf-8'))
def set_unit(d):
  global ATK,DEF,HP,UNIT
  UNIT=d; ATK=d['atk']; DEF=d['def']; HP=d['hp']
set_unit(UNIT)
ROLES={1:('M','M','M','skill'),2:('M','L','M','atk'),3:('L','L','L','skill'),4:('L','M','M','stable'),5:('L','M','L','skill'),6:('M','L','L','atk'),7:('M','M','H','hp'),8:('M','M','M','skill'),9:('H','L','L','atk'),10:('M','M','M','tails'),11:('L','H','H','stable'),12:('H','M','M','swing')}
FAM={1:'fac struct form par nat ple',2:'cept tain pris hib quest',3:'spect vis sens',4:'lect cert not put equ',5:'dict script sign leg jus',6:'cess ven it grad curr sequ loc',7:'fer port miss dit pend pay grat',8:'duc rect act cur cap',9:'tract press ject tend pet',10:'vers turn plic mot',11:'sta pos sid clos lig strict val fort',12:'rupt cis cid fin part'}
FAM={k:v.split() for k,v in FAM.items()}
TIER={}
import skills
for n,t,_ in skills.S: TIER[n]=t
def stage(L): return eval(UNIT['coins'],{},{'L':L})
def kof(L): return eval(UNIT['coin_value'],{},{'L':L})
class U:
  def __init__(s,role,L,coins=None,k=None,skill=None,side='A',boss=None,pheads=0.5):
    s.role=role;s.L=L;s.coins=coins or stage(L);s.k=k or kof(L);s.skill=skill or random.choice(FAM[role]);s.side=side;s.boss=boss;s.ph=pheads
    a,d,h,c=ROLES[role]
    s.bA=ATK[a][0]+int(ATK[a][1]*(L-1)); s.bD=DEF[d][0]+int(DEF[d][1]*(L-1)); s.bH=HP[h][0]+int(HP[h][1]*(L-1)); s.ct=c
    s.hp=None; s.flips=None; s.used_survive=False; s.sealed=False; s.perm_seal=False
  def throw(s): s.flips=[random.random()<s.ph for _ in range(s.coins)]
  def C(s,n): return sum(s.flips[:n])
  def calc(s):
    k=s.k;c=s.ct;n=s.coins;A=s.bA;H=s.bH
    if c=='atk': A+=k*s.C(n)
    elif c=='hp': H+=2*k*s.C(n)
    elif c=='skill': A+=k*s.C(max(1,n//2))
    elif c=='stable': A+=k*s.C(1)
    elif c=='tails': A+=k*(n-s.C(n))
    elif c=='swing': A+=2*k*s.C(n); H-=k*s.C(1)
    return A,s.bD,max(1,H)
  def skill_ok(s):
    if s.sealed or s.perm_seal: return False
    t=TIER[s.skill]; n=s.coins; h=s.C(n)
    return h>=1 if t=='쉬움' else (h>=math.ceil(n/2) if t=='보통' else h==n)
