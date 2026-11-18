# Souls-like Proto — notes for Claude

- Talk to the user in French.
- **At the end of every finished answer, give the link to the game:**
  https://hoplytes.github.io/souls-like-proto/ (and the version shown in the
  bottom-right corner of the game, i.e. the short commit id, when it changed).
- Every push to `main` rebuilds and publishes the web version (GitHub Actions,
  about 3 minutes). Remind the user to reload with Ctrl+F5 after an update.
- Godot 4.5, GDScript. Smoke test with screenshots:
  `xvfb-run -a godot --rendering-driver opengl3 -- --autotest=<folder>`
  (see `tools/autotest.gd`).
- Art comes from LPC (`tools/compose_lpc.py`, `tools/extract_env.py`), sounds
  are synthesised (`tools/make_sfx.py`) or CC0 / CC BY: keep the CREDITS-*.md
  files up to date when adding assets.
