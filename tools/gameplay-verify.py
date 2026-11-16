"""Real Godot Movie Maker -> FFmpeg MP4, labelled stills and telemetry."""
from pathlib import Path
import os, sys, json, subprocess, shutil
try:
    import imageio_ffmpeg
    FALLBACK=imageio_ffmpeg.get_ffmpeg_exe()
except ImportError:
    FALLBACK=None
FFMPEG=shutil.which("ffmpeg") or FALLBACK
from PIL import Image, ImageDraw, ImageStat, ImageChops
from verify import run, analyze, analyze_full, GODOT
out=Path('build/evidence').resolve();out.mkdir(parents=True,exist_ok=True)
(out/'full').mkdir(exist_ok=True)
sha=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
dirty=bool(subprocess.check_output(['git','status','--porcelain'],text=True).strip())
Path('game/build-source.txt').write_text(sha+(' dirty' if dirty else ''))
def record(mode,folder,name):
    run([GODOT,'--path','.','--resolution','1280x720','--audio-driver','Dummy','--fixed-fps','60','--write-movie',str(folder/(name+'.avi')),'--',mode,'--out='+str(folder)],folder/'engine.log',900)
    subprocess.run([FFMPEG,'-v','error','-y','-i',str(folder/(name+'.avi')),'-c:v','libx264','-crf','24','-pix_fmt','yuv420p','-an',str(folder/(name+'.mp4'))],check=True,timeout=300)
    (folder/(name+'.avi')).unlink()
def sheet(frames,path,columns=4):
    rows=(len(frames)+columns-1)//columns
    image=Image.new('RGB',(columns*320,rows*205),'#2a1a3e');draw=ImageDraw.Draw(image)
    for i,p in enumerate(frames):
        im=Image.open(p).convert('RGB');im.thumbnail((320,180))
        image.paste(im,((i%columns)*320,(i//columns)*205));draw.text(((i%columns)*320+5,(i//columns)*205+183),p.stem,fill='white')
    image.save(path,quality=88)
record('--replay',out,'gameplay')
report=analyze(out/'trace.jsonl')
frames=sorted(out.glob('*.png'))
assert len(frames)>=45, len(frames)
for p in frames:
    im=Image.open(p).convert('RGB')
    assert im.size==(1280,720) and sum(ImageStat.Stat(im).stddev)>40, p
assert sum(ImageStat.Stat(ImageChops.difference(Image.open(frames[0]).convert('RGB'),Image.open(frames[1]).convert('RGB'))).mean)>1
sheet(frames,out/'contact-sheet.jpg')
record('--replay=full',out/'full','full-run')
full=analyze_full(out/'full'/'trace.jsonl')
full_frames=sorted((out/'full').glob('*.png'))
assert len(full_frames)>=8
sheet(full_frames,out/'full-run-sheet.jpg')
(out/'report.json').write_text(json.dumps({'source':sha,'dirty':dirty,'engine':'4.6.1','scenarios':report,'full_run':full,'rendered':True,'physical_device':False},indent=2))
print('RENDERED EVIDENCE PASSED',sha)
