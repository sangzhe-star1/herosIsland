# Runtime mesh catalog candidate

This candidate exports the 17 crop/clutter collections from the frozen
`../harvest_sprite_pack.blend` as individual GLBs. It reuses the same rounded,
matte toy geometry and materials used to render the current PNG crop catalog.
Objects named `Shadow | <id>` are excluded because those radial alpha planes
belong to the offline sprite render, not to a runtime mesh.

Run the exporter with Blender 5.2+ from the project root:

```sh
/Applications/Blender.app/Contents/MacOS/blender -b \
  assets/harvest_3d/source/harvest_sprite_pack.blend \
  --python assets/harvest_3d/source/runtime_mesh_catalog_candidate/export_catalog_glb.py
```

Outputs are intentionally kept under this source-only directory until each
mesh has passed a Godot `PackedScene` import, paired visual review, held-state
alignment, and 16:9/4:3 page composition check. This is a geometry availability
candidate, not a claim that all crop art is integrated into HarvestAction.
