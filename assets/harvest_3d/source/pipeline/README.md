# Harvest sprite pipeline

One studio, one recipe per asset, one command. It reproduces every crop the
game ships to the pixel (0 or 1 differing pixels of 262,144, measured against
`../../crops/*.png`), so it can replace the fifteen one-off Blender scripts
that produced them: those scripts carry thirteen cameras between them and no
two candidates were guaranteed to sit on the same ground line.

It runs wherever Blender's Python runs. On the Mac that is Blender itself; in
the sandbox it is `pip install bpy` (Blender 5.0 as a Python module, CPU
Cycles, 47 s for all nineteen sprites on four cores). The audit and the
self-test need only Pillow.

## Files

| | |
|---|---|
| `contract.json` | the numbers: 512 px, pivot (256, 467), span 2.60 m, the frozen profile's hash, audit tolerances; the old sprite-pack rig under `legacy` |
| `palette.json` | every material the models use, by key (`M['leaf']`) |
| `studio.py` | Blender side: opens the frozen profile (world, Sun key, two Area lights, Standard view at −0.2 EV), keeps only its camera and lamps, frames the camera so the world origin lands on the pivot, and offers the primitives, the optional baked shadow, mesh repair, render and GLB |
| `models/<name>.py` | geometry only: `build(S, P)`; `S` is the studio, `P` the recipe's params. `from_glb.py` imports existing geometry instead |
| `recipes/<id>.json` | which model, which params, shadow policy, optional `ortho_scale`, where it installs |
| `build.py` | walks the recipes, renders, writes `manifest.json`, runs the audit |
| `audit.py` | no Blender: size, alpha, ground line, footprint, fringe, contact sheet |
| `test_pipeline.py` | recipes ↔ `data/harvest_crops.json` ↔ `harvest_visual_art.gd`, audit on the shipped PNGs, break-it-once |

## Run it

```bash
cd /opt/heroesIsland                                   # or the sandbox checkout
P=assets/harvest_3d/source/pipeline
blender -b -P $P/build.py -- --only carrot             # Mac: one asset
python3 $P/build.py -- --only carrot                   # sandbox, after: pip install bpy pillow
python3 $P/build.py                                    # all 19 → source/rendered/
python3 $P/build.py -- --install                       # and copy into ../../crops, ../../props
python3 $P/build.py -- --glb --blend                   # also GLBs and the .blend
python3 $P/build.py -- --rig legacy                    # the old softbox look, for comparison
python3 $P/audit.py assets/harvest_3d/crops            # audit what the game ships
python3 $P/test_pipeline.py                            # the self-test
```

Output lands in `source/rendered/` (git-ignored): `sprites/<id>.png`,
`manifest.json`, `contact_sheet.png`. A failing audit is a failing build: the
renders stay on disk for a look, nothing is installed.

## What the shipped art actually is (found while matching it)

- **Rig.** Every crop was rendered on 3 October through
  `catalog_profile_candidate/inputs/frozen_render_profile.blend`: the
  whole-plant review scene's sky, Sun key 1.1, Area fill 240, Area rim 180,
  Standard view transform at −0.2 EV, Cycles 24 samples. Not `build_pack.py`'s
  warm softbox and AgX, which is what the checked-in `harvest_sprite_pack.blend`
  renders as. The studio opens that profile and checks its SHA-256.
- **Geometry.** Fifteen crops are the sprite-pack models unchanged; `carrot`
  and `golden_carrot` are the long-root candidate; `strawberry` is the
  readability pass (wider shoulder, lifted crown, fourteen seeds on the camera
  side). All three are now models here; the strawberry builds the result
  directly instead of editing the old mesh.
- **Shadows.** The catalog exporter hid the sprite pack's radial shadow mesh,
  but the hidden mesh still rendered: every shipped crop carries a faint
  (≈22 % alpha) contact shadow below the ground line, which is why their alpha
  boxes reach row 486 while the solid pixels stop at 467. Two exceptions: the
  strawberry (its source deleted the mesh) and the broccoli (no shadow made it
  into the PNG). The recipes say so per asset, and the runtime's default of
  "crops have a baked shadow" is therefore true.
- **Props.** `basket_empty` is the whole-plant basket GLB (the same file the
  runtime ships) at its own 1.94 m span; the recipe uses `from_glb` plus
  `ortho_scale`. `soil_cover` still comes from the frozen GLB profile in
  `soil_cover_candidate/`. `soil_grass_patch` had no recorded source and was lit by
  the old softbox rig (muddy soil, dark grass, nothing like the crops standing
  on it); it was re-rendered through the frozen profile and installed, so the
  whole set now shares one light.

