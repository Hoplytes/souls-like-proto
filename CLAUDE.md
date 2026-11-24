# Souls-like Proto — notes for Claude

- Talk to the user in French.
- The game is played at https://hoplytes.github.io/souls-like-proto/ (the
  version shown in its bottom-right corner is the short commit id). The user
  no longer wants this link repeated at the end of every answer: give it only
  when it is useful, e.g. after publishing a change worth trying.
- Every push to `main` rebuilds and publishes the web version (GitHub Actions,
  about 3 minutes). Remind the user to reload with Ctrl+F5 after an update.
- Godot 4.5, GDScript. Smoke test with screenshots:
  `xvfb-run -a godot --rendering-driver opengl3 -- --autotest=<folder>`
  (the game starts in the character creator; test runs skip it)
  (see `tools/autotest.gd`). `--test=res://tools/<script>.gd` runs another
  scenario instead (a script extending autotest.gd, e.g. for one check).
- Progress (souls, level, bonfires, bosses, items, bloodstain) is saved in
  `user://save.json` by `scripts/progress.gd`; test runs never touch it.
- Licensed (paid) art lives in the PRIVATE repo Hoplytes/souls-like-assets,
  checked out into `local/` (git-ignored here) by the web build using the
  `ASSETS_TOKEN` secret. Never commit licensed files to this public repo.
- Scenery, hero and enemies come from SmallScaleInt's paid "Fantasy tileset -
  2D Isometric" (`tools/convert_fantasy.py` -> local/fantasy/, private repo;
  the zip is attached to its `tileset-fantasy` release). Bosses, music and
  sounds come from Flare (CC-BY-SA 3.0, `tools/convert_flare.py`); other
  sounds are synthesised (`tools/make_sfx.py`) or CC0 / CC BY: keep the
  CREDITS-*.md files up to date when adding assets.
