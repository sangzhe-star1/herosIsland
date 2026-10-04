# Runtime crop mesh candidates

`crops/<id>.glb` contains one mesh export for every entry in
`data/harvest_crops.json` (17 crop and clutter IDs). The meshes were exported
from the frozen `assets/harvest_3d/source/harvest_sprite_pack.blend` by
`source/runtime_mesh_catalog_candidate/export_catalog_glb.py`. The exporter
omits the offline radial shadow planes and preserves the source models'
material colors and pivot transforms.

Source hashes, byte sizes, mesh counts, and triangle counts are recorded in
`source/runtime_mesh_catalog_candidate/catalog_manifest.json`. The 17 files
total about 3.1 MB and 149,492 triangles. They currently remain candidates:
normal Godot import coverage does not prove their full-page composition or
visual approval. The `HarvestRuntimeImportProbe` checks these candidates as
`PackedScene` resources alongside the individually reviewed strawberry,
tomato, basket, and environment models.
