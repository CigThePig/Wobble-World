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
    assert result.returncode==0 and 'SCRIPT ERROR:' not in result.stdout and '\nERROR:' not in result.stdout, log
    return result.stdout

def analyze(path):
    groups=collections.defaultdict(list)
    for line in Path(path).read_text().splitlines():
        r=json.loads(line)
        assert all(math.isfinite(r[k]) for k in ['x','y','vx','vy','box_x','seesaw_angle'])
        groups[r['scenario']].append(r)
    assert len(groups)==14, list(groups)
    walk=groups['walk-stop-reverse']
    assert max(r['x'] for r in walk)-walk[0]['x']>150
    assert min(r['vx'] for r in walk)<-200
    assert abs(walk[-1]['vx'])<1 and walk[-1]['owners']==0
    short,long=groups['short-jump'],groups['long-jump']
    assert min(r['y'] for r in short)-min(r['y'] for r in long)>35
    assert max(r['jumps'] for r in long)==1
    assert any(r['held'] and r['axis']>.9 and r['owners']==2 for r in long)
    roll=groups['walk-roll']
    assert any(r['roll'] and r['axis']>.9 for r in roll)
    assert abs(roll[110]['vx'])>60 and not roll[-1]['roll'] and abs(roll[-1]['vx'])<1
    downhill=groups['downhill']
    assert max(r['vx'] for r in downhill)>350
    assert max(r['bounces'] for r in groups['spring'])>=1
    assert max(r['pushes'] for r in groups['box'])>0
    assert max(r['box_x'] for r in groups['box'])>1980
    assert any(r['roll'] and not r['grounded'] for r in groups['mode-motion'])
    assert groups['mode-motion'][-1]['roll']==False
    assert all(r['axis']==0 and r['owners']==0 and not r['held'] for r in groups['cancel-focus'][46:])
    assert max(r['jumps'] for r in groups['coyote'])==1
    assert max(r['jumps'] for r in groups['buffer'])==1
    assert max(r['rings'] for r in groups['bell'])>=1
    assert max(abs(r['seesaw_angle']) for r in groups['seesaw'])>.05
    # The repeated flat-ground route tolerates only subpixel engine contact settling.
    repeat=groups['walk-repeat']
    a={r['tick']:r for r in walk}; b={r['tick']:r for r in repeat}
    assert max(abs(a[t]['x']-b[t]['x']) for t in a.keys() & b.keys())<.1
    return {n:{'frames':len(rs),'jumps':max(r['jumps'] for r in rs),'bounces':max(r['bounces'] for r in rs),'max_speed':max(abs(r['vx']) for r in rs)} for n,rs in groups.items()}

if __name__=='__main__':
    run([GODOT,'--headless','--path','.','--editor','--import','--quit'],'build/import.log')
    result=run([GODOT,'--headless','--path','.','--resolution','1280x720','--fixed-fps','60','--','--replay','--out=build/checks'],'build/checks/engine.log')
    assert 'WOBBLE_REPLAY_COMPLETE' in result
    report=analyze('build/checks/trace.jsonl')
    result=run([GODOT,'--headless','--path','.','--script','res://game/input_checks.gd'],'build/checks/input.log')
    assert 'INPUT_CHECKS_PASSED' in result
    Path('build/checks/results.json').write_text(json.dumps(report,indent=2))
    print('ENGINE CHECKS PASSED')
