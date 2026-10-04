# Long-root carrot shape candidates

**Status: source candidate archive. These assets have not passed whole-page art acceptance and do not replace the runtime `assets/harvest_3d/crops/` PNGs.**

This pair was derived from `../build_pack.py`. It preserves that pack's shared fixed 3/4 orthographic camera, softbox lighting, AgX treatment and Blender world-ground pivot. Only the normal and golden carrot shape/materials were refined. Parent `source/.gdignore` and the local `.gdignore` keep these source assets out of Godot import and packaging.

## Files

- `build_carrots.py` — self-contained Blender build script; default output is the relative `rendered/` directory beside the script. `HARVEST_SPRITE_PACK_OUT` can override the output directory.
- `harvest_sprite_pack.blend` — editable source containing both candidate collections and the original shared render rig.
- `carrot.glb`, `golden_carrot.glb` — standalone model geometry; sprite-only alpha contact shadows are excluded.
- `sprites/carrot.png`, `sprites/golden_carrot.png` — 512 × 512 RGBA render outputs.
- `manifest.json` — render and shared ground-pivot contract.
- `png_audit.json`, `glb_audit.json` — previously generated read-only artifact inspections, preserved verbatim; paths in the GLB evidence refer to the original isolated candidate directory.
- `review_72_dense.png` — offline compositing review at 72 display size and 92px horizontal center spacing.
- `provenance.json` — archive origin, tool/version, status and reference source metadata.
- `SHA256SUMS` — SHA256 hashes of the saved sources, evidence and outputs, excluding the checksum file itself.

## Rebuild

Use Blender 5.2+ with the saved script:

```sh
Blender --background --python build_carrots.py
```

For another output location:

```sh
HARVEST_SPRITE_PACK_OUT=/absolute/output/path Blender --background --python build_carrots.py
```

No rebuild or test was run while archiving this candidate. Existing generated files were copied from the isolated production directory.

## Geometry and review limits

- Root profile is 1.556 world units high with a maximum diameter of 0.436. The tip touches world `z=0`.
- Both models retain the shared ground projection `(256,467)` in the 512px canvas, 211px below its center. Do not auto-trim before applying this pivot.
- The longer taper, mild hand-grown curvature, three shallow growth creases and taller green crown give the pair a clearer carrot silhouette. Normal uses matte orange; golden uses honey gold without metallic shading.
- Solid model pixels (alpha > 0.5) occupy `(194,82)..(347,467)` for both sprites. The existing display contract draws a 144px transparent canvas at `size=72`, yielding approximately `43.3 × 108.6px` of solid crop geometry.
- The offline review shows clear long-root recognition and no horizontal overlap at 92px spacing. It does not establish Godot screenshot quality, gesture alignment, vertical row safety or whole-page cohesion.
- The candidate is taller than the original. Actual 18-target, 16:9, 4:3 and held-state screenshots must check vertical overlap and interaction cues before runtime replacement.
- Each GLB has 11 nodes, 10 mesh primitives, 10,972 triangles and 5 simple PBR materials, with no textures, cameras, lights or glTF extensions.

This save changes source archive files only. Runtime crop images and gameplay are unchanged.
