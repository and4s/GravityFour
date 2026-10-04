from pathlib import Path
import zipfile,hashlib,json
root=Path(__file__).resolve().parent.parent
for name,folder in [('GravityFour-Windows-v3.9.zip','dist/v3.9')]:
    with zipfile.ZipFile(root/name,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in sorted((root/folder).rglob('*')):
            if p.is_file(): z.write(p,p.relative_to(root/folder))
with zipfile.ZipFile(root/'GravityFour-Source-v3.9.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    files=[]
    for folder in ['scripts','audio','fonts','assets','tests','docs']:
        for p in (root/folder).rglob('*'):
            if not p.is_file(): continue
            if folder=='tests' and p.suffix not in ['.gd','.uid','.json']: continue
            files.append(p)
    for pattern in ['*.tscn','*.godot','*.cfg','*.svg','*.ps1','*.bat','README.md','LICENSE','.gitignore','.gitattributes']:
        files.extend(root.glob(pattern))
    for name in ['README.md', 'package.py', 'fetch_templates.py', 'fetch_android_templates.py', 'generate_audio.py', 'generate_draw_fixture.py']:
        files.append(root/'tools'/name)
    for p in sorted(set(files)): z.write(p,p.relative_to(root))
files=['dist/v3.9/GravityFour.exe','GravityFour-Windows-v3.9.zip','dist/android/GravityFour-v3.9.apk','GravityFour-Source-v3.9.zip']
result={p:{'bytes':(root/p).stat().st_size,'sha256':hashlib.sha256((root/p).read_bytes()).hexdigest()} for p in files}
(root/'dist/release-v3.9-checksums.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
with zipfile.ZipFile(root/'dist/android/GravityFour-v3.9.apk') as z:
    names=z.namelist()
    assert 'lib/arm64-v8a/libgodot_android.so' in names
    assert 'lib/armeabi-v7a/libgodot_android.so' in names
    for name in ['GODOT-LICENSE','GODOT-COPYRIGHT','NOTO-LICENSE','PROJECT-LICENSE']:
        assert any(name+'.txt' in p for p in names),name
    assert any('NotoSansSC-Medium' in p for p in names)
    assert any(p.endswith('app_info.json') for p in names)
    assert not any('gravity-four-release.keystore' in p or 'release-key-password' in p for p in names)
print('APK assets: font, all licenses and both ARM architectures verified; no signing secrets.')
