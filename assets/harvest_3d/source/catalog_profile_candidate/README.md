# Catalog renders from the frozen shared profile

**Status: frozen-profile source archive, adopted in the formal runtime on 2026-10-03. The original candidate manifests below are historical. Formal interaction passed 1584 checks in the original integration snapshot, then 1706 checks after orchard/strawberry polish. Native badge checks cover 24/32/48/72/96px and 85 rendered cells; actual-page review is recorded separately.**

The 17 input assets were rendered with the same frozen World, Sun/Area light data, color management, Cycles settings and camera direction as the shared environment candidate. Their physical proportions, geometry, material assignments and world matrices were preserved. Fifteen assets use the original catalog geometry; `carrot` and `golden_carrot` use the previously archived long-root candidates.

## Files

- `export_catalog.py` — self-contained Blender exporter copied verbatim from the completed pipeline, including Sun/Area validation and the Blender 5.2 check for an actual enabled compositor graph.
- `catalog_profile_editable.blend` — editable catalog geometry, its materials and the shared render rig; asset collections are hidden until selected for rendering.
- `sprites/` — all 17 completed 512 × 512 RGBA renders.
- `inputs/frozen_render_profile.blend` — an exact byte copy of the profile used for this render. Its SHA is `4facaae15f88401f4f7553f12d4ec1e441e2a9597196b38a0b6a6b6fe2ea5512`. Keeping this small snapshot allows the surrounding environment source to receive later geometry edits without losing this run's render profile.
- `manifest.json` — the completed run's manifest, preserved verbatim: rig data, camera matrices, source object hashes, per-asset projection/alpha audits and output hashes. Absolute paths in it are historical provenance.
- `provenance.json` — archive status, repository-relative rebuild dependencies and the exact frozen profile hash.
- `render.log` — the completed Blender render output, preserved as evidence.
- `SHA256SUMS` — checksums of all archived files except the checksum file itself.
- `.gdignore` — excludes the source candidate and all its assets from Godot import and packaging.

## Rebuild inputs

The exporter accepts explicit `--source-blend`, `--carrot-blend`, `--profile-blend`, `--out`, and optional manifest/scene/camera arguments. It has no dependency on the original temporary directories.

Relative to this folder:

| Input | Path | SHA256 |
| --- | --- | --- |
| Original catalog | `../harvest_sprite_pack.blend` | `2dd8b2baabb50b610484b5876a904361005e1503f19b966954917a454f8bda91` |
| Original source contract | `../manifest.json` | `24e29d69ab0bc35fb9618ab56c0186333db17066d162cd0e4e768f3c2fb60902` |
| Long-root pair | `../carrot_shape_candidate/harvest_sprite_pack.blend` | `c9973e236dff542ee164f91d4ecbad893e1042db864b10e259c33ddfa721d26e` |
| Frozen shared profile | `inputs/frozen_render_profile.blend` | `4facaae15f88401f4f7553f12d4ec1e441e2a9597196b38a0b6a6b6fe2ea5512` |

The first two asset blends already exist in adjacent source directories and are reused without another copy. The archive including its frozen profile is about 4.7 MB.

## Rebuild command

From this directory, with Blender 5.2.2 LTS or a compatible version:

```sh
Blender --background --factory-startup --disable-autoexec --python export_catalog.py -- \
  --source-blend ../harvest_sprite_pack.blend \
  --source-manifest ../manifest.json \
  --carrot-blend ../carrot_shape_candidate/harvest_sprite_pack.blend \
  --profile-blend inputs/frozen_render_profile.blend \
  --expect-profile-sha256 4facaae15f88401f4f7553f12d4ec1e441e2a9597196b38a0b6a6b6fe2ea5512 \
  --require-light-types SUN,AREA,AREA \
  --require-view-transform Standard --require-exposure -0.20 \
  --out /absolute/path/to/a/new/catalog-render --render --save-blend
```

Replace `Blender` with its executable path where needed. Omitting `--render` runs inspection only. Repeating `--asset potato --asset bug` can render a subset for diagnostics. Use a new output directory to preserve this snapshot; do not use this candidate folder as the output.

## Render and shadow contract

- Each asset keeps its input Blender world scale. The shared orthographic span is 2.60 m; there is no automatic crop scaling or per-asset fitting.
- The transparent 512² canvas uses world `(0,0,0)` at pixel `(256,467)`. The measured pivot for this run is `(255.999908,466.999973)`.
- The frozen profile uses Standard exposure −0.20, one Sun and two Area lights, with its original ambient World and complete World node tree.
- Native geometry includes 241 Mesh and 78 Curve objects. Curve stems remain editable Curves; they were only evaluated temporarily for the projection audit.
- All 17 original `Shadow | ...` objects were excluded. `contact_shadow_baked=false`; the existing runtime `Shapes.ground_shadow` remains the contact-shadow owner.
- No old basket/soil-grass prop, environment geometry or fixed demonstration soil marks were included in the rendered PNGs.

## Evidence and limits

The completed offline run contains all 17 PNGs. Every evaluated vertex projection stays within the canvas, and all PNGs pass the recorded visible/solid edge checks. The manifest includes alpha bounds and four-edge pixel counts at thresholds 0.001, 0.05 and 0.95; this includes the potato lower edge instead of relying only on a valid ground pivot. Source geometry/material assignment/world matrix fingerprints were checked before and after rendering.

Those checks establish the offline export contract. They do not establish whole-page visual quality, runtime crop interaction or performance acceptance. The source folder stays excluded from Godot. Its rendered PNGs were copied to the existing runtime artwork paths. The formal snapshot, subsequent polish and their scope are recorded in `provenance.json` and `docs/HARVEST_RUNTIME_QA_20261002.md`; subsequent strawberry source revisions do not overwrite this frozen catalog archive.
