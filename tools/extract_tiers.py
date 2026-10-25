"""Extract isolated sprite silhouettes from the four generated production atlases.

The atlas objects have deliberately staggered rows, so fixed rectangular grid
crops would include pieces of neighboring sprites. Connected silhouettes at a
quarter scale identify each asset; a padded mask preserves its original alpha.
"""
from collections import deque
from pathlib import Path
from PIL import Image, ImageChops

ROOT=Path(__file__).resolve().parents[1]
SOURCES={
 'furniture':[['cauldron_t1','cauldron_t2','cauldron_t3'],['shelf_t1','shelf_t2','shelf_t3'],['counter_t1','counter_t2','counter_t3']],
 'plants':[['bed_t1','bed_t2','bed_t3'],['mint_t1','mint_t2','mint_t3'],['moonflower_t1','moonflower_t2','moonflower_t3']],
 'potions':[['energy_t1','energy_t2','energy_t3'],['dream_t1','dream_t2','dream_t3']],
 'foliage':[['bush_t1','bush_t2','bush_t3'],['plant_t1','plant_t2','plant_t3']],
}

def components(alpha):
    small=alpha.copy();small.thumbnail((384,256),Image.Resampling.NEAREST)
    w,h=small.size;px=small.load();seen=set();results=[]
    for y in range(h):
        for x in range(w):
            if (x,y) in seen or px[x,y]<160:continue
            stack=[(x,y)];seen.add((x,y));points=[]
            while stack:
                a,b=stack.pop();points.append((a,b))
                for u,v in ((a-1,b),(a+1,b),(a,b-1),(a,b+1)):
                    if 0<=u<w and 0<=v<h and (u,v) not in seen and px[u,v]>=160:
                        seen.add((u,v));stack.append((u,v))
            if len(points)>500:results.append(points)
    return (w,h),results

for sheet,rows in SOURCES.items():
    source=ROOT/'art/source/tier-atlases'/f'{sheet}.png'
    image=Image.open(source).convert('RGBA')
    alpha=image.getchannel('A')
    (w,h),objects=components(alpha)
    expected=sum(map(len,rows))
    if len(objects)!=expected:raise RuntimeError(f'{sheet}: found {len(objects)} silhouettes, expected {expected}')
    objects.sort(key=lambda pts:sum(y for x,y in pts)/len(pts))
    owners={}
    for number,points in enumerate(objects):
        for point in points:owners[point]=number
    for row,names in enumerate(rows):
        group=objects[row*3:row*3+3]
        group.sort(key=lambda pts:sum(x for x,y in pts)/len(pts))
        for name,points in zip(names,group):
            mask=Image.new('L',(w,h));p=mask.load()
            own_id=objects.index(points)
            for x,y in points:
                p[x,y]=255
                for u,v in ((x-1,y),(x+1,y),(x,y-1),(x,y+1),(x-1,y-1),(x+1,y+1),(x-1,y+1),(x+1,y-1)):
                    if 0<=u<w and 0<=v<h and owners.get((u,v),own_id)==own_id:p[u,v]=255
            mask=mask.resize(image.size,Image.Resampling.NEAREST)
            separated=image.copy()
            separated.putalpha(ImageChops.multiply(alpha,mask))
            box=separated.getchannel('A').getbbox()
            pad=4
            box=(max(0,box[0]-pad),max(0,box[1]-pad),min(image.width,box[2]+pad),min(image.height,box[3]+pad))
            out=ROOT/'game/art'/f'{name}.png'
            separated.crop(box).save(out)
            print(name,separated.crop(box).size)
