"""Write CREDITS-LPC.md for the LPC layers used by compose_lpc.py.
Run: python3 tools/lpc_credits.py <LPC-repo>/CREDITS.csv"""
import csv, os, sys
USED = ["body/bodies/male/", "body/bodies/muscular/", "body/bodies/skeleton/", "head/heads/human/male/",
        "head/heads/orc/male/", "hair/plain/adult/", "torso/armour/plate/male/",
        "legs/armour/plate/male/", "feet/armour/plate/male/", "arms/armour/plate/male/",
        "weapon/sword/arming/", "weapon/polearm/spear/"]
groups = {}
for row in csv.DictReader(open(sys.argv[1], encoding="utf-8")):
    fn = row["filename"].strip()
    for u in USED:
        if fn.startswith(u):
            key = tuple(row[k].strip() for k in ("authors", "licenses", "urls", "notes"))
            groups.setdefault(key, set()).add(u)
out = ["# Credits: Liberated Pixel Cup (LPC) art", "",
       "Character, armour and weapon sprites come from the",
       "[Universal LPC Spritesheet Character Generator](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator).",
       "They were combined into sheets by `tools/compose_lpc.py` (the orc body was recoloured).",
       "Each piece may be used under any one of the licences listed for it.", ""]
for (authors, licenses, urls, notes), parts in sorted(groups.items(), key=lambda kv: sorted(kv[1])[0]):
    out += [f"## {', '.join(sorted(parts))}", "", f"- Authors: {authors}", f"- Licences: {licenses}"]
    if notes: out.append(f"- Notes: {notes}")
    out += ["- Sources: " + ", ".join(u.strip() for u in urls.split(",") if u.strip()), ""]
# The credits table lists faces under a "${head}" placeholder; this entry is
# copied from sheet_definitions/head/faces/face_neutral.json ("head/faces/male/neutral").
out += ["## head/faces/male/neutral/", "", "- Authors: JaidynReiman, Stephen Challener (Redshrike)",
        "- Licences: OGA-BY 3.0, CC-BY-SA 3.0, GPL 3.0",
        "- Notes: Original by Redshrike, spellcast and jump overrides by JaidynReiman",
        "- Sources: https://opengameart.org/content/liberated-pixel-cup-lpc-base-assets-sprites-map-tiles, https://opengameart.org/content/ulpc-expanded-expressions", ""]
open(os.path.join(os.path.dirname(__file__), "..", "CREDITS-LPC.md"), "w", encoding="utf-8").write("\n".join(out))
print(len(groups), "credit groups")
