from PIL import Image, ImageOps, ImageDraw
from pathlib import Path
p=Path('files-pasted-by-the-user-build/outputs/Loop/art_review')
ids=['stack','runner','crowd','racer','color_gate','merge','cell_odyssey']
for kind in ['desktop','desktop-tutorial','desktop-pause','desktop-results','portrait-tutorial','portrait-results']:
    sheet=Image.new('RGB',(4*320,2*240),'#101820')
    for i,id in enumerate(ids):
        f=p/'after'/f'{id}-{kind}.png'
        if not f.exists():continue
        img=Image.open(f).convert('RGB');img.thumbnail((316,216))
        x=i%4*320;y=i//4*240
        sheet.paste(img,(x+(320-img.width)//2,y+24))
        ImageDraw.Draw(sheet).text((x+8,y+5),id,fill='white')
    sheet.save(p/f'review-{kind}.jpg')
