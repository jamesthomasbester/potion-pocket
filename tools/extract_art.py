from PIL import Image, ImageDraw, ImageFilter, ImageChops
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def extract(source,names,xs,ys):
 im=Image.open(root/source)
 for i,name in enumerate(names):
  c=im.crop((xs[i%3],ys[i//3],xs[i%3+1],ys[i//3+1]))
  mask=c.getchannel('A').point(lambda x:255 if x>180 else 0)
  small=mask.copy();small.thumbnail((140,140))
  w,h=small.size; px=small.load();seen=set();best=[]
  for yy in range(h):
   for xx in range(w):
    if (xx,yy) in seen or px[xx,yy]<64:continue
    todo=[(xx,yy)];seen.add((xx,yy));part=[]
    while todo:
     x,y=todo.pop();part.append((x,y))
     for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
      if 0<=nx<w and 0<=ny<h and (nx,ny) not in seen and px[nx,ny]>=64:seen.add((nx,ny));todo.append((nx,ny))
    if len(part)>len(best):best=part
  sx=c.width/w;sy=c.height/h
  bounds=(max(0,int(min(x for x,y in best)*sx)-3),max(0,int(min(y for x,y in best)*sy)-3),min(c.width,int((max(x for x,y in best)+1)*sx)+3),min(c.height,int((max(y for x,y in best)+1)*sy)+3))
  # Atlas extraction: retain this sprite's connected silhouette, with padding
  # for antialiasing and its shadow; discard neighboring-cell fragments.
  cut=Image.new('L',(w,h));d=ImageDraw.Draw(cut)
  for point in best:d.point(point,fill=255)
  cut=cut.filter(ImageFilter.MaxFilter(7)).resize(c.size,Image.Resampling.NEAREST)
  c.putalpha(ImageChops.multiply(c.getchannel('A'),cut))
  c.crop(bounds).save(root/'game/art'/f'{name}.png')
extract('art/source/props-atlas.png',['cauldron','shelf','counter','leaves','flowers','bed','bush','plant','gate'],[0,540,1024,1536],[0,385,700,1024])
extract('art/source/characters-atlas.png',['owner','brewer','cashier','gardener','customer0','customer1','departing','energy','dream'],[0,420,820,1263],[0,460,878,1246])
