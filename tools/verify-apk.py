from pathlib import Path
import subprocess, zipfile, sys, hashlib, json
p=Path(sys.argv[1]); out=p.parent
manifest=subprocess.check_output(['aapt','dump','badging',str(p)],text=True)
signature=subprocess.check_output(['apksigner','verify','--verbose','--print-certs',str(p)],text=True)
assert "package: name='com.cigthepig.wobbleworld.dev'" in manifest
assert 'launchable-activity:' in manifest
abi='x86_64' if '--emulator' in sys.argv else 'arm64-v8a'
with zipfile.ZipFile(p) as z:
    assert f'lib/{abi}/libgodot_android.so' in z.namelist()
    assert any(n.startswith('assets/') and n.endswith('project.binary') for n in z.namelist())
    source=z.read('assets/game/build-source.txt').decode().strip()
    assert source==subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
(out/(p.stem+'-manifest.txt')).write_text(manifest)
(out/(p.stem+'-signature.txt')).write_text(signature)
digest=hashlib.sha256(p.read_bytes()).hexdigest()
(out/(p.name+'.sha256')).write_text(digest+'  '+p.name+'\n')
(out/(p.stem+'-metadata.json')).write_text(json.dumps({'source':source,'sha256':digest,'abi':abi,'engine':'4.6.1','package':'com.cigthepig.wobbleworld.dev'},indent=2))
print('APK VERIFIED',p.name)
