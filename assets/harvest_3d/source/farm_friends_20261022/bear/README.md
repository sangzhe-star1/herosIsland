# Bear friend-farm character

The bear already had a Blender recipe (`pipeline/recipes/bear.json`, model
`pipeline/models/bear.py`) for its 2.5D sprite, but no runtime GLB, so his own
farm showed no bear. The 一二三木头人 quiet pick needs a friend who can turn its
back, so the same recipe is exported as geometry here.

- `exports/sprites/bear.glb`: runtime geometry, no textures, camera or lights.
- `exports/manifest.json`: render contract from the same build.
- `assets/harvest_3d/runtime/friends/bear.glb`: installed copy used by
  `BearFarm.tscn`.

The installed sprite `props/bear.png` was not replaced (the rebuild differs from
it only inside the baked shadow band).

Rebuild from the repository root:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python-exit-code 1 \
  -P assets/harvest_3d/source/pipeline/build.py -- \
  --only bear --out /tmp/bear_export --glb
cp /tmp/bear_export/sprites/bear.glb assets/harvest_3d/runtime/friends/bear.glb
```

**Colour space.** The sprite recipe writes its fur colours as display (sRGB)
values, but glTF `baseColorFactor` is linear, so the raw export rendered almost
white in Godot. Both copies here have each factor converted with `c ** 2.2`
(teddy brown 0.62/0.42/0.24 -> 0.35/0.15/0.04), the same darker linear range
the rabbit, puppy and robot GLBs already use. Repeat that step after a rebuild.
