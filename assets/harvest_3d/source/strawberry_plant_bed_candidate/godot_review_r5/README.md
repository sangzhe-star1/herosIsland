# Strawberry r5: isolated Godot review

This folder records the current in-game review of the source-only r5 strawberry
plant. It is a review candidate, not a production asset approval. The formal
`HarvestAction` scene and its 2D target, touch, basket, and order owners were not
changed.

## What was rendered

The screenshots use the real `harvest_02` level through
`tests/Harvest3DIntegratedPilot.tscn`, with its normal 14 `HarvestTarget` nodes
and two baskets. The pilot replaces only visible 3D art. `HarvestTarget` still
owns picking and hit testing; the original basket and order code still owns
sorting and delivery.

| State | 16:9 | 4:3 |
| --- | --- | --- |
| Current page baseline | [1280×720](harvest-02-baseline-16x9.png) | [1024×768](harvest-02-baseline-4x3.png) |
| r5 strawberry body, ordinary | [1280×720](r5-plant-normal-16x9.png) | [1024×768](r5-plant-normal-4x3.png) |
| r5 strawberry body, held | [1280×720](r5-plant-held-16x9.png) | [1024×768](r5-plant-held-4x3.png) |
| r5 strawberry body, delivered | [1280×720](r5-plant-delivery-16x9.png) | [1024×768](r5-plant-delivery-4x3.png) |
| Rejected continuous-bed alternative | [1280×720](r5-bed-rejected-16x9.png) | — |

All pilot screenshots came from separate `tests/qa_run.py` temporary projects.
The pilot enables reduced motion. The held and delivery runs use the existing
gesture path; both aspect ratios logged a successful strawberry delivery to
the fruit basket, with the order advancing from 0/4 to 1/4. Each run reported
visible image content and `save=OK`.

## Asset and render checks

- Plant source: `rendered_r5/strawberry_plant.glb`, Blender 5.2.2 LTS,
  4,026 triangles, 4 materials, no textures, and the named `FruitSlot` node.
- Plant SHA-256: `6a9de7eb7362e73b60d490fc9aaf02c363b33b681dafad7a62149e3b1cc4d349`.
- Godot 4.7.1 Compatibility renderer loaded the GLB with `GLTFDocument` and
  rendered it in all six states above.
- The read-only GLB structure audit found one scene root, no duplicate node
  names, no unreachable nodes, and the expected fruit slot. It reports 4,026
  scene triangles and 5 potential material primitives.
- Rebuilding with the checked-in Blender script reproduces the bed GLB hash
  exactly. The plant rebuild has identical vertex positions, normals, and
  oriented triangle sets, but Blender changes the order of one mesh's triangle
  index list, so the complete GLB byte hash differs. This does not change the
  rendered geometry.

## Visual decision

The separate rosette body gives the current fruit a visible plant and remains
in place after picking, while the fruit travels through the existing hold and
basket route. This makes it the better of the two strawberry candidates tested
here.

The r5 continuous bed is rejected: in the real level composition it reads as
one broad brown slab, and its root coverage misses one of the fourteen crop
anchors. The rejected comparison is retained above so that it is not mistaken
for the plant-only option.

The plant-only result remains a local 3D art candidate. The 4:3 page still has
substantial open meadow, and the mixed 2D HUD/3D art page needs a broader visual
pass. These screenshots prove rendering and the existing pick/delivery path;
they do not prove children's recognition, device performance, or approval to
replace the formal page.

## Re-run the candidate

From the repository root, replace the screenshot path and window size as
needed. Add `PILOT_HELD=1` to capture the held state; also add
`PILOT_DELIVER=1` to send that strawberry into the existing fruit basket.

```sh
SHOT_WINDOW=1280x720 \
SHOT_PATH=/tmp/strawberry-r5.png \
PILOT_STRAWBERRY_PLANT=1 \
PILOT_STRAWBERRY_BODY_GLB=res://assets/harvest_3d/source/strawberry_plant_bed_candidate/rendered_r5/strawberry_plant.glb \
python3 tests/qa_run.py --name strawberry-r5-review \
  --timeout 240 --expect "3D integrated pilot image=" -- \
  --rendering-driver opengl3 res://tests/Harvest3DIntegratedPilot.tscn
```
