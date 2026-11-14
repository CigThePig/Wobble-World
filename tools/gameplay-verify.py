"""Real Godot Movie Maker -> FFmpeg MP4, labelled stills and telemetry."""
from pathlib import Path
import os, sys, json, subprocess
from PIL import Image, ImageDraw, ImageStat, ImageChops
from verify import run, analyze, GODOT
out=Path('build/evidence').resolve();out.mkdir(parents=True,exist_ok=True)
sha=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
dirty=bool(subprocess.check_output(['git','status','--porcelain'],text=True).strip())
Path('game/build-source.txt').write_text(sha+(' dirty' if dirty else ''))
run([GODOT,'--path','.','--resolution','1280x720','--audio-driver','Dummy','--fixed-fps','60','--write-movie',str(out/'gameplay.avi'),'--','--replay','--out='+str(out)],out/'engine.log',600)
report=analyze(out/'trace.jsonl')
subprocess.run(['ffmpeg','-v','error','-y','-i',str(out/'gameplay.avi'),'-c:v','libx264','-crf','24','-pix_fmt','yuv420p','-an',str(out/'gameplay.mp4')],check=True,timeout=120)
(out/'gameplay.avi').unlink()
frames=sorted(out.glob('*.png'))
assert len(frames)>=70
for p in frames:
    im=Image.open(p).convert('RGB')
    assert im.size==(1280,720) and sum(ImageStat.Stat(im).stddev)>40, p
assert sum(ImageStat.Stat(ImageChops.difference(Image.open(frames[0]),Image.open(frames[4]))).mean)>1
sheet=Image.new('RGB',(1280,14*205),'#285855');draw=ImageDraw.Draw(sheet)
for row in range(14):
    chosen=sorted(out.glob(f'{row:02d}-*.png'))
    for col,index in enumerate([0,2,3,5]):
        p=chosen[index];im=Image.open(p);im.thumbnail((320,180));sheet.paste(im,(col*320,row*205));draw.text((col*320+5,row*205+183),p.stem,fill='white')
sheet.save(out/'contact-sheet.jpg')
(out/'report.json').write_text(json.dumps({'source':sha,'dirty':dirty,'engine':'4.6.1','scenarios':report,'rendered':True,'physical_device':False},indent=2))
print('RENDERED EVIDENCE PASSED',sha)
