import sys,json,numpy as np; sys.path.insert(0,'/home/claude/grade/pc'); sys.path.insert(0,'/home/claude/grade')
import fit as F1
from fit import *
from films_data import rows
from scipy.optimize import least_squares
def run(train,test,out=None):
    data=TESTS+rows(train)
    lo=np.concatenate([np.zeros(48),[0.2],[-0.1]*6,[0.3]]); hi=np.concatenate([np.full(24,3000.),np.full(24,40.),[20],[0.1]*6,[3]])
    sol=least_squares(lambda v: resid(v,data),v0,bounds=(lo,hi),x_scale=scale,max_nfev=300)
    p=unpack(sol.x)
    def err(par,rs):
        return np.mean([np.linalg.norm((labs(render(rgb,lk,par))-NULL)-dc,axis=1)[:18].mean() for n,lk,dc in rs])
    tr=rows(test)
    print(f'train {train} -> held-out {test}: old {err(OLD,tr):.2f}  single-slider fit {err(P1,tr):.2f}  joint fit {err(p,tr):.2f}',flush=True)
    if out: json.dump({k:(np.round(p[k],4).tolist() if np.ndim(p[k]) else round(float(p[k]),4)) for k,_ in KEYS},open(out,'w'),indent=1)
    return p
P1={k:(np.array(v) if isinstance(v,list) else v) for k,v in json.load(open('/home/claude/grade/pc/fit.json')).items()}
if __name__=='__main__':
    run(['rel','v3','v5'],['v6'])
    run(['rel','v3','v6'],['v5'])
    run(['rel','v5','v6'],['v3'])
    run(['v3','v5','v6'],['rel'])
    run(['rel','v3','v5','v6'],['v6'],'/home/claude/grade/pc/fit2.json')
