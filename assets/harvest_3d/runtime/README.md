# Harvest runtime GLB candidates

These are reviewed copies promoted out of `source/` so Godot can import them as
normal `PackedScene` resources. The source models stay frozen under
`assets/harvest_3d/source/`; regenerate or revise there, review the result, then
copy a new approved model here. Godot generates each `.glb.import` sidecar.

| Runtime file | Frozen source | SHA-256 |
| --- | --- | --- |
| `strawberry.glb` | `source/strawberry_readability/rendered/strawberry.glb` | `eb33862a529ba8d182d7d76363931f3173453175da2d02dfd1db9205ace29ae7` |
| `basket.glb` | `source/whole_plant/rendered/basket.glb` | `901ad1618351b92bff63ea5360e1171b41a65dac902634affc5998728a6fd482` |
| `tomato_body.glb` | `source/whole_plant/rendered/plant001_body.glb` | `8da428b2f5091355adcced7b1121954638a8d2551c32aa131bc274edb66109e5` |
| `tomato_fruit.glb` | `source/whole_plant/rendered/tomato_fruit.glb` | `5babf2850fb897705b150430362e83864344ee2f0e6086c301a7cac16e6556bd` |
| `passive_environment.glb` | `source/whole_plant/environment_refined/passive_environment.glb` | `b0ab2a87738360bf01d84aeb2651ee3e48176bc816a3413bfc1d72bfa55d3e92` |

`tests/HarvestRuntimeImportProbe.tscn` verifies the standard Godot import path,
then displays the imported strawberry and basket on the real `HarvestAction`
page. It only replaces visible art in the test scene. Target state, hit areas,
gestures, basket classification, and order progression remain owned by the
existing 2D components. This pilot covers a resource-loading slice, not the
full crop catalog or a formal-page visual approval.
