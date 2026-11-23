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
    anims = parse(os.path.join(SRC, "animations", "enemies", name + ".txt"))
    os.makedirs(os.path.join(OUT, name), exist_ok=True)
    meta = {"cell": cell, "feet": feet, "anims": {}}
    for anim in wanted:
        a = anims[anim]
        cache = {}
        n = a["count"]
        sheet = Image.new("RGBA", (n * cell, 8 * cell))
        for idx, flare_dir, x, y, w, h, ox, oy, src in a["frames"]:
            if src not in cache:
                cache[src] = Image.open(os.path.join(SRC, src)).convert("RGBA")
            # Flare dir d faces 180+45*d degrees on screen (0 = west, 2 = north,
            # see Utils::calcDirection in flare-engine); our rows start east.
            row = (flare_dir + 4) % 8
            piece = cache[src].crop((x, y, x + w, y + h))
            sw, sh = max(1, round(w * scale)), max(1, round(h * scale))
            piece = piece.resize((sw, sh), Image.LANCZOS)
            px = idx * cell + feet[0] - round(ox * scale)
            py = row * cell + feet[1] - round(oy * scale)
            sheet.alpha_composite(piece, (px, py)) if px >= 0 and py >= 0 else sheet.paste(piece, (px, py), piece)
        sheet.save(os.path.join(OUT, name, anim + ".png"), optimize=True)
        meta["anims"][anim] = {"frames": n, "ms": a.get("ms", 500), "type": a.get("type", "looped")}
    json.dump(meta, open(os.path.join(OUT, name, "anims.json"), "w"), indent=1)
    print("enemy", name, list(meta["anims"]))

def convert_tiles(tileset, ids, scale):
    path = os.path.join(SRC, "tilesetdefs", tileset + ".txt")
    img = None
    tiles = {}
    for line in open(path):
        line = line.strip()
        if line.startswith("img="):
            img = Image.open(os.path.join(SRC, line[4:])).convert("RGBA")
        elif line.startswith("tile="):
            v = [int(x) for x in line[5:].split(",")[:7]]
            tiles[v[0]] = v[1:]
    os.makedirs(os.path.join(OUT, "tiles"), exist_ok=True)
    meta = {}
    for t in ids:
        x, y, w, h, ox, oy = tiles[t]
        piece = img.crop((x, y, x + w, y + h)).resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
        piece.save(os.path.join(OUT, "tiles", f"{t}.png"), optimize=True)
        meta[str(t)] = [round(ox * scale), round(oy * scale)]
    json.dump(meta, open(os.path.join(OUT, "tiles", "anchors.json"), "w"), indent=1)
    print("tiles", len(ids))

FIGHT = ["stance", "run", "swing", "hit", "die"]
convert_enemy("skeleton", FIGHT + ["block"], 0.42, 160, [80, 120])
convert_enemy("zombie", FIGHT, 0.42, 160, [80, 120])
convert_enemy("minotaur", FIGHT + ["block"], 0.55, 256, [128, 190])
# Tile numbers of the Flare dungeon tileset (see tilesetdefs/tileset_dungeon.txt).
FLOORS = [16, 17, 18, 19, 22, 23, 26, 29, 30] + list(range(32, 48)) + list(range(60, 64))
# Walls come in pairs: even = textured left face, odd = textured right face.
WALLS = [64, 65, 66, 68, 69, 96, 97, 98, 99, 102, 103, 106, 107]
PROPS = [110, 111, 128, 129, 130, 131, 151, 167] + list(range(176, 184)) + [194, 197, 199, 200, 264, 265]
convert_tiles("tileset_dungeon", FLOORS + WALLS + PROPS, 0.5)