| sprite | differing pixels vs shipped |
|---|---|
| apple, bug, corn, golden_carrot, lettuce, orange, potato, stone, strawberry, watermelon | 0 |
| broccoli, carrot, grape, peas, pumpkin, tomato, wheat | 1 |
| basket_empty | 344 (same alpha box; shading noise) |
| soil_grass_patch | replaced on purpose: the old PNG came from the other rig |
| tree, hedge, stones, tuft, sprig_yellow/pink/lilac | new on 4 October: the farm's scenery, drawn by `farm_world_art.gd` |
| building_* (13), fence, fence_y, dog, bear | new on 4 October: the facilities, the fence, the dog and the neighbour; deep footprints use `origin_offset` and `deep_footprint` |
| tree_pine, tree_fruit, bush_flower, flowerbed, mushrooms, log, hay_bale, wheelbarrow, scarecrow, windmill, windmill_blades, pond, duck, chicken, signpost, bench, butterfly, butterfly_blue | new on 4 October: the dressing in `data/farm_world_dressing.json`; `floats` marks the two that never touch the ground |

## Buildings and animals

A building is modelled about its own centre with `S.block / S.cyl / S.cone /
S.roof`, door on the camera side (negative y, positive x). Its recipe then
sets `"origin_offset"` to slide it straight back from the camera, direction
(−0.56, 0.83), by about half its depth, so the FRONT edge of the footprint
stands on the ground pivot; the farm anchors a facility at the bottom of its
box and scales it to the box width. `"deep_footprint": true` tells the audit
that the nearest corner, not the centre, is what touches the ground line.
Spans run 3.4 to 4.8 m for buildings, 2.6 for the dog, 3.4 for the bear.

A ground patch (soil_grass_patch, clearing, meadow_patch) is its own
ground: no radial shadow (it would reach the canvas edge in front), and the
newer two are slid back like a building so the farm anchors them by their
front rim. `build.py` audits before it installs; a failing sprite never
reaches the game.

## Add an asset

1. `models/pear.py` with `def build(S, P):` using `S.uv / S.lathe / S.leaf /
   S.tube / S.fruit_mesh / S.mesh` and `S.M['...']`; or hand over a GLB and use
   `"model": "from_glb"`. World origin is the ground contact.
2. `recipes/pear.json`:
   ```json
   {"id": "pear", "kind": "crop", "model": "pear", "params": {},
    "shadow": {"baked": true, "size": [0.38, 0.26]}, "install": "crops/pear.png"}
   ```
   A colour variant is a recipe, not a model: `golden_carrot.json` is
   `carrot` with `{"golden": true}`. An asset that needs its own frame adds
   `"ortho_scale": 1.94`.
3. Add the id to `data/harvest_crops.json` and to `CROP_IDS` in
   `scripts/harvest/harvest_visual_art.gd`; `test_pipeline.py` and
   `tools_check.py` fail until all three agree.
4. `build.py -- --only pear --install`, look at the contact sheet, commit the
   PNG with the recipe and model.

New colour for everything green: edit `palette.json`, rebuild. No model
changes.

## The contract, in one paragraph

Every sprite is 512 × 512 straight-alpha RGBA from the frozen profile's
orthographic camera at a 2.60 m span unless the recipe says otherwise. The
world origin projects to pixel (256, 467); `studio.py` refuses to render if
it does not, and `harvest_visual_art.gd` anchors by the same number
(`GROUND_ORIGIN_PIXEL_Y`). Wide objects extend a little below that row in a
3/4 view; the audit allows rows 427..503 and a footprint centre within 90 px
of the pivot column. `"shadow": {"baked": true}` renders the short radial
contact shadow into the alpha; `false` means the runtime draws
`Shapes.ground_shadow`, and the install step writes `<id>.json` with
`contact_shadow_baked: false` for a prop so the game never draws two.

## What this does not decide

Whether the farm goes runtime-3D. The GLB export is there (`--glb`) so the
same geometry can feed either answer, but the game today loads only the PNGs,
and the fifteen runtime trials recorded in
`docs/GARDEN_HARVEST_3D_EVOLUTION_PLAN.md` were all rejected by the art gate.
