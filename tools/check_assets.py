"""Check every production variant is importable, transparent and cataloged."""
from pathlib import Path
from xml.etree import ElementTree
from PIL import Image
root=Path(__file__).resolve().parents[1]
families=['cauldron','shelf','counter','bed','mint','moonflower','energy','dream','bush','plant']
for family in families:
 for tier in range(1,4):
  name=f'{family}_t{tier}.png'
  path=root/'game/art'/name
  with Image.open(path) as image:
   assert image.mode=='RGBA',name
   assert min(image.size)>120,name
   a=image.getchannel('A')
   assert a.getextrema()[0]==0 and a.getextrema()[1]>=250,name
   assert sum(1 for p in [(0,0),(image.width-1,0),(0,image.height-1),(image.width-1,image.height-1)] if a.getpixel(p)==0)==4,name
for kind in ['floor','wall']:
 for variant in range(3):
  ElementTree.parse(root/'game/art/decor'/f'{kind}_{variant}.svg')
for name in ['owner','brewer','cashier','gardener','customer0','customer1','departing']:
 path=root/'game/art/animations'/f'{name}.png'
 with Image.open(path) as image:
  assert image.mode=='RGBA' and image.size==(1024,1024),name
  for row in range(4):
   for col in range(4):
    frame=image.crop((col*256,row*256,(col+1)*256,(row+1)*256)).getchannel('A')
    assert frame.getbbox() is not None and sum(frame.histogram()[200:])>400,name+f' {row},{col}'
    assert frame.getpixel((0,0))==0 and frame.getpixel((255,0))==0,name+f' edge {row},{col}'
print('ASSETS 30 transparent variants, 6 vector finishes, 112 animation frames verified')
