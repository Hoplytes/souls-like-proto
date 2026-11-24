"""Convert SmallScaleInt's "Fantasy tileset - 2D Isometric" (licensed: the
output goes to local/fantasy/, which is git-ignored here and lives in the
private repo Hoplytes/souls-like-assets; never commit it to this repo).

Run: python3 tools/convert_fantasy.py <the pack's folder or zip> [local/fantasy]

Output, in the same formats as tools/convert_flare.py:
- tiles/: atlas_<page>.png + floors.png + tiles.json
  {"res", "tiles": {name: [page, x, y, w, h, ax, ay]}, "floors": {name: index},
   "floor_cell", "floor_cols"}; tile names are the pack's file names without
  ".png" (e.g. "Tree A1_S"). Every 256x256 tile stands on a 128x64 diamond
  centred at (128, 208).
- chars/<name>/: one packed sheet per animation + anims.json (15 frames,
  8 rows E, SE, S, SW, W, NW, N, NE; frames cropped and packed)."""
import json, os, re, shutil, sys, tempfile, zipfile
from PIL import Image

src = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "local", "fantasy")
if src.endswith(".zip"):
    tmp = tempfile.mkdtemp()
    zipfile.ZipFile(src).extractall(tmp)
    src = tmp
ROOT = next(os.path.join(d) for d, subs, _ in os.walk(src) if "Environment" in subs)
ENV = os.path.join(ROOT, "Environment")

RES = 128 / 96  # the pack's pixels per world unit (a 96-unit cell is 128 px wide)
ANCHOR = (128, 208)  # the tile diamond's centre in every 256x256 tile

# --- tiles ------------------------------------------------------------------
# Floors: full ground blocks (drawn by the game's TileMapLayer, all 4 turns).
FLOOR_RE = re.compile(r"^(Ground (A1|A2|A18|B[1-6]|C[1-6]|D1|E1|F1|F3|H1|H4|H9|H10|H11|I([1-9]|10)|J1"
                      r"|A([3-9]|1[0-2]|19|2[0-4])|E([2-9]|1[0-5])|J([2-9]|10))|Flora A[1-7])_[NESW]$")
# (the ground overlays -- grass tufts, pebbles, flowers -- are on the grid too:
# the game draws them with a second tile layer instead of one node each)
# Scenery, ground overlays, house parts, cliffs and ramps kept.
KEEP_RE = re.compile(r"^(Ground (A([3-9]|1[0-2]|19|2[0-4])|B[1-6]|C[1-6]|E([2-9]|1[0-5])|J([2-9]|10))_[NESW]"
                     r"|Tree .*|Stone .*|Flora .*|WallFlora .*|Misc .*_S|Wall A.*|FirePlace|Torch.*|Chest A1_S"
                     r"|Wall (D|F|G)(1|7)_[NESW]|Roof (C|D)(1|6)_[NESW]|Door A1_[NESW]"
                     r"|Ground G(12|13|16|22)_[NESW]|Wall B([1-9]|1[01])_[NESW]|Wall E1[5-8]_[NESW])$")
FLOOR_CELL = (136, 96)  # floor grid cell, the diamond's centre in the middle
FLOOR_COLS = 14

# Whole ground blocks (not the overlays): their edges are bled outward a
# little so that neighbouring cells overlap -- otherwise the half-transparent
# rim of each diamond lets a thin dark seam show between cells.
BASE_FLOOR_RE = re.compile(r"^Ground (A1|A2|A18|B[1-6]|C[1-6]|D1|E1|F1|F3|H1|H4|H9|H10|H11|I([1-9]|10)|J1)_[NESW]$")

def bleed(im):
    # Some tiles (the dark grass) have a dark rim drawn along the diamond's
    # edges: its last pixels take the colour found a little further in.
    src = im.copy()
    px = im.load()
    sp = src.load()
    for y in range(160, 256):
        for x in range(56, 200):
            t = abs(x - ANCHOR[0]) / 64.0 + abs(y - ANCHOR[1]) / 32.0
            if 0.9 <= t <= 1.05:
                sx = round(ANCHOR[0] + (x - ANCHOR[0]) * 0.86)
                sy = round(ANCHOR[1] + (y - ANCHOR[1]) * 0.86)
                r, g, b, a = sp[sx, sy]
                if a > 0:
                    px[x, y] = (r, g, b, 255)
    s = 1.035
    big = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    out = Image.new("RGBA", im.size)
    out.paste(big, (round(ANCHOR[0] - ANCHOR[0] * s), round(ANCHOR[1] - ANCHOR[1] * s)))
    out.alpha_composite(im)
    return out

