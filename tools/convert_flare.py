"""Convert Flare (github.com/flareteam/flare-game, CC-BY-SA 3.0) bosses
(Minotaur, wyvern: one packed sheet per animation, 8 rows E, SE, S, SW, W,
NW, N, NE) and copy its music and sounds.
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

FIGHT = ["stance", "run", "swing", "hit", "die"]

# Only the two bosses and the sounds are still used (the scenery, the hero
# and the other enemies come from SmallScaleInt's pack, tools/convert_fantasy.py).
convert_enemy("minotaur", FIGHT + ["block"], 0.55, 256, [128, 190])
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
