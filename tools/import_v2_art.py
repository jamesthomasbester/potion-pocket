"""Copy the chosen art/v2 cut-outs into game/art for runtime use.

art/ is excluded from export, so the shop scene loads these copies. Furniture
is halved (it is drawn well below its source size); the room, sky and HUD
icons keep full resolution. Rerun after changing a pick below.
"""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
src = root / 'art/v2'
shop = root / 'game/art/shop'
ui = root / 'game/art/ui'
# One cut-out per tier (t1, t2, t3), matching the game's level 1/3/7 art tiers.
TIERS = {
    'cauldron': ['cauldron/t1_seed2619076981_cut', 'cauldron/t2_cut', 'cauldron/t3_seed2219203962_cut'],
    'counter': ['shop_counter_sheet/seed669728475_cut1', 'shop_counter_sheet/seed669728475_cut2', 'shop_counter_sheet/seed669728475_cut3'],
    'potion_shelf': ['bookcase_purple/t1_seed2938632042_cut', 'bookcase_purple/t2_cut', 'bookcase_purple/t3_seed2838126136_cut'],
    'bookcase': ['bookcase_amber/t1_seed2376558755_cut', 'bookcase_amber/t2_cut', 'bookcase_amber/t3_seed172019034_cut'],
    'workbench': ['workbench/t1_seed3667237731_cut', 'workbench/t2_cut', 'workbench/t3_seed2174775064_cut'],
    'lectern': ['lectern_rot/t1/seed1571052957_cut', 'lectern_rot/t2/seed1029225267_cut', 'lectern_rot/t3/seed3756409768_cut'],
    'books': ['book_stack/t1_seed2304387617_cut', 'book_stack/t2_cut', 'book_stack/t3_seed3361449894_cut'],
    'rug': ['moon_rug/t1_seed2600604092_cut', 'moon_rug/t2_cut', 'moon_rug/t3_seed1263269516_cut'],
    'door_mat': ['door_mat/t1_seed221783967_cut', 'door_mat/t2_cut', 'door_mat/t3_seed2398598579_cut'],
    'plant': ['potted_plant/t1_seed1245336311_cut', 'potted_plant/t2_cut', 'potted_plant/t3_seed3237999719_cut'],
}
FULL = {'room': 'seed1604686692_cut', 'sky': 'night_sky'}
ICONS = {'coin': 'out', 'gear': 'gear-out', 'book': 'book-out', 'shop': 'shop-out', 'garden': 'gardeb-out', 'potion': 'potion-out', 'market': 'market-out'}

shop.mkdir(parents=True, exist_ok=True)
ui.mkdir(parents=True, exist_ok=True)
for name, picks in TIERS.items():
    for tier, pick in enumerate(picks, 1):
        im = Image.open(src / (pick + '.png')).convert('RGBA')
        im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
        im.save(shop / f'{name}_t{tier}.png', optimize=True)
for name, pick in FULL.items():
    Image.open(src / (pick + '.png')).convert('RGBA').save(shop / f'{name}.png', optimize=True)
for name, pick in ICONS.items():
    Image.open(src / (pick + '.png')).convert('RGBA').save(ui / f'{name}.png', optimize=True)
print('Copied', sum(len(p) for p in TIERS.values()) + len(FULL), 'shop images and', len(ICONS), 'icons')
