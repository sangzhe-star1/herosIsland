# Blender source generators

These scripts are the editable procedural sources for shipped runtime scenes,
gameplay props, and the 48 newer 3D interface icons. They were moved out of
`scratch/` so asset source code has a stable home. Output paths are relative to
the repository root, so the scripts work from any checkout.

Run them from the project root with Blender's Python environment:

```sh
blender --background --python tools/art/rebuild_all_3d.py
blender --background --python tools/art/render_gameplay_3d_props.py
blender --background --python tools/art/render_all_missing_3d_icons.py
```

Each script overwrites its corresponding files under `assets/`. Run one only
when intentionally rebuilding that asset family. The harvest and farm-prop
sprites use the audited studio pipeline under
`assets/harvest_3d/source/pipeline/`; these legacy scene and icon generators
remain separate because their camera, materials, and output formats differ.
The home diorama currently has no procedural rebuild script in this folder.
