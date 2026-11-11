import sys,json,numpy as np; sys.path.insert(0,'/home/claude/grade'); sys.path.insert(0,'/home/claude/grade/pc')
from port import render, OLD
from lib import lab
from scipy.optimize import least_squares
rgb=np.array(json.load(open('/home/claude/grade/chart_rgb.json')))
d=json.load(open('/home/claude/grade/cal2_looks.json'))
cam={'A':np.load('/home/claude/grade/a_lab.npy'),'B':np.load('/home/claude/grade/b_lab.npy'),'C':np.load('/home/claude/grade/c_lab.npy'),'D':np.load('/home/claude/grade/d_lab.npy')}
def labs(o): return np.array([lab(c*255) for c in o])
def tolook(e):
    z=[0]*12
    return {'hue':e.get('hue',z),'light':e.get('light',z),'sat':e.get('sat',z),'wb':(e.get('ab',0),e.get('gm',0)) if e.get('wb') else None,'split':tuple(e['split']) if 'split' in e else None}
TESTS=[]
for k in 'ABCD':
    for j,e in enumerate(d[k]):
        if j==0 or any(e.get(t) for t in ('contrast','hi','sh','mid')): continue
        TESTS.append((k+e['name'],tolook(e),cam[k][j+1]-cam[k][1]))
NULL=labs(render(rgb,tolook({})))
KEYS=[('gp',12),('gn',12),('hp',12),('hn',12),('lscale',1),('wab',3),('wgm',3),('split',1)]
def unpack(v):
    p={};i=0
    for k,n in KEYS: p[k]=v[i:i+n] if n>1 else v[i]; i+=n
    return p
def pack(p): return np.concatenate([np.atleast_1d(np.asarray(p[k],float)) for k,_ in KEYS])
v0=pack(OLD); scale=np.abs(v0)+np.concatenate([np.full(48,50.),[1.],[0.01]*6,[0.5]])
def resid(v,tests=TESTS,reg=True):
    p=unpack(v); r=[]
    for n,lk,dc in tests:
        dp=labs(render(rgb,lk,p))-NULL; r.append((dp-dc).ravel())
    r=np.concatenate(r)
    if reg:
        w=np.full(len(v),0.5); w[[3,15,27,39]]=1e4   # Red: no chart patch, keep the old values
        r=np.concatenate([r,w*(v-v0)/scale])
    return r
if __name__=='__main__':
    lo=np.concatenate([np.zeros(48),[0.2],[-0.1]*6,[0.3]]); hi=np.concatenate([np.full(24,3000.),np.full(24,40.),[20],[0.1]*6,[3]])
    r0=resid(v0,reg=False); print('before: mean |dLab| per patch %.2f'%np.abs(r0).reshape(-1,3).__abs__().__pow__(2).sum(1).__pow__(.5).mean())
    sol=least_squares(resid,v0,bounds=(lo,hi),x_scale=scale,max_nfev=400)
    r1=resid(sol.x,reg=False); print('after : mean |dLab| per patch %.2f'%(np.sqrt((r1.reshape(-1,3)**2).sum(1)).mean()))
    p=unpack(sol.x); json.dump({k:(np.round(p[k],4).tolist() if np.ndim(p[k]) else round(float(p[k]),4)) for k,_ in KEYS},open('/home/claude/grade/pc/fit.json','w'),indent=1)
    for k,_ in KEYS: print(k,np.round(p[k],3))
