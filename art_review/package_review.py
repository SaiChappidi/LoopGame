from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import zipfile,re
base=Path('files-pasted-by-the-user-build/outputs')
p=base/'Loop/art_review'
ids=['stack','runner','crowd','racer','color_gate','merge','cell_odyssey']
names=['Stack Studio','Skyline Sprint','Small World','Coastline','Chromatic','Soft Numbers','Cell Odyssey']
out=Image.new('RGB',(1540,930),'#111b22');d=ImageDraw.Draw(out)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',17)
for i,(id,name) in enumerate(zip(ids,names)):
    d.text((i*220+8,8),name,font=font,fill='#e2e7dd')
    for row,phase in enumerate(['before','after']):
        im=Image.open(p/phase/f'{id}-portrait.png').convert('RGB');im.thumbnail((208,400))
        x=i*220+(220-im.width)//2;y=55+row*445
        out.paste(im,(x,y));d.text((i*220+8,y-23),phase.upper(),font=font,fill='#a9c8bc')
out.save(p/'before-after-overview.jpg',quality=93)
# Update existing static preview pages to match the new actual games.
for id in ids[:6]:
    (base/'Loop-Web-Previews/images'/f'{id}.png').write_bytes((p/'after'/f'{id}-portrait.png').read_bytes())
for f in (base/'Loop-Web-Previews').glob('*.html'):
    f.write_text(f.read_text(encoding='utf-8').replace('../Loop-Platform-Windows.zip','../Loop-Visual-Edition-Windows.zip'),encoding='utf-8')
# Only distribution files; personal data and review/test saves are excluded.
package=base/'Loop-Visual-Edition'
with zipfile.ZipFile(base/'Loop-Visual-Edition-Windows.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for name in ['bin/Godot.exe','Loop.pck','Play LOOP.cmd','README.md','ASSET_CREDITS.md','licenses/Godot-LICENSE.txt','licenses/Godot-COPYRIGHT.txt','licenses/Godot-AUTHORS.md']:
        z.write(package/name,'Loop-Visual-Edition/'+name)
# Validate every gallery image target.
for id in ids:
    for view in ['portrait','desktop']:
        for mode in ['', '-detail']:
            for phase in ['before','after']:
                assert (p/phase/f'{id}-{view}{mode}.png').is_file()
        for state in ['tutorial','pause','results']:
            assert (p/'after'/f'{id}-{view}-{state}.png').is_file()
print('Gallery image targets verified; ZIP excludes all saves.')
