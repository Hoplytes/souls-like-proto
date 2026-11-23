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
  (see `tools/autotest.gd`).
- Licensed (paid) art lives in the PRIVATE repo Hoplytes/souls-like-assets,
  checked out into `local/` (git-ignored here) by the web build using the
  `ASSETS_TOKEN` secret. Never commit licensed files to this public repo.
- Art comes from LPC (`tools/compose_lpc.py`, `tools/extract_env.py`), sounds
  are synthesised (`tools/make_sfx.py`) or CC0 / CC BY: keep the CREDITS-*.md
  files up to date when adding assets.
