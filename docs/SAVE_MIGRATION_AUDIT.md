# Audit a real garden save before changing migration boundaries

`tests/audit_garden_save.py` runs the normal `SaveManager.load_game()` path on
a copy of a supplied `save_game.json`. It creates a uniquely named temporary
Godot project and user-data directory, so neither the Mac's live save nor the
source backup is opened for writing. The report includes the save version
fields, XP and coin balances, garden levels and plots, fields added or changed
by normalization, and basic preservation checks. The normalized save is only
an output artifact; do not copy it back to a device until its report has been
reviewed.

Export or copy the save from the iPad, then run:

```bash
python3 tests/audit_garden_save.py --save /absolute/path/to/save_game.json
```

Or let the Mac fetch it: connect the iPad by cable, unlock it, tap Trust, and
double-click `tools/pull_ipad_save.command` (equivalent to
`./tools/pull_ipad_save.command --audit`). It reads
`Documents/save_game.json` and `.bak` from the `com.family.heroesisland` data
container with `xcrun devicectl`, copies them read-only into
`~/HeroesIsland-saves/<date>-ipad/` with their SHA-256 in `SOURCE.txt`, and
runs this audit into an `audit/` folder beside them. It refuses an output
folder inside the repository. Only a development-signed build (installed from
Xcode or Godot) exposes its container; for an App Store or TestFlight build,
take the file from a Finder backup instead. `--simulator` rehearses the same
path against the booted iPad simulator: on 21 October it copied that
simulator's save (an older build, with no robot friend) and the audit passed
its basic checks, adding `npc.robot` and settlement timestamps only. The
physical-device branch has not run yet, because no iPad has been connected.

Godot is found in the usual application paths. If needed, add
`--godot /path/to/Godot`. The report and normalized copy are written under a
fresh `/tmp/heroes-save-audit-*` directory. To choose a persistent location,
pass `--output-dir /absolute/path/outside/the/repository`.

The audit deliberately does not decide that every changed field is safe. Farm
growth and basket settlement normally run when a save is opened, and old
unknown farm keys need a human review. Check `migration_report.json`, especially
`checks`, `human_review_required`, `lost_farm_keys`, `added_farm_keys`,
`changed_farm_keys`, and `farm_change_paths`, plus the before/after plot and
warehouse summaries. `farm_change_paths` lists nested field paths and whether
a field was added or removed, without writing any saved values to the report or
console. A passing `checks` object means the basic preservation rules held; it
does not replace reviewing farm changes or playing the result on the device.
The runner prints the source file's SHA-256 before and after the run and
confirms it stayed unchanged.
