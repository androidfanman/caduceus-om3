import json,numpy as np,sys
sys.path.insert(0,'/home/claude/grade'); sys.path.insert(0,'/home/claude/grade/pc')
from lib import lab,lch
import model3 as M3
TL=json.load(open('/home/claude/grade/pc/tonelut.json'))
D=json.load(open('/home/claude/grade/patches.json'))
def lab_of_lch(P):
    h=np.radians(P[:,2]); return np.stack([P[:,0],P[:,1]*np.cos(h),P[:,1]*np.sin(h)],1)
def corr(L): return lab_of_lch(lch(L)-M3.vig)
SH={'rel':(np.array(D['DEFAULT']['lab']),{n:np.array(D[n]['lab']) for n in M3.order})}
for t,f in (('v3','v3_lab.npy'),('v5','v5_lab.npy'),('v6','v6_lab.npy')):
    P=np.load('/home/claude/grade/'+f); SH[t]=(P[0],{n:P[j+1] for j,n in enumerate(M3.order)})
def rows(tags):
    out=[]
    for t in tags:
        F={f['name']:f for f in json.load(open(f'/home/claude/grade/pc/films_{t}.json'))['films']}
        C,L=SH[t]
        for n,f in F.items():
            sp=f.get('split'); lk={'hue':f['hue'],'light':f['light'],'sat':f['sat'],'wb':(f['wb']['a_b'],f['wb']['g_m']) if f['wb'] else None,
                'split':(sp['sh_color'],sp['sh'],sp['hl_color'],sp['hl']) if sp else None,'tone':TL[f'{t}:{n}']}
            out.append((f'{t}:{n}',lk,corr(L[n])-C))
    return out
