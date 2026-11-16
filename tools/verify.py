"""Small engine suite. Assertion failures and Godot errors are fatal; retain logs."""
from pathlib import Path
import subprocess, os, json, collections, math
ROOT=Path(__file__).resolve().parents[1]
os.chdir(ROOT)
GODOT=os.environ.get('GODOT','godot')
def run(args, log, timeout=240):
    result=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=timeout)
    Path(log).parent.mkdir(parents=True,exist_ok=True)
    Path(log).write_text(result.stdout)
    print(result.stdout[-5000:])
    assert result.returncode==0 and 'SCRIPT ERROR:' not in result.stdout and 'ERROR:' not in result.stdout, log
    return result.stdout

def load(path):
    groups=collections.defaultdict(list)
    for line in Path(path).read_text().splitlines():
        r=json.loads(line)
        assert all(math.isfinite(r[k]) for k in ['x','y','vx','vy','box_x','day'])
        groups[r['scenario']].append(r)
    return groups

def speed(r): return math.hypot(r['vx'],r['vy'])

def summary(groups):
    return {n:{'frames':len(rs),'jumps':rs[-1]['jumps'],'bounces':rs[-1]['bounces'],'seeds':rs[-1]['seeds'],'max_speed':round(max(speed(r) for r in rs))} for n,rs in groups.items()}

def analyze(path):
    groups=load(path)
    assert len(groups)==17, list(groups)
    walk=groups['walk-stop-reverse']
    assert max(r['x'] for r in walk)-walk[0]['x']>150
    assert min(r['vx'] for r in walk)<-200
    assert abs(walk[-1]['vx'])<1 and walk[-1]['owners']==0
    short,long=groups['short-jump'],groups['long-jump']
    assert min(r['y'] for r in short)-min(r['y'] for r in long)>35
    assert long[-1]['jumps']==1
    assert any(r['held'] and r['axis']>.9 and r['owners']==2 for r in long)
    assert groups['coyote'][-1]['jumps']==1
    assert groups['buffer'][-1]['jumps']==1
    focus=groups['cancel-focus']
    assert any(r['paused'] for r in focus)
    assert all(r['axis']==0 and r['owners']==0 and not r['held'] for r in focus if r['tick']>46)
    roll=groups['walk-roll']
    assert any(r['roll'] and r['axis']>.9 for r in roll)
    coast=[r for r in roll if r['tick']==140][0]
    assert coast['roll'] and abs(coast['vx'])>60, coast
    assert not roll[-1]['roll'] and abs(roll[-1]['vx'])<1
    # The repeated flat-ground route tolerates only subpixel engine contact settling.
    a={r['tick']:r for r in walk}; b={r['tick']:r for r in groups['walk-repeat']}
    assert max(abs(a[t]['x']-b[t]['x']) for t in a.keys() & b.keys())<.1
    ledge=groups['boing-ledge']
    assert ledge[-1]['bounces']>=1 and max(r['x'] for r in ledge)>1290 and any(r['grounded'] and r['y']<420 and r['x']>1270 for r in ledge)
    leap=groups['hill-leap']
    assert max(speed(r) for r in leap)>800 and leap[-1]['splashes']==0 and max(r['x'] for r in leap)>3600
    assert any(not r['grounded'] and 3220<r['x']<3500 and r['y']<900 for r in leap)
    fall=groups['pond-fall']
    assert fall[-1]['splashes']==1 and fall[-1]['grounded'] and not 3180<fall[-1]['x']<3540
    garden=groups['garden']
    assert garden[-1]['bounces']>=3 and garden[-1]['x']>5000 and garden[-1]['y']<380
    kick=groups['kick-crate']
    assert kick[-1]['kicks']>=1 and kick[70]['box_x']-kick[0]['box_x']>150
    assert not kick[0]['gate'] and kick[-1]['gate'] and kick[-1]['x']>6050
    slam=groups['slam-floor']
    assert slam[-1]['pounds']>=1 and slam[-1]['crumbled'] and not slam[0]['crumbled']
    assert max(r['y'] for r in slam)>560 and slam[-1]['snoozles']==slam[0]['snoozles']+1
    assert slam[-1]['y']<380 and slam[-1]['x']>6600
    boing=groups['big-boing']
    assert min(r['y'] for r in boing)<0 and boing[-1]['x']>7000 and boing[-1]['y']<60
    descent=groups['descent']
    assert descent[-1]['boosts']>=1 and max(speed(r) for r in descent)>1000 and max(r['x'] for r in descent)>9800
    assert any(not r['grounded'] and 9350<r['x']<9700 for r in descent)
    bell=groups['bell']
    assert not bell[0]['awake'] and bell[-1]['rings']>=1 and bell[-1]['awake'] and bell[-1]['day']==1 and bell[-1]['results']
    return summary(groups)

def analyze_full(path):
    run=load(path)['full-run']
    end=run[-1]
    assert end['results'] and end['awake'] and end['gate'] and end['crumbled'], end
    assert end['splashes']==0 and end['seeds']>=80 and end['snoozles']>=1 and len(run)<4500, (end,len(run))
    return {'ticks':len(run),'seeds':end['seeds'],'snoozles':end['snoozles']}

if __name__=='__main__':
    sha=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
    dirty=bool(subprocess.check_output(['git','status','--porcelain'],text=True).strip())
    Path('game/build-source.txt').write_text(sha+(' dirty' if dirty else ''))
    run([GODOT,'--headless','--path','.','--editor','--import','--quit'],'build/import.log')
    result=run([GODOT,'--headless','--path','.','--resolution','1280x720','--fixed-fps','60','--','--replay','--out=build/checks'],'build/checks/engine.log')
    assert 'WOBBLE_REPLAY_COMPLETE' in result
    report=analyze('build/checks/trace.jsonl')
    result=run([GODOT,'--headless','--path','.','--resolution','1280x720','--fixed-fps','60','--','--replay=full','--out=build/checks/full'],'build/checks/full/engine.log')
    assert 'WOBBLE_REPLAY_COMPLETE' in result
    full=analyze_full('build/checks/full/trace.jsonl')
    result=run([GODOT,'--headless','--path','.','--script','res://game/input_checks.gd'],'build/checks/input.log')
    assert 'INPUT_CHECKS_PASSED' in result
    Path('build/checks/results.json').write_text(json.dumps({'source':sha,'dirty':dirty,'scenarios':report,'full_run':full},indent=2))
    print('ENGINE CHECKS PASSED')
