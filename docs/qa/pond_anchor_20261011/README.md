# Pond anchor shots — 11 October 2026

These screenshots were rendered by `tests/FarmShot.tscn` through the isolated
`tests/qa_run.py` runner with `SHOT_FOCUS_FACILITY=pond`. `FarmShot` now gets the
camera target from `FarmPondManager.pond_center()`, the same data-backed anchor
used by the fishing zone, ripple ring, and fish receipt flight.

Both renders used Godot 4.7.1 Compatibility on macOS and completed with
`farm_shot -> OK`:

- `pond_focus_16x9.png`: 1280×720
- `pond_focus_4x3.png`: 1024×768

The pond is visible near the center of each farm view. The screenshots cover
the standard dressing coordinates; the real-touch probe separately moves the
pond and verifies the new hit area and receipt origin in both view shapes.
