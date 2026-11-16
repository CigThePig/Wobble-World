from pathlib import Path
import subprocess, zipfile, sys, hashlib, json
p=Path(sys.argv[1]); out=p.parent
manifest=subprocess.check_output(['aapt2','dump','badging',str(p)],text=True)
xml=subprocess.check_output(['aapt2','dump','xmltree',str(p),'--file','AndroidManifest.xml'],text=True)
(out/(p.stem+'-manifest.txt')).write_text(manifest+'\n'+xml)
signature=subprocess.check_output(['apksigner','verify','--verbose','--print-certs',str(p)],text=True)
assert "package: name='com.cigthepig.wobbleworld.dev'" in manifest
# Godot 4.6 launches through an exported activity-alias, absent from badging's activity list.
assert 'E: activity-alias' in xml and 'android.intent.action.MAIN' in xml and 'android.intent.category.LAUNCHER' in xml
assert 'android:exported' in xml and '=true' in xml
assert 'certificate SHA-256 digest:' in signature
abi='x86_64' if '--emulator' in sys.argv else 'arm64-v8a'
with zipfile.ZipFile(p) as z:
    assert f'lib/{abi}/libgodot_android.so' in z.namelist()
    assert all(n.startswith(f'lib/{abi}/') for n in z.namelist() if n.startswith('lib/') and n.endswith('.so'))
    assert any(n.startswith('assets/game/main.') for n in z.namelist())
    elf=z.read(f'lib/{abi}/libgodot_android.so')
    assert elf[:4]==b'\x7fELF' and elf[4]==2
    assert int.from_bytes(elf[18:20],'little')==(62 if abi=='x86_64' else 183)
    assert any(n.startswith('assets/') and n.endswith('project.binary') for n in z.namelist())
    source=z.read('assets/game/build-source.txt').decode().strip()
    assert source==subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
(out/(p.stem+'-signature.txt')).write_text(signature)
digest=hashlib.sha256(p.read_bytes()).hexdigest()
(out/(p.name+'.sha256')).write_text(digest+'  '+p.name+'\n')
(out/(p.stem+'-metadata.json')).write_text(json.dumps({'source':source,'sha256':digest,'abi':abi,'engine':'4.6.1','package':'com.cigthepig.wobbleworld.dev'},indent=2))
print('APK VERIFIED',p.name)
