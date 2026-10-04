# Harvest sprite pipeline

One studio, one recipe per asset, one command. This replaces the habit of
copying the camera and lights into a new Blender script for every candidate:
fifteen scripts in `source/` carry thirteen cameras between them, and no two
candidates were guaranteed to sit on the same ground line.

It runs on the Mac with Blender. The sandbox has no Blender and no GPU; it
can only run the audit and the self-test, which is why both are plain Python.

## Files

| | |
|---|---|
| `contract.json` | the numbers: 512 px, pivot (256, 467), camera, light, render, audit tolerances |
| `palette.json` | every material the models use, by key (`M['leaf']`) |
| `studio.py` | Blender side: scene, camera, softbox, palette, primitives, baked shadow, render, GLB |
| `models/<name>.py` | geometry only: `build(S, P)`; `S` is the studio, `P` the recipe's params |
| `recipes/<id>.json` | which model, which params, shadow policy, where it installs |
| `build.py` | walks the recipes, renders, writes `manifest.json`, runs the audit |
| `audit.py` | no Blender: size, alpha, ground line, footprint, fringe, contact sheet |
| `test_pipeline.py` | recipes ↔ `data/harvest_crops.json` ↔ `harvest_visual_art.gd`, audit, break-it-once |

## Run it

```bash
cd /opt/heroesIsland
blender -b -P assets/harvest_3d/source/pipeline/build.py -- --only carrot   # one
blender -b -P assets/harvest_3d/source/pipeline/build.py                    # all 19
blender -b -P assets/harvest_3d/source/pipeline/build.py -- --install       # and copy into ../../crops, ../../props
blender -b -P assets/harvest_3d/source/pipeline/build.py -- --glb --blend   # also GLBs and the .blend
python3 assets/harvest_3d/source/pipeline/audit.py assets/harvest_3d/crops  # audit what the game ships
python3 assets/harvest_3d/source/pipeline/test_pipeline.py                  # the self-test
```

Output lands in `source/rendered/` (`sprites/<id>.png`, `manifest.json`,
`contact_sheet.png`). `build.py` ends by running `audit.py` with the system
`python3` (Blender's python has no Pillow; `pip install pillow` once). A
failing audit is a failing build: the renders stay on disk for a look, nothing
is installed.

The first run should be compared against the PNGs already in `../../crops`:
the models were moved out of `build_pack.py` verbatim and the studio carries
the same camera, so the diff should be noise. If it is not, the studio is
wrong, not the model.

## Add an asset

1. `models/pear.py` with `def build(S, P):` using `S.uv / S.lathe / S.leaf /
   S.tube / S.fruit_mesh / S.mesh` and `S.M['...']`. World origin is the
   ground contact; roughly one Blender unit tall reads right at 90 px.
2. `recipes/pear.json`:
   ```json
   {"id": "pear", "kind": "crop", "model": "pear", "params": {},
    "shadow": {"baked": true, "size": [0.38, 0.26]}, "install": "crops/pear.png"}
   ```
   A colour variant is a recipe, not a model: `golden_carrot.json` is
   `carrot` with `{"golden": true}`.
3. Add the id to `data/harvest_crops.json` and to `CROP_IDS` in
   `scripts/harvest/harvest_visual_art.gd`; `test_pipeline.py` fails until all
   three agree.
4. `build.py -- --only pear --install`, look at the contact sheet, commit the
   PNG with the recipe and model.

New colour for everything green: edit `palette.json`, rebuild. No model
changes.

## The contract, in one paragraph

Every sprite is 512 × 512 straight-alpha RGBA from a fixed 3/4 orthographic
camera (`ortho_scale` 2.60). The world origin projects to pixel (256, 467);
`studio.py` refuses to render if it does not, and `harvest_visual_art.gd`
anchors by the same number (`GROUND_ORIGIN_PIXEL_Y`). Wide objects extend a
little below that row in a 3/4 view; the audit allows rows 427..503 and a
footprint centre within 90 px of the pivot column. A recipe with
`"shadow": {"baked": true}` gets the short radial contact shadow in its alpha
(the sprite-pack look); `false` means the runtime draws `Shapes.ground_shadow`
and the install step writes `<id>.json` with `contact_shadow_baked: false` so
the game never draws two. `soil_cover` is still produced by the frozen GLB
profile in `soil_cover_candidate/`, not by a recipe; it is the next one to
move once the 3D stop line (PLAN.md, open decision 4) is settled.

## What this does not decide

Whether the farm goes runtime-3D. The GLB export is there (`--glb`) so the
same geometry can feed either answer, but the game today loads only the PNGs,
and the fifteen runtime trials recorded in
`docs/GARDEN_HARVEST_3D_EVOLUTION_PLAN.md` were all rejected by the art gate.
