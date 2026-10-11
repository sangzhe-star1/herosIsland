# Robot friend farm character

The friendly robot already appeared in the public visitor schedule and order
board, but had no full-body model or farm to visit. This asset carries the
existing rounded blue-gray robot design into the shared friend-farm scene.

- `exports/harvest_studio.blend`: editable Blender source, with the frozen
  orthographic profile and generated robot geometry.
- `exports/sprites/robot_friend.glb`: runtime geometry, no external textures,
  camera, or studio lights.
- `exports/sprites/robot_friend.png`: matching 512px icon render; installed to
  `assets/harvest_3d/props/robot_friend.png` for the farm door.
- `assets/harvest_3d/runtime/friends/robot.glb`: installed runtime copy used by
  `RobotFarm.tscn`.
- `exports/manifest.json` and `exports/contact_sheet.png`: render contract and
  sprite audit output.

The model is procedural project artwork based on the existing Blender robot
prop; it uses no third-party mesh or texture. Its source is
`assets/harvest_3d/source/pipeline/models/robot_friend.py` and its recipe is
`assets/harvest_3d/source/pipeline/recipes/robot_friend.json`.

Rebuild from the repository root:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python-exit-code 1 \
  -P assets/harvest_3d/source/pipeline/build.py -- \
  --only robot_friend \
  --out assets/harvest_3d/source/farm_friends_20261010/robot/exports \
  --glb --blend --install \
  --audit-python /Users/xhzhou/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
cp assets/harvest_3d/source/farm_friends_20261010/robot/exports/sprites/robot_friend.glb \
  assets/harvest_3d/runtime/friends/robot.glb
```
