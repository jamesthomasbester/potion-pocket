"""Generate the six scalable architecture swatches used by the Decor menu."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'game/art/decor'
root.mkdir(parents=True,exist_ok=True)
styles=[
 ('floor_0','#fae7cb','#f6e1c2','#e5ceb0',''),
 ('floor_1','#eee1f7','#f8edfc','#d6bfed','<path d="M64 26l8 9-8 9-8-9z M20 67l5 5-5 5-5-5z M108 67l5 5-5 5-5-5z" fill="#b995e4"/>'),
 ('floor_2','#e4efd9','#f3f4dc','#bad19e','<path d="M57 37q-2-14 14-15-2 16-14 15zm6 30q10-13 22-4-13 11-22 4z" fill="#70aa6f"/>'),
 ('wall_0','#ecd8c3','#d8c4b2','#c98c62',''),
 ('wall_1','#eee0f2','#d8c5e7','#aa81cb','<path d="M34 25h60v47H34z" fill="none" stroke="#aa81cb" stroke-width="3"/>'),
 ('wall_2','#e7ecd9','#c9d9bd','#d1a65d','<path d="M102 18q-20 10-16 34t-22 23" fill="none" stroke="#579162" stroke-width="3"/><path d="M88 45q-18-8-14-20 12 4 14 20zm-7 18q12-7 22-3-10 11-22 3z" fill="#70aa6f"/>')
]
for name,a,b,line,motif in styles:
    if name.startswith('floor'):
        body=f'<path d="M64 8L122 48 64 88 6 48z" fill="{a}" stroke="{line}" stroke-width="4"/><path d="M64 8v80M6 48h116" stroke="{line}" stroke-width="2"/><path d="M64 8L122 48 64 88 6 48" fill="none" stroke="{b}" stroke-width="5"/>{motif}'
    else:
        body=f'<path d="M7 10h114v76H7z" fill="{a}" stroke="{line}" stroke-width="5"/><path d="M7 63h114v23H7z" fill="{b}"/><path d="M7 10h114" stroke="{line}" stroke-width="10"/>{motif}'
    (root/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="96" viewBox="0 0 128 96">{body}</svg>')
print('Created',len(styles),'architecture swatches')
