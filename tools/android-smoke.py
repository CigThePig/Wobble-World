"""Android OS-touch smoke. Same source, x86_64 ABI; no physical S25 claim."""
import subprocess, os, time, json, re, sys
from pathlib import Path
from PIL import Image
out=Path('build/android-runtime');out.mkdir(parents=True,exist_ok=True)
sdk=Path(os.environ['ANDROID_HOME']); adb_path=str(sdk/'platform-tools/adb')
package='com.cigthepig.wobbleworld.dev'
def adb(*args,raw=False):
    return subprocess.check_output([adb_path,*args],timeout=90 if args[0]=='install' else 25,**({} if raw else {'text':True}))
def logs():return adb('logcat','-d')
def wait_for(fn,seconds=90):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        value=fn()
        if value:return value
        time.sleep(1)
    raise AssertionError('Timed out waiting for Android state')
def capture(name):
    path=out/name;path.write_bytes(adb('exec-out','screencap','-p',raw=True))
    im=Image.open(path).convert('RGB'); pixels=list(im.getdata())
    orange=sum(r>220 and 105<g<195 and b<130 for r,g,b in pixels)
    green=sum(g>r*1.05 and g>b*1.03 for r,g,b in pixels)
    assert orange>100 and green>1000,('Bloop/world missing',orange,green)
    return {'orange_pixels':orange,'green_pixels':green,'size':im.size}
def states():
    return [dict(zip(['x','y','jumps','bounces','roll','rings'],m)) for m in re.findall(r'WOBBLE_STATE x=([-\d.]+) y=([-\d.]+) jumps=(\d+) bounces=(\d+) roll=(\w+) rings=(\d+)',logs())]
emu=subprocess.Popen([str(sdk/'emulator/emulator'),'-avd','wobble','-no-window','-no-audio','-no-boot-anim','-no-snapshot','-gpu','swangle','-skin','1280x720'],stdout=(out/'emulator.log').open('w'),stderr=subprocess.STDOUT)
recording=None
try:
    def booted():
        try:return adb('shell','getprop','sys.boot_completed').strip()=='1'
        except subprocess.SubprocessError:return False
    wait_for(booted,240)
    adb('shell','input','keyevent','82')
    (out/'install.log').write_text(adb('install','-r',sys.argv[1]))
    adb('logcat','-c')
    adb('shell','monkey','-p',package,'-c','android.intent.category.LAUNCHER','1')
    wait_for(lambda:'WOBBLE_LAYOUT ' in logs())
    # Dismiss only the known Android immersive-mode introduction when present.
    adb('shell','uiautomator','dump','/sdcard/window.xml')
    xml=adb('shell','cat','/sdcard/window.xml');(out/'window.xml').write_text(xml)
    import xml.etree.ElementTree as ET
    for node in ET.fromstring(xml).iter('node'):
        if node.get('text')=='Got it':
            bounds=list(map(int,re.findall(r'\d+',node.get('bounds',''))))
            adb('shell','input','tap',str((bounds[0]+bounds[2])//2),str((bounds[1]+bounds[3])//2))
    assert 'FATAL EXCEPTION' not in logs() and 'Fatal signal' not in logs()
    sha=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
    assert 'source='+sha in logs()
    layout=json.loads(re.findall(r'WOBBLE_LAYOUT (\{[^\n]+\})',logs())[-1])
    (out/'layout.json').write_text(json.dumps(layout,indent=2))
    before=capture('initial.png')
    initial=wait_for(lambda:states() and states()[-1])
    recording=subprocess.Popen([adb_path,'shell','screenrecord','--time-limit','30','/sdcard/wobble.mp4'],stdout=(out/'screenrecord.log').open('w'),stderr=subprocess.STDOUT)
    def tap(key):adb('shell','input','tap',*map(str,layout[key]))
    tap('jump')
    wait_for(lambda:any(int(s['jumps'])>=1 for s in states()))
    tap('roll')
    wait_for(lambda:any(s['roll']=='true' for s in states()))
    tap('roll')
    wait_for(lambda:states() and states()[-1]['roll']=='false')
    adb('shell','input','swipe',*map(str,layout['move']),*map(str,layout['move_end']),'14000')
    wait_for(lambda:any(float(s['x'])>float(initial['x'])+150 for s in states()))
    wait_for(lambda:any(int(s['bounces'])>=1 for s in states()),20)
    after=capture('after-touch.png')
    # Background then resume must leave an explicit paused menu.
    adb('shell','input','keyevent','3')
    adb('shell','monkey','-p',package,'-c','android.intent.category.LAUNCHER','1')
    wait_for(lambda:'WOBBLE_PAUSED owners=0 axis=0' in logs())
    (out/'resumed.png').write_bytes(adb('exec-out','screencap','-p',raw=True))
    text=logs();(out/'logcat.txt').write_text(text)
    assert 'SCRIPT ERROR:' not in text and 'FATAL EXCEPTION' not in text and 'Fatal signal' not in text
    (out/'report.json').write_text(json.dumps({'source':sha,'abi':'x86_64','os_touch_movement':True,'jump':True,'roll':True,'spring':True,'images':[before,after],'physical_device':False},indent=2))
    print('ANDROID_SMOKE_PASSED')
finally:
    try:
        (out/'logcat.txt').write_text(logs())
        if recording:
            pids=adb('shell','pidof','screenrecord').strip()
            if pids:adb('shell','kill','-2',*pids.split())
            recording.wait(timeout=15)
            adb('pull','/sdcard/wobble.mp4',str(out/'android.mp4'))
    finally:
        emu.terminate()
        emu.wait(timeout=20)
