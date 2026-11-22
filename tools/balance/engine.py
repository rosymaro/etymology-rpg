import random,math
from full import *
def battle(my,en,magic=None,quizok=True,P=2,bossab=None):
  """my,en: lists of U. returns kills"""
  T={'A':{'team':my,'perm_atk':0,'perm_def':0,'next_hp':0,'next_block':0,'shield':0,'firstX':0,'share':False,'regen':0,'wall':0,'mana_twice':0,'cap':False,'leg':False},
     'B':{'team':en,'perm_atk':0,'perm_def':0,'next_hp':0,'next_block':0,'shield':0,'firstX':0,'share':False,'regen':0,'wall':0,'mana_twice':0,'cap':False,'leg':False}}
  pending_dmg={'A':0,'B':0}  # damage to next entering unit of that side
  # magic
  sub_pool=False; prae=False; dmods={}
  def cast(m):
    nonlocal sub_pool,prae
    if m in ('com','re','ad','sub','prae','inter') and not quizok: return
    half=lambda u,dm: dm//2 if random.random()<0.03 else dm
    if m=='de': en[0].pre_dmg=getattr(en[0],'pre_dmg',0)+half(en[0],2*P); en[0].atkmod=-1
    elif m=='un':
      for e in en: e.pre_dmg=getattr(e,'pre_dmg',0)+math.ceil(P/2); e.first_null=True
    elif m=='inneg': en[0].pre_dmg=getattr(en[0],'pre_dmg',0)+P; en[0].perm_seal=True
    elif m=='ob': en[0].pre_dmg=getattr(en[0],'pre_dmg',0)+P; T['A']['ob']=True
    elif m=='in': my[0].ph=0.75
    elif m=='dis': en[0].bA=0
    elif m=='com': T['A']['share']=True
    elif m=='re': T['A']['regen']=P
    elif m=='ad': T['A']['shield']=P
    elif m=='sub': sub_pool=True
    elif m=='prae': prae=True
    elif m=='inter': T['A']['wall']=2; T['A']['wallv']=math.ceil(P/2)
    elif m=='pro':
      best=max(range(len(my)),key=lambda i:my[i].bA); u=my.pop(best); my.insert(0,u); u.bA+=best*math.ceil(P/2)
    elif m=='ex':
      if len(my)>1: u=my.pop(0); my.append(u); u.bH+=(len(my)-1)*math.ceil(P/2)
      if len(en)>1: e=en.pop(0); en.append(e); e.bH+=(len(en)-1)*math.ceil(P/2)
  if magic: cast(magic)
  if magic=='fac2': pass
  if sub_pool and len(my)>1:
    for u in my[1:]: g=u.bH//2; my[0].bH+=g; u.bH-=g
  sub_pool=False
  i=j=0;a=b=None;kills=0;clash=0
  def enter(u,side):
    u.throw(); A,D,H=u.calc(); u.A=A+T[side]['perm_atk']+getattr(u,'atkmod',0); u.D=D+T[side]['perm_def']+(1 if T[side]['cap'] else 0); u.hp=H+T[side]['next_hp']-getattr(u,'pre_dmg',0)-pending_dmg[side]
    T[side]['next_hp']=0; pending_dmg[side]=0; u.pre_dmg=0
    if side=='A' and T['A']['shield']: u.hp+=T['A']['shield']
    u.block=T[side]['next_block']; T[side]['next_block']=0
  while i<len(my) and j<len(en):
    newa=a is None; newb=b is None
    if newa: a=my[i]; enter(a,'A')
    if newb: b=en[j]; enter(b,'B')
    if sub_pool and i>0: break
    # boss on-enter abilities
    clash+=1
    for u,o,side,oside in ((a,b,'A','B'),(b,a,'B','A')):
      u.skip=0;u.dbl=0;u.red=0;u.refl=0;u.first=False;u.halfrefl=False;u.turn=False;u.plic=False;u.dodge=0;u.cess=False;u.lig=False;u.spill=False
    if bossab and b.boss:
      ab=b.boss
      if ab=='defect' and a.flips: a.flips[0]=False
      if ab=='dictate': a.flips[:2]=[False]*min(2,len(a.flips))
      if ab=='vortex': a.flips=[not x for x in a.flips]; b.flips=[not x for x in b.flips]
      if ab=='devil' and any(a.flips): a.flips[a.flips.index(True)]=False
      if ab in('defect','dictate','vortex','devil'):
        A,D,H=a.calc(); a.A=A+T['A']['perm_atk']
      if ab=='storm':
        for u in my[i+1:]: u.bH-=2
    # skills (both sides) evaluated at clash start
    for u,o,side,oside in ((a,b,'A','B'),(b,a,'B','A')):
      if getattr(u,'first_null',False): u.first_null=False; continue
      if not u.skill_ok(): continue
      sk=u.skill; R=T[side]
      if sk=='fac' and side=='A' and magic: cast(magic)
      elif sk=='struct': u.red+=2
      elif sk=='form': u.A+=2
      elif sk=='par': pass
      elif sk=='nat': R['revive']=True
      elif sk=='ple': u.hp+=3
      elif sk=='cept': u.A+=2
      elif sk=='tain': o.skip+=1
      elif sk in('pris','hib','clos'): o.sealed=True; o.perm_seal = o.perm_seal or sk=='hib'
      elif sk=='spect': u.A+=2
      elif sk=='vis':
        if not all(u.flips): u.flips[u.flips.index(False)]=random.random()<0.5; A,D,H=u.calc(); u.A=max(u.A,A)
      elif sk=='sens': u.dodge+=1
      elif sk=='lect': pass
      elif sk=='cert': o.D=max(0,o.D-2)
      elif sk=='not': u.A+=2 if random.random()<0.5 else 0
      elif sk=='put': u.put=True
      elif sk=='equ': m=(u.hp+o.hp)//2; u.hp=m; o.hp=m
      elif sk=='dict': o.flips=[False]*len(o.flips); A,D,H=o.calc(); o.A=A
      elif sk=='sign': o.D-=1
      elif sk=='jus': u.halfrefl=True
      elif sk=='cess': u.cess=True
      elif sk in('ven','it'): o.hp-=2
      elif sk=='grad': R['perm_atk']+=0  # applied on win
      elif sk=='curr': u.dbl=1
      elif sk=='sequ': u.A+=3 if (i>0 if side=='A' else j>0) else 0
      elif sk=='loc': R['next_hp']+=3
      elif sk=='miss': u.miss=True
      elif sk=='dit': u.dit=True
      elif sk=='pend': u.hp-=3; u.A+=6
      elif sk=='pay': u.skip+=1; o.skip+=1; u.hp+=4
      elif sk=='grat':
        for x in R['team'][(i if side=='A' else j)+1:]: x.bH+=2
      elif sk=='duc': R['perm_atk']+=1; u.A+=1
      elif sk=='rect': u.A+=1
      elif sk=='act': u.A+=2
      elif sk=='cur': R['next_block']=1
      elif sk=='cap': R['cap']=True; u.D+=1
      elif sk=='tract':
        if any(o.flips): o.flips[o.flips.index(True)]=False; A,D,H=o.calc(); o.A=A
      elif sk=='press': o.A-=2
      elif sk=='ject':
        t=R['team'] if False else (T[oside]['team'][(j if side=='A' else i)+1:])
        if t: random.choice(t).bH-=3
      elif sk=='tend': u.spill=True
      elif sk=='pet': u.A+=1
      elif sk=='vers': o.A,o.D=o.D,o.A
      elif sk=='turn': u.turn=True
      elif sk=='plic': u.plic=True
      elif sk=='mot': u.first=True
      elif sk=='sta': u.used_survive=False; u.can_survive=True
      elif sk=='pos': pending_dmg[oside]+=3
      elif sk=='sid': u.skip+=1; u.hp+=5
      elif sk=='lig': u.lig=True
      elif sk=='strict': o.sealed=True
      elif sk=='val': u.A+=3
      elif sk=='fort': u.D+=2
      elif sk=='rupt': o.D=0
      elif sk=='cis': o.hp=max(1,o.hp//2)
      elif sk=='cid':
        if o.boss: o.hp=max(1,o.hp//2)
        else: o.hp=0
      elif sk=='fin': u.fin=True
      elif sk=='part':
        for x in T[oside]['team'][(j if side=='A' else i)+1:]: x.bH-=max(1,u.A//2)//max(1,len(T[oside]['team']))
    if bossab and b.boss=='tyrant' and newb: b.A+=j
    if bossab and b.boss=='pirate' and newb:
      T['A']['shield']=0; T['A']['regen']=0; T['A']['share']=False; T['A']['wall']=0; prae=False
    if bossab and b.boss=='titan' and newb: b.hp=int(b.hp*1.5)
    if bossab and b.boss=='dragon' and newb: b.hp=int(b.hp*1.5)
    if bossab and b.boss=='guardian' and newb: b.block=1
    if bossab and b.boss=='wizard' and newb: a.hp-=P
    # rounds
    rnd=0
    if T['A']['wall']>0: a.red+=T['A']['wallv']; T['A']['wall']-=1
    while a.hp>0 and b.hp>0 and rnd<200:
      rnd+=1
      def dmg(x,y):
        if x.skip>=rnd: return 0
        d=max(1,x.A-y.D-y.red)
        if getattr(x,'put',False) and y.hp*2<=y.bH: d+=3
        if bossab and y.boss=='specter' and rnd==1: return 0
        return d*(2 if (x.dbl and rnd==1) else 1)
      da=dmg(a,b); db=dmg(b,a)
      if prae or a.first: 
        # a strikes first
        b.hp-=apply(b,da) if False else 0
      for (x,y,d) in ((b,a,db),(a,b,da)):
        if y.dodge and rnd==1: d=0
        if y.block>0 and d>0: y.block-=1; d=0
        if y.turn and d>0: y.turn=False; d=0
        if y is a and T['A']['share'] and d>0 and i+1<len(my): s=d//3; d-=s; my[i+1].bH-=s//2
        if y.lig and d>0 and ((y is a and i+1<len(my)) or (y is b and j+1<len(en))): d-=d//2
        y.incoming=d
      first_a = prae or a.first
      if first_a:
        b.hp-=b.incoming
        if b.hp>0: a.hp-=a.incoming
      elif b.first:
        a.hp-=a.incoming
        if a.hp>0: b.hp-=b.incoming
      else:
        a.hp-=a.incoming; b.hp-=b.incoming
      for x,y in ((a,b),(b,a)):
        if x.halfrefl: y.hp-=x.incoming//2
        if x.plic: x.A+=x.incoming
        if getattr(x,'fin',False) and 0<y.hp<=3: y.hp=0
        if x.cess and 0<x.hp<=x.bH//2: x.hp+=4; x.cess=False
        if getattr(x,'can_survive',False) and x.hp<=0: x.hp=1; x.can_survive=False
      if bossab and b.boss=='dragon':
        for u in my[i+1:]: u.bH-=1
    if b.hp<=0:
      j+=1; kills+=1
      if bossab and a.hp>0 and getattr(b,'boss',None): pass
      if getattr(a,'miss',False): pending_dmg['B']+=2
      if a.skill=='grad' and a.skill_ok(): T['A']['perm_atk']+=1
      if T['A']['regen']: a.hp+=T['A']['regen']
      if a.spill if hasattr(a,'spill') else False: pending_dmg['B']+=max(0,a.A-1)
      b=None
    if a.hp<=0:
      if bossab and en[min(j,len(en)-1)].boss=='predator' and b is not None: b.hp+=3
      if bossab and en[min(j,len(en)-1)].boss=='tyrant' and b is not None: pass
      if T['A'].get('revive') and a.hp<=0:
        T['A']['revive']=False; my.append(a); a.hp=None
      i+=1; a=None
  return kills
