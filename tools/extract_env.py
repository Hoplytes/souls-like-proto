"""Cut scenery sprites out of the LPC Revised sheets (github.com/ElizaWy/LPC).
Run: python3 tools/extract_env.py <path-to-ElizaWy-LPC-checkout>"""
import os, shutil, sys
from PIL import Image

SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "env")
os.makedirs(OUT, exist_ok=True)

# name: (sheet, box)   boxes are (left, top, right, bottom) in sheet pixels
PROPS = {
    "tree_dead": ("Terrain/trees_autumn.png", (3, 274, 93, 397)),
    "tree_pine_a": ("Terrain/trees_autumn.png", (420, 357, 505, 493)),
    "tree_pine_b": ("Terrain/trees_autumn.png", (132, 389, 217, 493)),
    "tree_pine_c": ("Terrain/trees_autumn.png", (324, 421, 409, 512)),
    "tree_red_a": ("Terrain/trees_autumn.png", (417, 112, 511, 237)),
    "tree_red_b": ("Terrain/trees_autumn.png", (129, 144, 223, 237)),
    "tree_orange": ("Terrain/trees_autumn.png", (321, 16, 415, 141)),
    "stump": ("Terrain/trees_autumn.png", (26, 437, 69, 468)),
    "tree_shadow": ("Terrain/trees_autumn.png", (16, 25, 80, 56)),
    "rock_big": ("Terrain/Rocks, Grasslands.png", (0, 256, 64, 347)),
    "rock_wide": ("Terrain/Rocks, Grasslands.png", (130, 259, 189, 313)),
    "rock_flat": ("Terrain/Rocks, Grasslands.png", (64, 321, 122, 351)),
    "rock_low": ("Terrain/Rocks, Grasslands.png", (0, 353, 61, 383)),
    "rock_mid": ("Terrain/Rocks, Grasslands.png", (128, 352, 160, 382)),
    "rock_small": ("Terrain/Rocks, Grasslands.png", (129, 327, 158, 351)),
    "pebble": ("Terrain/Rocks, Grasslands.png", (163, 333, 190, 347)),
    "pillar": ("Structure/Pillars/Stone Pillar A.png", (96, 0, 128, 96)),
    "pillar_broken": ("Structure/Pillars/Stone Pillar A.png", (96, 46, 128, 96)),
    "pillar_dark": ("Structure/Pillars/Stone Pillar A.png", (192, 0, 224, 96)),
    "pillar_dark_broken": ("Structure/Pillars/Stone Pillar A.png", (192, 58, 224, 96)),
    "grass_tall_a": ("Terrain/plants_autumn.png", (355, 0, 380, 53)),
    "grass_tall_b": ("Terrain/plants_autumn.png", (386, 0, 413, 53)),
    "grass_short_a": ("Terrain/plants_autumn.png", (263, 23, 285, 51)),
    "grass_short_b": ("Terrain/plants_autumn.png", (295, 23, 317, 51)),
    "fern": ("Terrain/plants_autumn.png", (99, 77, 154, 128)),
    "bush_a": ("Terrain/plants_autumn.png", (0, 0, 32, 32)),
    "bush_b": ("Terrain/plants_autumn.png", (64, 0, 96, 32)),
    "bush_c": ("Terrain/plants_autumn.png", (0, 32, 32, 64)),
    "mushroom_a": ("Terrain/mushrooms.png", (103, 64, 122, 90)),
    "mushroom_b": ("Terrain/mushrooms.png", (6, 98, 24, 121)),
    "tuft_a": ("Terrain/terrain_autumn.png", (256, 96, 288, 128)),
    "tuft_b": ("Terrain/terrain_autumn.png", (64, 192, 96, 224)),
}

for name, (sheet, box) in PROPS.items():
    im = Image.open(os.path.join(SRC, sheet)).convert("RGBA").crop(box)
    bb = im.getchannel("A").getbbox()
    im = im.crop(bb) if bb else im
    im.save(os.path.join(OUT, name + ".png"), optimize=True)

# Whole tile sheets used by the ground tile map.
shutil.copy(os.path.join(SRC, "Terrain/terrain_autumn.png"), os.path.join(OUT, "terrain_autumn.png"))
shutil.copy(os.path.join(SRC, "Structure/Floor/Tile C.png"), os.path.join(OUT, "floor_slabs.png"))
print("wrote", len(PROPS), "props to", os.path.normpath(OUT))
