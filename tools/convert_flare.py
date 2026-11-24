"""Convert Flare (github.com/flareteam/flare-game, CC-BY-SA 3.0) art for the
isometric prototype:
- enemies: packed atlases -> one uniform sheet per animation, 8 rows in the
  HD hero's order (E, SE, S, SW, W, NW, N, NE), feet at a fixed point;
- dungeon tiles: cut out one by one.
Everything is scaled down to match the HD hero.
Run: python3 tools/convert_flare.py <flare-game checkout>"""
import json, os, sys
from PIL import Image

SRC = os.path.join(sys.argv[1], "mods", "fantasycore")
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "flare")
# Detail factor: the game draws its world at 640x360 units but renders at the
# screen's resolution (1280x720 and more), so art is stored at RES times the
# size it takes in the world, and drawn at 1/RES (the "res" key of the
# metadata tells the game).
RES = 2

def parse(path):
    anims, cur, images = {}, None, {}
    default_img = None
    for line in open(path):
        line = line.strip()
        if line.startswith("image="):
            v = line[6:].split(",")
            if len(v) == 2:
                images[v[1]] = v[0]
            else:
                default_img = v[0]
        elif line.startswith("["):
            cur = line[1:-1]
            anims[cur] = {"frames": [], "image": images.get(cur, default_img)}
        elif cur and line.startswith("frames="):
            anims[cur]["count"] = int(line[7:])
        elif cur and line.startswith("duration="):
            anims[cur]["ms"] = int(line[9:].replace("ms", "").replace("s", "000"))
        elif cur and line.startswith("type="):
            anims[cur]["type"] = line[5:]
        elif cur and line.startswith("frame="):
            v = line[6:].split(",")
            # An optional 9th field names which of the images holds the frame.
            src = images.get(v[8], default_img) if len(v) > 8 else anims[cur]["image"]
            anims[cur]["frames"].append([int(x) for x in v[:8]] + [src])
    return anims

def convert_enemy(name, wanted, scale, cell, feet):
    convert(os.path.join(SRC, "animations", "enemies", name + ".txt"), os.path.join(OUT, name), wanted, scale, cell, feet)

def convert(txt, out_dir, wanted, scale, cell, feet):
    name = os.path.basename(out_dir)
    scale, cell, feet = scale * RES, cell * RES, [f * RES for f in feet]
    anims = parse(txt)
    os.makedirs(out_dir, exist_ok=True)
    meta = {"cell": cell, "feet": feet, "res": RES, "packed": True, "anims": {}}
    for anim in wanted:
        a = anims[anim]
        cache = {}
        n = a["count"]
        cells = [[Image.new("RGBA", (cell, cell)) for _ in range(n)] for _ in range(8)]
        for idx, flare_dir, x, y, w, h, ox, oy, src in a["frames"]:
            if src not in cache:
                cache[src] = Image.open(os.path.join(SRC, src)).convert("RGBA")
            # Flare dir d faces 180+45*d degrees on screen (0 = west, 2 = north,
            # see Utils::calcDirection in flare-engine); our rows start east.
            row = (flare_dir + 4) % 8
            piece = cache[src].crop((x, y, x + w, y + h))
            sw, sh = max(1, round(w * scale)), max(1, round(h * scale))
            piece = piece.resize((sw, sh), Image.LANCZOS)
            px, py = feet[0] - round(ox * scale), feet[1] - round(oy * scale)
            cells[row][idx].alpha_composite(piece, (px, py)) if px >= 0 and py >= 0 else cells[row][idx].paste(piece, (px, py), piece)
        # Pack: each frame cropped to what it shows (most of a cell is empty),
        # shelf-packed into one sheet. rects[row][frame] = [x, y, w, h, ox, oy]
        # with (ox, oy) the crop's corner inside the cell.
        crops = []
        for row in range(8):
            for f in range(n):
                b = cells[row][f].getbbox()
                crops.append((row, f, cells[row][f].crop(b) if b else None, b))
        width = min(2048, max(512, cell * 4))
        rects = [[[0, 0, 0, 0, 0, 0] for _ in range(n)] for _ in range(8)]
        x = y = shelf = 0
        placed = []
        for row, f, im, b in sorted(crops, key=lambda c: -(c[2].height if c[2] else 0)):
            if im is None:
                continue
            if x + im.width > width:
                x, y, shelf = 0, y + shelf + 2, 0
            placed.append((im, x, y))
            rects[row][f] = [x, y, im.width, im.height, b[0], b[1]]
            x += im.width + 2  # transparent gutters: no bleeding when filtered
            shelf = max(shelf, im.height)
        sheet = Image.new("RGBA", (width, max(1, y + shelf)))
        for im, px, py in placed:
            sheet.paste(im, (px, py))
        sheet.save(os.path.join(out_dir, anim + ".png"), optimize=True)
        meta["anims"][anim] = {"frames": n, "ms": a.get("ms", 500), "type": a.get("type", "looped"), "rects": rects}
    json.dump(meta, open(os.path.join(out_dir, "anims.json"), "w"), indent=1)
    return meta

