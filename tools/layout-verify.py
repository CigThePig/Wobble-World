from verify import run, GODOT
from PIL import Image
from pathlib import Path
for size in ['1280x800','1280x720','1920x864','2340x1080','1024x768']:
    text=run([GODOT,'--path','.','--resolution',size,'--audio-driver','Dummy','--','--layout-check'],f'build/layout/{size}.log',60)
    assert 'LAYOUT_PASSED' in text
    im=Image.open(f'build/layout/{size}.png')
    assert im.size==tuple(map(int,size.split('x')))
print('ALL LAYOUTS PASSED')
