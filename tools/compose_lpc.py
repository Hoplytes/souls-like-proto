"""Assemble LPC layers into Godot-ready sprite sheets.

Every sheet uses 128x128 cells. Rows: for each animation in ANIMS, one row per
direction (up, left, down, right), except 'hurt' which has a single row.
Run:  python3 tools/compose_lpc.py <path-to-LPC-repo>/spritesheets
"""
import json, os, sys
from PIL import Image

SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites')
CELL = 128
ANIMS = [("idle", 2, 4), ("walk", 9, 4), ("slash", 6, 4), ("thrust", 8, 4), ("hurt", 6, 1), ("jump", 5, 4)]
COLS = max(a[1] for a in ANIMS)

# Weapon attack sheets that are drawn on 128 px cells (others are 64 px).
def layer_path(spec, anim):
    """spec: str folder with <anim>.png, or callable(anim) -> path or None.
    A layer with no idle falls back to the first frame of its walk."""
    if isinstance(spec, tuple):
        spec = spec[0]
    p = spec(anim) if callable(spec) else os.path.join(spec, anim + ".png")
    if p and os.path.exists(os.path.join(SRC, p)):
        return p
    if anim == "idle":
        w = layer_path(spec, "walk")
        return (w, "first") if w else None
    return None

def tint(im, hue, sat=None, val=0.8):
    """Recolour every visible pixel to the given hue (0-255), keeping light and shade.
    sat: target saturation (None keeps a light boost of the original), val: brightness factor."""
    h, s, v = im.convert("RGB").convert("HSV").split()
    h = h.point(lambda _: hue)
    if sat is None:
        s = s.point(lambda x: min(255, int(x * 0.9) + 25))
    else:
        s = s.point(lambda x: sat)
    v = v.point(lambda x: min(255, int(x * val)))
    out = Image.merge("HSV", (h, s, v)).convert("RGBA")
    out.putalpha(im.getchannel("A"))
    return out

def compose(name, layers):
    rows = sum(a[2] for a in ANIMS)
    sheet = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    row0 = 0
    for anim, frames, nrows in ANIMS:
        for spec in layers:
            p = layer_path(spec, anim)
            if not p:
                continue
            first_only = isinstance(p, tuple)
            if first_only:
                p = p[0]
            im = Image.open(os.path.join(SRC, p)).convert("RGBA")
            if isinstance(spec, tuple):
                im = tint(im, *spec[1:])
            src_cell = 128 if im.height >= nrows * 128 else 64
            off = (CELL - src_cell) // 2
            for r in range(min(nrows, im.height // src_cell)):
                for f in range(frames):
                    if (f + 1) * src_cell > im.width:
                        break
                    sf = 0 if first_only else f
                    tile = im.crop((sf * src_cell, r * src_cell, (sf + 1) * src_cell, (r + 1) * src_cell))
                    dst = Image.new("RGBA", (CELL, CELL))
                    dst.paste(tile, (off, off))
                    cell = sheet.crop((f * CELL, (row0 + r) * CELL, (f + 1) * CELL, (row0 + r + 1) * CELL))
                    cell = Image.alpha_composite(cell, dst)
                    sheet.paste(cell, (f * CELL, (row0 + r) * CELL))
        row0 += nrows
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, name + ".png"), optimize=True)
    print("wrote", name, sheet.size)

def sword(part):  # part: 'bg' or 'fg'
    def f(anim):
        if anim == "slash":
            return f"weapon/sword/arming/attack_slash/{part}/steel.png"
        return f"weapon/sword/arming/universal/{part}/{anim}/steel.png"
    return f

def spear(part):  # part: 'background' or 'foreground'
    return lambda anim: f"weapon/polearm/spear/{part}/{anim}/steel.png"

def mean_hue(path):
    im = Image.open(os.path.join(SRC, path)).convert("RGBA")
    hs = [px[0] for px, a in zip(im.convert("RGB").convert("HSV").get_flattened_data(), im.getchannel("A").get_flattened_data()) if a > 200]
    return sorted(hs)[len(hs) // 2]

ORC_HUE = mean_hue("head/heads/orc/male/walk.png")

KNIGHT = ["body/bodies/male", "head/heads/human/male", "head/faces/male/neutral",
          "legs/armour/plate/male", "feet/armour/plate/male", "torso/armour/plate/male",
          "arms/armour/plate/male", "hair/plain/adult"]

BRONZE = (21, 125, 1.1)
RED = (250, 175, 0.85)
LEATHER = (16, 95, 0.75)
SPARTAN = ["body/bodies/male", "head/heads/human/male", "head/faces/male/neutral",
           "feet/sandals/male", ("legs/armour/plate/male",) + BRONZE, ("legs/skirts/legion/male",) + LEATHER,
           ("torso/armour/legion/male",) + BRONZE, lambda a: f"shoulders/legion/male/{a}/bronze.png",
           "arms/bracers/male", ("cape/solid/fg",) + RED, lambda a: f"shield/spartan/fg/{a}/spartan.png",
           ("hat/helmet/legion/adult",) + BRONZE, ("hat/accessory/crest/adult",) + RED]
SPARTAN_BACK = [lambda a: f"shield/spartan/bg/{a}/spartan.png", ("cape/solid/bg",) + RED]

compose("knight", KNIGHT)
compose("spartan", SPARTAN)
compose("spartan_back", SPARTAN_BACK)
compose("sword_bg", [sword("bg")])
compose("sword_fg", [sword("fg")])
compose("spear_bg", [spear("background")])
compose("spear_fg", [spear("foreground")])
compose("skeleton", ["body/bodies/skeleton"])
compose("orc", [("body/bodies/muscular", ORC_HUE), "head/heads/orc/male"])

json.dump({"cell": CELL, "anims": [{"name": a, "frames": f, "rows": r} for a, f, r in ANIMS]},
          open(os.path.join(OUT, "layout.json"), "w"), indent=1)