# Floor tiles of each tileset (drawn by the game's TileMapLayer).
FLOOR_IDS = {
    "grass": list(range(16, 48)),
    "snow": list(range(16, 48)),
    "cave": list(range(16, 32)) + list(range(48, 56)),
    "ruins": list(range(24, 32)) + list(range(105, 120)) + list(range(153, 167)),
    "dungeon": [16, 17, 18, 19, 22, 23, 26, 29, 30] + list(range(32, 48)) + list(range(60, 64)),
}
FLOOR_CELL = (192, 112)  # floor grid cell: the tile's anchor sits at its centre
FLOOR_COLS = 10

def convert_tiles(defs, ids, scale, out_name, root=SRC):
    """Cut tiles out of a Flare tileset (a tileset may use several images) and
    pack them into atlases, so the game draws a whole biome with a couple of
    textures (one texture per tile meant ~1000 draw calls per frame):
    - atlas_<page>.png: every tile, shelf-packed;
    - floors.png: the floor tiles in a grid, each anchored at its cell centre.
    tiles.json: {"res", "tiles": {id: [page, x, y, w, h, ax, ay]},
    "floors": {id: index in the grid}, "floor_cell", "floor_cols"}."""
    tiles, cache, img = {}, {}, None
    for line in open(os.path.join(root, "tilesetdefs", defs + ".txt")):
        line = line.strip()
        if line.startswith("img="):
            path = os.path.join(root, line[4:])
            img = cache.setdefault(path, Image.open(path).convert("RGBA") if os.path.exists(path) else None)
        elif line.startswith("tile="):
            v = [int(x) for x in line[5:].split(",")[:7]]
            tiles[v[0]] = v[1:] + [img]
    out = os.path.join(OUT, "tiles", out_name)
    import shutil
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    scale *= RES
    pieces = {}
    for t in ids:
        x, y, w, h, ox, oy, im = tiles[t]
        piece = im.crop((x, y, x + w, y + h)).resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
        pieces[t] = (piece, round(ox * scale), round(oy * scale))
    meta = {"res": RES, "tiles": {}, "floors": {}, "floor_cell": list(FLOOR_CELL), "floor_cols": FLOOR_COLS}
    # Every tile, shelf-packed into pages of at most 2048 x 4096.
    W, H = 2048, 4096
    pages, page, x, y, shelf = [], [], 0, 0, 0
    for t in sorted(ids, key=lambda t: -pieces[t][0].height):
        piece, ax, ay = pieces[t]
        if x + piece.width > W:
            x, y, shelf = 0, y + shelf + 2, 0
        if y + piece.height > H:
            pages.append(page)
            page, x, y, shelf = [], 0, 0, 0
        page.append((t, x, y))
        meta["tiles"][str(t)] = [len(pages), x, y, piece.width, piece.height, ax, ay]
        x += piece.width + 2
        shelf = max(shelf, piece.height)
    pages.append(page)
    for k, pg in enumerate(pages):
        height = max(y + pieces[t][0].height for t, x, y in pg)
        sheet = Image.new("RGBA", (W, height))
        for t, px, py in pg:
            sheet.paste(pieces[t][0], (px, py))
        sheet.save(os.path.join(out, f"atlas_{k}.png"), optimize=True)
    # The floors, on a grid.
    floors = [t for t in FLOOR_IDS.get(out_name, []) if t in pieces]
    # Floors are centred in their cell (their Flare anchors are not reliable:
    # some ruins slabs have odd ones); cells tall enough for the tallest.
    cw = FLOOR_CELL[0]
    ch = max([FLOOR_CELL[1]] + [pieces[t][0].height + (pieces[t][0].height % 2) for t in floors])
    meta["floor_cell"] = [cw, ch]
    grid = Image.new("RGBA", (cw * FLOOR_COLS, ch * ((len(floors) + FLOOR_COLS - 1) // FLOOR_COLS)))
    for k, t in enumerate(floors):
        piece, ax, ay = pieces[t]
        cx, cy = (k % FLOOR_COLS) * cw, (k // FLOOR_COLS) * ch
        grid.alpha_composite(piece, (cx + (cw - piece.width) // 2, cy + (ch - piece.height) // 2))
        meta["floors"][str(t)] = k
    grid.save(os.path.join(out, "floors.png"), optimize=True)
    json.dump(meta, open(os.path.join(out, "tiles.json"), "w"), indent=1)
    print("tiles", out_name, len(ids), "pages", len(pages))

FIGHT = ["stance", "run", "swing", "hit", "die"]

# --- The modular hero (character creator) ------------------------------------
# Melee gear only (bows, staffs and wands need ranged combat, not built yet).
HERO_ANIMS = ["stance", "run", "swing", "block", "hit", "die"]
SKIP = {"greatbow", "longbow", "shortbow", "slingshot", "greatstaff", "staff", "rod", "wand"}

def convert_avatar(sex):
    folder = os.path.join(SRC, "animations", "avatar", sex)
    pieces = sorted(f[:-4] for f in os.listdir(folder) if f.endswith(".txt") and f[:-4] not in SKIP
                    and not open(os.path.join(folder, f)).read().startswith("INCLUDE"))
    # (female_dark only redraws the pieces that show skin; the game falls
    # back to the female pieces for the others.)
    for piece in pieces:
        convert(os.path.join(folder, piece + ".txt"), os.path.join(OUT, "avatar", sex, piece), HERO_ANIMS, 0.42, 160, [80, 120])
    print("avatar", sex, len(pieces), "pieces")
    return pieces

if "--avatar-only" in sys.argv:
    for sex in ["male", "female", "female_dark"]:
        convert_avatar(sex)
    sys.exit()
convert_enemy("skeleton", FIGHT + ["block"], 0.42, 160, [80, 120])
convert_enemy("zombie", FIGHT, 0.42, 160, [80, 120])
convert_enemy("minotaur", FIGHT + ["block"], 0.55, 256, [128, 190])
# Tile numbers of the Flare dungeon tileset (see tilesetdefs/tileset_dungeon.txt).
FLOORS = [16, 17, 18, 19, 22, 23, 26, 29, 30] + list(range(32, 48)) + list(range(60, 64))
# Walls come in pairs: even = textured left face, odd = textured right face.
WALLS = [64, 65, 66, 68, 69, 96, 97, 98, 99, 102, 103, 106, 107]
PROPS = [110, 111, 128, 129, 130, 131, 151, 167] + list(range(176, 184)) + [194, 197, 199, 200, 264, 265]
convert_tiles("tileset_dungeon", FLOORS + WALLS + PROPS, 0.5, "dungeon")

# --- Open world biomes (tile numbers from each tileset's definition file) ---
convert_tiles("tileset_grassland",
    list(range(16, 48)) + list(range(72, 76)) + list(range(96, 144)) + list(range(240, 256)) + [224, 227, 264, 265],
    0.5, "grass")
convert_tiles("tileset_snowplains",
    list(range(16, 48)) + list(range(344, 364)) + list(range(72, 76)) + list(range(96, 144)) + list(range(244, 248))
    + [264, 265] + list(range(532, 535)) + list(range(553, 568)), 0.5, "snow")
convert_tiles("tileset_cave",
    list(range(16, 32)) + list(range(48, 56)) + list(range(132, 136)) + list(range(144, 154)) + [160, 161, 162, 163, 264, 265],
    0.5, "cave")
convert_tiles("tileset_ruins",
    list(range(24, 32)) + list(range(105, 120)) + list(range(153, 167)) + list(range(186, 195)) + list(range(223, 235))
    + list(range(241, 247)) + list(range(274, 279)) + list(range(289, 295)) + list(range(312, 318)) + [380, 381],
    0.5, "ruins", os.path.join(sys.argv[1], "mods", "empyrean_campaign"))

# --- Open world enemies ---
for name in ["goblin", "goblin_elite", "antlion", "ice_ant", "fire_ant", "skeleton_weak"]:
    convert_enemy(name, FIGHT, 0.42, 160, [80, 120])
convert_enemy("wyvern_water", FIGHT + ["block"], 0.5, 256, [128, 190])

# --- Flare music and sounds (CC-BY-SA 3.0) ---
import re, subprocess

def normalize(src, dst, peak_db):
    """Copies a sound with its peak brought to peak_db (Flare's footsteps and
    ambiences are recorded some 30 dB lower than everything else)."""
    out = subprocess.run(["ffmpeg", "-i", src, "-af", "volumedetect", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    gain = peak_db - float(re.search(r"max_volume: ([-0-9.]+)", out).group(1))
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-af", f"volume={gain:.1f}dB",
                    "-c:a", "libvorbis", "-q:a", "4", dst], check=True)

SND = os.path.join(os.path.dirname(__file__), "..", "assets", "flare_audio")
for sub in ["music", "soundfx", "soundfx/enemies", "soundfx/environment", "soundfx/steps", "soundfx/powers"]:
    src = os.path.join(SRC, sub)
    dst = os.path.join(SND, sub)
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(src):
        if not f.endswith(".ogg") or f.startswith(("title", "town")):
            continue
        if sub == "music":  # re-encoded lighter for the web build (~64 kbit/s)
            import subprocess
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", os.path.join(src, f),
                            "-c:a", "libvorbis", "-q:a", "0", os.path.join(dst, f)], check=True)
        else:
            normalize(os.path.join(src, f), os.path.join(dst, f), -10.0 if "_loop" in f else -2.0)
print("audio copied")
