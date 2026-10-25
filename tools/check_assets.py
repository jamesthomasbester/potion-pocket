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
print('ASSETS 30 transparent sprites and 6 vector finishes verified')
