"""Make a browsable contact sheet of all shipped production assets."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parents[1]
entries=[f'{family}_t{tier}' for family in ['cauldron','shelf','counter','bed','mint','moonflower','energy','dream','bush','plant'] for tier in range(1,4)]
entries += [f'{kind}_{i}' for kind in ['floor','wall'] for i in range(3)]
cell=(240,240)
out=Image.new('RGB',(cell[0]*6,cell[1]*6),'#faf4ea')
d=ImageDraw.Draw(out)
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',18)
for idx,name in enumerate(entries):
 x=(idx%6)*cell[0];y=(idx//6)*cell[1]
 d.rounded_rectangle((x+6,y+6,x+cell[0]-6,y+cell[1]-6),18,fill='#fffdf7',outline='#ead9c4',width=2)
 if name.startswith(('floor_','wall_')):
  im=Image.new('RGBA',(170,128),(0,0,0,0))
  preview=ImageDraw.Draw(im)
  colors={'floor_0':('#fae7cb','#e5ceb0'),'floor_1':('#eee1f7','#d6bfed'),'floor_2':('#e4efd9','#bad19e'),'wall_0':('#ecd8c3','#c98c62'),'wall_1':('#eee0f2','#aa81cb'),'wall_2':('#e7ecd9','#d1a65d')}
  face,edge=colors[name]
  if name.startswith('floor'):preview.polygon([(85,5),(165,64),(85,123),(5,64)],fill=face,outline=edge,width=4)
  else:preview.rounded_rectangle((6,6,164,122),8,fill=face,outline=edge,width=5)
 else:im=Image.open(root/'game/art'/f'{name}.png').convert('RGBA')
 im.thumbnail((192,176),Image.Resampling.LANCZOS)
 px=x+(cell[0]-im.width)//2;py=y+14+(176-im.height)//2
 out.paste(im,(px,py),im)
 label=name.replace('_',' ').title()
 box=d.textbbox((0,0),label,font=font)
 d.text((x+(cell[0]-(box[2]-box[0]))/2,y+198),label,font=font,fill='#191b43')
path=root/'docs/evidence/tiered/asset-catalog.png'
out.save(path)
print(path)