def convert_tiles():
    names = sorted(f[:-4] for f in os.listdir(ENV) if f.endswith(".png"))
    floors = [n for n in names if FLOOR_RE.match(n)]
    keep = [n for n in names if KEEP_RE.match(n) or n in floors]
    out = os.path.join(OUT, "tiles")
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    pieces = {}
    for n in keep:
        im = Image.open(os.path.join(ENV, n + ".png")).convert("RGBA")
        if BASE_FLOOR_RE.match(n):
            im = bleed(im)
        b = im.getbbox()
        if b:
            pieces[n] = (im.crop(b), ANCHOR[0] - b[0], ANCHOR[1] - b[1], im)
    # Dark grass edges ("Ground A3D", "A4D"): the ragged light-grass edges
    # tinted to the dark grass (the pack's own dark edges are straight-cut).
    for base in ["Ground A3", "Ground A4"]:
        for t in "NESW":
            n = base + "_" + t
            if n in pieces:
                piece, ax, ay, full = pieces[n]
                def tint(im):
                    r, g, b, a = im.split()
                    return Image.merge("RGBA", (r.point(lambda v: v * 0.40), g.point(lambda v: v * 0.53),
                                                b.point(lambda v: v * 0.21), a))
                pieces[base + "D_" + t] = (tint(piece), ax, ay, tint(full))
                floors.append(base + "D_" + t)
    meta = {"res": RES, "tiles": {}, "floors": {}, "floor_cell": list(FLOOR_CELL), "floor_cols": FLOOR_COLS}
    W, H = 2048, 4096
    pages, page, x, y, shelf = [], [], 0, 0, 0
    for n in sorted(pieces, key=lambda n: -pieces[n][0].height):
        piece, ax, ay, _ = pieces[n]
        if x + piece.width > W:
            x, y, shelf = 0, y + shelf + 2, 0
        if y + piece.height > H:
            pages.append(page)
            page, x, y, shelf = [], 0, 0, 0
        page.append((n, x, y))
        meta["tiles"][n] = [len(pages), x, y, piece.width, piece.height, ax, ay]
        x += piece.width + 2
        shelf = max(shelf, piece.height)
    pages.append(page)
    for k, pg in enumerate(pages):
        sheet = Image.new("RGBA", (W, max(py + pieces[n][0].height for n, px, py in pg)))
        for n, px, py in pg:
            sheet.paste(pieces[n][0], (px, py))
        sheet.save(os.path.join(out, f"atlas_{k}.png"), optimize=True)
    cw, ch = FLOOR_CELL
    floors = [n for n in floors if n in pieces]
    grid = Image.new("RGBA", (cw * FLOOR_COLS, ch * ((len(floors) + FLOOR_COLS - 1) // FLOOR_COLS)))
    for k, n in enumerate(floors):
        full = pieces[n][3]
        cell = full.crop((ANCHOR[0] - cw // 2, ANCHOR[1] - ch // 2, ANCHOR[0] + cw // 2, ANCHOR[1] + ch // 2))
        grid.paste(cell, ((k % FLOOR_COLS) * cw, (k // FLOOR_COLS) * ch))
        meta["floors"][n] = k
    # Water: the pack has foam and ripples but no water surface; a plain one
    # (our own, drawn here) goes on the last cell of the grid.
    k = len(floors)
    if k >= grid.width // cw * (grid.height // ch):
        bigger = Image.new("RGBA", (grid.width, grid.height + ch))
        bigger.paste(grid, (0, 0))
        grid = bigger
    import random
    rnd = random.Random(3)
    water = Image.new("RGBA", (cw, ch))
    cx, cy = cw // 2, ch // 2
    for y in range(ch):
        for x in range(cw):
            if abs(x - cx) / 64.0 + abs(y - cy) / 32.0 <= 1.08:  # a little over the cell: no seams
                n = rnd.randint(-6, 6)
                water.putpixel((x, y), (38 + n, 104 + n, 128 + n, 255))
    grid.paste(water, ((k % FLOOR_COLS) * cw, (k // FLOOR_COLS) * ch))
    meta["floors"]["Water"] = k
    grid.save(os.path.join(out, "floors.png"), optimize=True)
    json.dump(meta, open(os.path.join(out, "tiles.json"), "w"), indent=0)
    print("tiles", len(pieces), "pages", len(pages), "floors", len(floors))

# --- characters --------------------------------------------------------------
CHARS = {"Player": "hero", "Enemy 1": "skeleton_a", "Enemy 2": "skeleton_b", "Enemy 3": "skeleton_c",
         "NPC1": "brigand_a", "NPC2": "brigand_b", "NPC3": "brigand_c"}
ANIMS = ["Idle", "Walk", "Run", "StrafeLeft", "StrafeRight", "RunBackwards", "Attack1", "Attack2", "Attack4",
         "Attack5", "AttackRun", "Special1", "TakeDamage", "Die", "CrouchIdle", "CrouchRun", "Taunt"]
CELL, FRAMES = 128, 15
FEET = [64, 88]

def convert_chars():
    for folder, name in CHARS.items():
        out = os.path.join(OUT, "chars", name)
        shutil.rmtree(out, ignore_errors=True)
        os.makedirs(out)
        meta = {"cell": CELL, "feet": FEET, "res": RES, "packed": True, "anims": {}}
        for anim in ANIMS:
            im = Image.open(os.path.join(ROOT, "Characters", folder, anim + ".png")).convert("RGBA")
            n = im.width // CELL
            crops = []
            for prow in range(8):
                row = prow  # same order as the game: E, SE, S, SW, W, NW, N, NE
                for f in range(n):
                    c = im.crop((f * CELL, prow * CELL, f * CELL + CELL, prow * CELL + CELL))
                    b = c.getbbox()
                    crops.append((row, f, c.crop(b) if b else None, b))
            width = 1024
            rects = [[[0, 0, 0, 0, 0, 0] for _ in range(n)] for _ in range(8)]
            x = y = shelf = 0
            placed = []
            for row, f, c, b in sorted(crops, key=lambda c: -(c[2].height if c[2] else 0)):
                if c is None:
                    continue
                if x + c.width > width:
                    x, y, shelf = 0, y + shelf + 2, 0
                placed.append((c, x, y))
                rects[row][f] = [x, y, c.width, c.height, b[0], b[1]]
                x += c.width + 2
                shelf = max(shelf, c.height)
            sheet = Image.new("RGBA", (width, max(1, y + shelf)))
            for c, px, py in placed:
                sheet.paste(c, (px, py))
            sheet.save(os.path.join(out, anim + ".png"), optimize=True)
            meta["anims"][anim] = {"frames": n, "rects": rects}
        json.dump(meta, open(os.path.join(out, "anims.json"), "w"))
        print("char", name)

# --- animated props -------------------------------------------------------------
FX = {"Props/Fire": "flame", "Props/Torch 1": "torch", "Props/PortalIdle": "portal",
      "Animated Tiles/WindMill1": "windmill", "Animated Tiles/Water Ripples 1": "ripple_ring",
      "Animated Tiles/Water Ripples 10": "ripple_a", "Animated Tiles/Water Ripples 11": "ripple_b",
      # Breakable scenery: frame 0 is the object, the last frame its debris.
      "Props/Barrel 1": "break_barrel_a", "Props/Barrel 2": "break_barrel_b", "Props/Barrel 3": "break_barrel_c",
      "Destructible tiles/Clay explosion": "break_jar", "Destructible tiles/straw explosion": "break_straw",
      "Destructible tiles/grass explosion large": "break_grass", "Destructible tiles/Grass explosion small": "break_grass_small",
      "Destructible tiles/Tree Green Explosion": "break_tree_green", "Destructible tiles/Tree Yellow Explosion": "break_tree_yellow",
      "Destructible tiles/stone explosion Small": "break_stones", "Destructible tiles/stone explosion large": "break_rocks",
      "Destructible tiles/wood explosion Small": "break_crate", "Destructible tiles/wood explosion large": "break_woodpile",
      # Chips flying off when breakable scenery is hit (played once).
      "Destructible tiles/Wood damage": "hit_wood", "Destructible tiles/Stone damage": "hit_stone"}

def convert_fx():
    """Each animation: its frames side by side, cropped to their common box.
    fx.json: {name: {frames, w, h, ax, ay}}, (ax, ay) the tile anchor (or,
    for the 128 px flame, the base of the fire) inside a frame."""
    out = os.path.join(OUT, "fx")
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    meta = {}
    for folder, name in FX.items():
        d = os.path.join(ROOT, "Animations", folder)
        frames = [Image.open(os.path.join(d, f)).convert("RGBA") for f in sorted(os.listdir(d)) if f.endswith(".png")]
        box = None
        for im in frames:
            b = im.getbbox()
            if b:
                box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
        w, h = box[2] - box[0], box[3] - box[1]
        cols = min(len(frames), 4096 // w)  # at most 4096 px wide (WebGL)
        rows = (len(frames) + cols - 1) // cols
        strip = Image.new("RGBA", (w * cols, h * rows))
        for k, im in enumerate(frames):
            strip.paste(im.crop(box), ((k % cols) * w, (k // cols) * h))
        strip.save(os.path.join(out, name + ".png"), optimize=True)
        size = frames[0].width
        anchor = (64, 72) if size == 128 else (size // 2, size * 13 // 16)  # 512 px: a 2x2-cell footprint
        meta[name] = {"frames": len(frames), "cols": cols, "w": w, "h": h, "ax": anchor[0] - box[0], "ay": anchor[1] - box[1]}
    json.dump(meta, open(os.path.join(out, "fx.json"), "w"), indent=1)
    print("fx", list(meta))

if "--fx-only" not in sys.argv:
    convert_tiles()
    convert_chars()
convert_fx()
