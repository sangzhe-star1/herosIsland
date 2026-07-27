import json, os, re, sys, glob, hashlib

root = "."
errors, warnings = [], []

def res(p):  # res://x -> ./x
    return p.replace("res://", "./", 1)

# tests/ is linted too: the smoke test is as prone to the untyped-inference
# parser bug as anything else, and a broken test is worse than no test.
gd = glob.glob("scripts/**/*.gd", recursive=True) + glob.glob("tests/**/*.gd", recursive=True)
tscn = glob.glob("scenes/**/*.tscn", recursive=True) + glob.glob("tests/**/*.tscn", recursive=True)
tres = glob.glob("resources/**/*.tres", recursive=True)

# --- 1. res:// references resolve (audio/font assets are optional by design)
# Assets and not-yet-built minigame templates are intentionally absent; the
# code guards every one of them with ResourceLoader.exists() before loading.
OPTIONAL_PREFIXES = ("res://assets/",)
PLANNED = set(re.findall(r'"(res://scenes/minigames/[^"]+)"',
                         open("scripts/core/game_data.gd").read()))
# The shell scripts count too. `tests/shots.sh` kept pointing at
# scenes/house/HeroHouse.tscn for a whole session after that scene was deleted
# -- nothing complained, because the scanner only ever read .gd/.tscn/.tres,
# and a screenshot tool that names a scene that is gone just fails at 3am.
for f in gd + tscn + tres + glob.glob("tests/*.sh") + ["project.godot"]:
    for m in re.finditer(r'res://[A-Za-z0-9_./%-]+', open(f).read()):
        p = m.group(0)
        if p.endswith(('%s.ogg',)) or '%s' in p:
            continue
        if p.startswith(OPTIONAL_PREFIXES) or p in PLANNED:
            continue
        if not os.path.exists(res(p)):
            errors.append(f"{f}: missing resource {p}")

# --- 2. tabs only for indentation in GDScript
for f in gd:
    for i, line in enumerate(open(f).read().split("\n"), 1):
        stripped = line.lstrip("\t")
        if stripped.startswith(" ") and stripped.strip() and not stripped.lstrip().startswith("#"):
            warnings.append(f"{f}:{i}: space indentation after tabs")
        if line.startswith(" ") and line.strip():
            errors.append(f"{f}:{i}: leading space indent (Godot wants tabs)")

# --- 3. bracket balance
for f in gd:
    src = open(f).read()
    src = re.sub(r'"(\\.|[^"\\])*"', '""', src)
    src = re.sub(r'#.*', '', src)
    for open_c, close_c in [("(", ")"), ("[", "]"), ("{", "}")]:
        if src.count(open_c) != src.count(close_c):
            errors.append(f"{f}: unbalanced {open_c}{close_c} "
                          f"({src.count(open_c)} vs {src.count(close_c)})")

# --- 3a2. A Control's anchors do nothing under a Node2D, and fail silently.
#
# A Control resolves its anchors against its parent CanvasItem's "anchorable
# rect". Node2D reports that as (0, 0, 0, 0) -- so PRESET_FULL_RECT is honoured
# perfectly against nothing and the Control ends up zero-sized. Everything
# drawn inside it still appears, because Node2D children do not care what size
# their parent claims to be.
#
# The result is a level that looks completely finished and cannot be touched.
# Twelve of thirty-four levels shipped that way, including the first one in the
# game. Nothing caught it: it parses, it builds, it screenshots correctly, and
# every probe that only ENTERED a level passed. Use UiKit.play_area().
#
# A Control under a CanvasLayer is fine -- a CanvasLayer is not a CanvasItem,
# so the lookup falls through to the viewport. That is why every HUD worked.
# Which of our own scripts are Node2D-rooted? Follow `extends` through the
# project's own class_names until it lands on an engine class. Only a Node2D
# parent has the zero anchorable rect: a plain Node is not a CanvasItem at all,
# so the lookup falls through to the viewport and the anchors work -- which is
# why every dev preview harness in tests/ is fine and must not be flagged.
extends_of = {}
for f in gd:
    src = open(f).read()
    name = re.search(r'^class_name\s+(\w+)', src, re.M)
    base = re.search(r'^extends\s+(\w+)', src, re.M)
    if name and base:
        extends_of[name.group(1)] = base.group(1)

def node2d_rooted(base, seen=()):
    while base in extends_of and base not in seen:
        seen = seen + (base,)
        base = extends_of[base]
    return base == "Node2D"

for path in gd:
    src = open(path).read()
    base = re.search(r'^extends\s+(\w+)', src, re.M)
    if not base or not node2d_rooted(base.group(1)):
        continue
    lines = src.splitlines()
    anchored = {}
    for i, line in enumerate(lines):
        m = re.search(r'(\w+)\s*:?=\s*(?:Control|CenterContainer|VBoxContainer'
                      r'|HBoxContainer|PanelContainer)\.new\(\)', line)
        if m:
            anchored.pop(m.group(1), None)
        m = re.search(r'(\w+)\.set_anchors_preset\(Control\.PRESET_FULL_RECT\)', line)
        if m:
            anchored[m.group(1)] = i + 1
        m = re.match(r'\s*add_child\((\w+)\)\s*$', line)
        if m and m.group(1) in anchored:
            errors.append(
                f"{path}:{i+1}: '{m.group(1)}' gets PRESET_FULL_RECT (line "
                f"{anchored[m.group(1)]}) and is then added to a Node2D, where "
                f"anchors do nothing -- it will be zero-sized and untouchable. "
                f"Use UiKit.play_area().")


# --- 3b. GDScript cannot infer a type from an untyped (Variant) expression.
#         `var x := event.pressed` is a parser error, and a parser error in any
#         script blanks the whole game -- this is the bug that produced the
#         grey-screen launch. Only flag when the OUTERMOST expression is
#         untyped: int(d.get(...)) and I18n.t(d.get(...)) infer fine, because
#         the outer call has a declared return type.
def untyped_source(rhs):
    rhs = rhs.strip()
    if "event." in rhs:
        return "an InputEvent property (untyped on the base class)"
    if re.match(r'^[A-Za-z_][\w.]*\.get\(.*\)$', rhs):
        return "a bare .get() call"
    if re.match(r'^[A-Za-z_][\w.]*\[[^\]]+\]$', rhs):
        return "a bare dictionary/array lookup"
    # ...and a method called ON one of those. `data["levels"].size()` is an int
    # to a reader and a Variant to the parser, because the thing it was called
    # on had no type. This one got through and hung the whole suite: a parse
    # error in a probe means the probe never runs, never prints, and never
    # quits -- so the run sat there until it was killed by hand.
    if re.match(r'^[A-Za-z_][\w.]*\[[^\]]+\]\.\w+\(.*\)$', rhs):
        return "a method called on an untyped lookup"
    if re.match(r'^[A-Za-z_][\w.]*\.get\(.*\)\.\w+\(.*\)$', rhs):
        return "a method called on a bare .get()"
    return None

for f in gd:
    lines = open(f).read().split("\n")
    for i, line in enumerate(lines, 1):
        m = re.search(r'\bvar\s+(\w+)\s*:=\s*(.*)$', line)
        if not m:
            continue
        name, rhs = m.group(1), m.group(2)
        j = i
        while rhs.rstrip().endswith("\\") and j < len(lines):
            rhs = rhs.rstrip()[:-1] + " " + lines[j]
            j += 1
        why = untyped_source(rhs)
        if why:
            errors.append(f"{f}:{i}: `var {name} :=` infers from {why}; "
                          f"declare the type explicitly")

# --- 3c. Cross-file member checks.
#         Without a running engine these two rules are the only thing that
#         catches a renamed constant or a signal wired to a method that no
#         longer exists -- both of which are runtime-fatal in Godot.

# Members exposed by each class_name script.
class_members = {}
for f in gd:
    src = open(f).read()
    m = re.search(r'^class_name\s+(\w+)', src, re.M)
    if not m:
        continue
    members = set()
    members |= set(re.findall(r'^(?:static\s+)?func\s+(\w+)', src, re.M))
    members |= set(re.findall(r'^const\s+(\w+)', src, re.M))
    members |= set(re.findall(r'^(?:static\s+)?var\s+(\w+)', src, re.M))
    members |= set(re.findall(r'^enum\s+(\w+)', src, re.M))
    class_members[m.group(1)] = members

for f in gd:
    src = open(f).read()
    for cls, member in re.findall(r'\b([A-Z]\w+)\.(\w+)', src):
        if cls not in class_members:
            continue          # engine class or autoload, not ours to verify
        if member in class_members[cls]:
            continue
        if member in ("new", "call", "free", "instantiate"):
            continue
        errors.append(f"{f}: {cls}.{member} does not exist on {cls}")

# Methods referenced by signal connections must exist in the same file.
for f in gd:
    src = open(f).read()
    defined = set(re.findall(r'^\s*(?:static\s+)?func\s+(\w+)', src, re.M))
    fields = set(re.findall(r'^\s*(?:@\w+\s+)?var\s+(\w+)', src, re.M))
    for method in re.findall(r'\.connect\(\s*(_\w+)(\s*\.)?', src):
        name, is_field = method[0], bool(method[1].strip())
        # `x.connect(_thing.close)` hands over a METHOD OF ANOTHER OBJECT,
        # which is a perfectly ordinary thing to do and not a callback this
        # file has to define. Only a bare `_name` is one.
        if is_field or name in fields:
            continue
        if name not in defined:
            errors.append(f"{f}: connect() references {name}(), which is not "
                          f"defined in this file")

# --- 3d. Godot's global class cache goes stale.
#         The editor rewrites it on scan; headless runs read it as-is. A
#         class_name added since the editor last opened the project is unknown
#         to any headless run, and every script using it fails to parse -- which
#         looks like a code bug and is not one.
cache_path = ".godot/global_script_class_cache.cfg"
if os.path.exists(cache_path):
    cached = set(re.findall(r'"class": &"(\w+)"', open(cache_path).read()))
    declared = set()
    for f in gd:
        m = re.search(r'^class_name\s+(\w+)', open(f).read(), re.M)
        if m:
            declared.add(m.group(1))
    missing = sorted(declared - cached)
    if missing:
        warnings.append(
            "Godot's class cache is stale: %s not registered. "
            "Open the project in the editor, or run tests/run_smoke.sh which "
            "refreshes it first." % ", ".join(missing))

    # An ERROR, not a warning: a class_name referenced from another script
    # that is missing from the cache does not degrade anything gracefully --
    # the referencing script fails to PARSE, and every screen that touches it
    # dies. That shipped once: the whole adventure template referred to five
    # new classes by name, and on a machine whose editor had not rescanned,
    # all thirty levels errored the instant a child picked one.
    #
    # The fix at the call site is `const X := preload("res://path.gd")`, which
    # resolves by path and never consults the cache. This check makes sure
    # nobody has to rediscover that.
    for f in gd:
        norm = f.replace('\\', '/')
        if norm.startswith('tests/') or '/tests/' in norm:
            continue          # dev-only, and run_smoke refreshes first
        # Comments name these classes on purpose -- that is where the reason
        # they are preloaded is written down. Only real code counts.
        body = re.sub(r'#.*', '', open(f).read())
        own = re.search(r'^class_name\s+(\w+)', body, re.M)
        own_name = own.group(1) if own else None
        for name in missing:
            if name == own_name:
                # A file naming its OWN class is not automatically safe. The
                # declaration line is fine; using the name as a type or a
                # constructor is not, because on a stale cache the name does
                # not exist even inside the file that declares it -- the
                # script fails to COMPILE and everything that preloads it
                # dies too. That is what turned every level grey once:
                # `static func for_level(...) -> VariantPicker` in
                # variant_picker.gd, skipped by this very check.
                without_decl = re.sub(r'^class_name\s+\w+.*$', '', body, flags=re.M)
                if not re.search(r'\b%s\b' % re.escape(name), without_decl):
                    continue
                errors.append(
                    "%s uses its own class name '%s' as a type or "
                    "constructor. On a machine whose editor has not rescanned "
                    "that name does not exist even here, and the script will "
                    "not compile. Drop the annotation, or use "
                    "`load(\"res://...\")` instead of `%s.new()`."
                    % (f, name, name))
                continue
            if re.search(r'\b%s\b' % re.escape(name), body):
                errors.append(
                    "%s refers to '%s' by class name, and '%s' is not in the "
                    "class cache -- this script will not parse on a machine "
                    "whose editor has not rescanned. Use "
                    "`const X := preload(...)` instead."
                    % (f, name, name))

# --- 4. localization keys
strings = json.load(open("data/strings.json"))
en, zh = strings["en"], strings["zh"]
used = set()
for f in gd:
    src = open(f).read()
    used |= set(re.findall(r'I18n\.t\(\s*"([^"]+)"', src))
    # keys built indirectly, e.g. praise_key = "result.great"
    # Keys built indirectly: a bare "namespace.key" literal anywhere in a
    # script counts, because templates increasingly keep their strings in
    # const tables (the defence's upgrade draft, for one) rather than
    # spelling out I18n.t() at the point of use.
    used |= set(re.findall(
        r'"((?:app|common|boot|home|map|world|level|badge|growth|character'
        r'|traffic|result|parent|rewards|limit|sorting|bin|item|collect'
        r'|up|defense|battle|duel|expedition|keepy|shop|outfit|house|echo'
        r'|memory|rescue|platformer|blaster|colour|garden|crop|npc)'
        r'\.[a-z0-9_]+)"', src))
def collect_keys(node, out):
    """Any JSON field named *_key holds a translation key."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k.endswith("_key") and isinstance(v, str) and v:
                out.add(v)
            else:
                collect_keys(v, out)
    elif isinstance(node, list):
        for v in node:
            collect_keys(v, out)

for f in glob.glob("data/*.json"):
    if f.endswith("strings.json"):
        continue
    collect_keys(json.load(open(f)), used)
for k in sorted(used):
    if k not in en:
        errors.append(f"strings.json: missing en key '{k}'")
    if k not in zh:
        errors.append(f"strings.json: missing zh key '{k}'")
for k in sorted(set(en) - used):
    warnings.append(f"strings.json: key '{k}' defined but not referenced yet")

# --- 5. data integrity
worlds = {w["id"] for w in json.load(open("data/worlds.json"))}
levels = json.load(open("data/levels.json"))
rewards = json.load(open("data/rewards.json"))
badges = set(rewards["badges"])
growth_ids = {g["id"] for g in rewards["growth_attributes"]}
ids = set()
for lv in levels:
    lid = lv["id"]
    if lid in ids:
        errors.append(f"levels.json: duplicate id {lid}")
    ids.add(lid)
    if lv["world"] not in worlds:
        errors.append(f"levels.json: {lid} references unknown world {lv['world']}")
    b = lv.get("reward", {}).get("badge", "")
    if b and b not in badges:
        errors.append(f"levels.json: {lid} awards unknown badge {b}")
    ga = lv.get("growth_attribute", "")
    if ga and ga not in growth_ids:
        errors.append(f"levels.json: {lid} unknown growth_attribute {ga}")
for lv in levels:
    r = lv.get("requires", "")
    if r and r not in ids:
        errors.append(f"levels.json: {lv['id']} requires unknown level {r}")

# --- 3b. variety: the rule the whole redesign exists to enforce
#
# The island's first rebuild turned every one of its levels into the same
# side-scrolling run, and nobody noticed until a child played four in a row.
# These three rules are what "a collection of games" means, stated as numbers
# so a future level cannot quietly break it:
#
#   * no template more than twice in a row
#   * every world offers at least four different kinds of play
#   * side-scrolling stays a fifth of the island, never its floor

# Rooms are places, not levels: walked into whenever he likes, with nothing in
# them to finish. They used to be recognised by writing "hero_studio" out by
# hand in four different files; they now say so themselves, with "room": true.
#
# Bonus levels are treats sitting beside the curriculum -- always unlocked,
# never required, and deliberately outside the ratio. Counting them would let
# somebody "fix" a platformer-heavy island by adding bonus puzzles, which
# fixes the number and not the problem.
numbered = [l for l in levels
            if not l.get("room", False) and not l.get("bonus", False)]
if numbered:
    run = worst = 1
    worst_at = ""
    for i in range(1, len(numbered)):
        if numbered[i].get("game_type") == numbered[i - 1].get("game_type"):
            run += 1
            if run > worst:
                worst, worst_at = run, numbered[i].get("id", "?")
        else:
            run = 1
    if worst > 2:
        errors.append(
            "%d levels in a row use the same template (up to %s). "
            "Two is the limit -- a third makes the island feel like one game."
            % (worst, worst_at))

    from collections import Counter
    per_world = {}
    for l in numbered:
        per_world.setdefault(l.get("world", ""), []).append(l.get("game_type", ""))
    for world_id, kinds in per_world.items():
        if len(set(kinds)) < 4:
            errors.append(
                "world '%s' has only %d kinds of play across %d levels; "
                "the brief asks for at least 4."
                % (world_id, len(set(kinds)), len(kinds)))

    mix = Counter(l.get("game_type", "") for l in numbered)
    side = mix.get("platform_adventure", 0) + mix.get("platformer", 0)
    share = 100.0 * side / len(numbered)
    if share > 25.0:
        errors.append(
            "side-scrolling is %.0f%% of the island (%d of %d levels). "
            "The cap is 25%%." % (share, side, len(numbered)))

# every world's growth_attribute is real
for w in json.load(open("data/worlds.json")):
    if w["growth_attribute"] not in growth_ids:
        errors.append(f"worlds.json: {w['id']} unknown growth_attribute")

# --- 5c. a level that ends on its target must HAVE a target
#
# LevelManager.score_correct() finishes the level when auto_complete_on_target()
# is true and the target is met -- and an empty target is met by the first right
# answer, because a loop over no requirements finds nothing unmet. A template
# that ends itself overrides auto_complete_on_target() to false and leaves the
# target empty on purpose. A template that does NOT override it, and has no
# target, ends on the first thing the child does right.
#
# That is how 最终一战 -- the last fight in the game -- ended when he hit the
# monster once, with an eighteen-cell progress meter on screen showing one lit.
# The runtime now refuses to complete on an empty target, so this can no longer
# be fatal; it is still always a mistake, because a level in this state has no
# ending at all.
game_type_scene = dict(re.findall(r'"(\w+)":\s*"(res://[^"]+)"',
                                  open("scripts/core/game_data.gd").read()))
scene_script = {}
for game_type, scene_path in game_type_scene.items():
    scene_file = res(scene_path)
    if not os.path.exists(scene_file):
        continue
    m = re.search(r'path="(res://scripts/[^"]+\.gd)"', open(scene_file).read())
    if m:
        scene_script[game_type] = res(m.group(1))

# --- 5d. every kind of game has its own picture on the map
#
# A child who cannot read the label picks a level by looking at the marker.
# The map's icon table is a lookup keyed on game_type with a `flag` default,
# so a template missing from it does not fail -- it silently becomes a flag,
# and a world of eight levels shows eight identical markers.
#
# That is what the rebuild did: the table still listed the templates from
# before it, so all nine new ones defaulted. It is the same shape of mistake
# as world_style.gd and island_map.gd, which is why it is worth a rule.
map_icons = set(re.findall(r'"(\w+)":\s*"\w+"',
    re.search(r'var icons := \{(.*?)\n\t\}',
              open("scripts/ui/world_map.gd").read(), re.S).group(1)))
for game_type in sorted({l["game_type"] for l in levels}):
    if game_type not in map_icons:
        errors.append(
            f"world_map.gd: game_type '{game_type}' has no icon of its own; "
            f"its levels all show the default flag")

for lv in levels:
    script = scene_script.get(lv["game_type"])
    if not script or not os.path.exists(script):
        continue
    if "func auto_complete_on_target" in open(script).read():
        continue          # the template decides for itself
    target = lv.get("target", {})
    if not any(k in target for k in ("correct", "correct_crossings")):
        errors.append(
            f"levels.json: {lv['id']} ({lv['game_type']}) has no target, and "
            f"{os.path.basename(script)} does not override "
            f"auto_complete_on_target() -- the level has no ending")

# --- 5b. every world is a PLACE
#
# WorldStyle.for_world() and IslandMap._region_prop() both end in a catch-all
# arm, so a world with no entry of its own does not crash -- it silently gets
# the default. When the rebuild renamed the five worlds, nobody moved the
# scenery across, and four of the five were drawn as the same blue sea and
# sand for weeks. Nothing failed. Every static check passed. It was only
# visible by looking at the screen, which is exactly the kind of bug a check
# should be catching instead.
#
# So: a world id in worlds.json must appear as its own match arm in both
# files. Falling through to `_` is the error.
def match_arms(path):
    src = open(path).read()
    # Arm labels only: `"night_city":` or `"skyline", "rooftops":` at the head
    # of a line. Deliberately not a general string search -- the world id also
    # appears in comments and in level ids, and matching those would let a
    # mention stand in for a drawing.
    arms = set()
    for line in src.splitlines():
        m = re.match(r'^\s*((?:"[\w]+"\s*,\s*)*"[\w]+")\s*:\s*$', line)
        if m:
            arms |= set(re.findall(r'"(\w+)"', m.group(1)))
    return arms

for path, what in [("scripts/world/world_style.gd", "scenery of its own"),
                   ("scripts/world/island_map.gd", "a shape of its own on the map")]:
    arms = match_arms(path)
    for w in sorted(worlds):
        if w not in arms:
            errors.append(f"{os.path.basename(path)}: world '{w}' has "
                          f"no {what} and falls through to the default")

# --- 5e. only one thing may take money, and stars are not money
#
# 关卡星章 is a score. The brief's first rule is that it can never be spent,
# and the collapse of the old star-purse is what makes that true. These two
# rules stop it quietly coming back:
#
#   * nothing outside currency_manager.gd may decrement a balance
#   * the retired spend_stars() may not gain a caller again
#
# The first version of this rule only matched a dictionary WRITE, which meant
# SaveManager.add_coins() and SaveManager.spend_coins() -- two real back doors
# with real callers -- were invisible to it. Both are gone now, and these two
# extra patterns are what stops them growing back under a new name.
for path in gd:
    # The definition site and the probe that proves it is dead are exempt.
    if path.endswith("currency_manager.gd") or path.endswith("save_manager.gd") \
            or path.startswith("tests"):
        continue
    src = open(path).read()
    if re.search(r'\bSaveManager\.spend_stars\s*\(', src):
        errors.append(f"{path}: calls the retired SaveManager.spend_stars(). "
                      f"关卡星章 cannot be spent -- use "
                      f"scripts/shop/currency_manager.gd")
    if re.search(r'data\["rewards"\]\["coins"\]\s*=', src) \
            and "save_manager.gd" not in path:
        errors.append(f"{path}: writes rewards.coins directly. Money goes "
                      f"through currency_manager.gd so that every change to "
                      f"it is in one file")

# The two retired back doors, checked EVERYWHERE including save_manager.gd and
# the probes -- there is no legitimate caller left anywhere, so there is no
# exemption to make. add_coins() also skipped progress_changed, so the 星星币
# chip kept showing the old number after a level that paid out.
for path in gd:
    src = open(path).read()
    for gone, instead in (("add_coins", "Coins.earn(amount, reason)"),
                          ("spend_coins", "Coins.spend(amount)")):
        if re.search(r'\bSaveManager\.' + gone + r'\s*\(', src):
            errors.append(f"{path}: calls SaveManager.{gone}(), which was "
                          f"removed. Money moves through "
                          f"scripts/shop/currency_manager.gd -- use {instead}")
    if path.endswith("save_manager.gd") and re.search(
            r'^func (add_coins|spend_coins)\b', src, re.M):
        errors.append(f"{path}: defines add_coins/spend_coins again. These are "
                      f"back doors around currency_manager.gd; the whole point "
                      f"of one money file is that there is only one")

# --- 5q. the crops have to be growable
#
# A stage that takes zero seconds finishes the instant it starts, which reads
# to a child as a crop that skipped a step -- and to the growth arithmetic as a
# division by nothing. A crop with no yield is a plant he waters for eight
# hours and gets an empty basket from. Neither shows up as a crash.
FARM_STAGES = 5                 # keep in step with farm_save.gd's STAGES
if os.path.exists("data/crops.json"):
    crops = json.load(open("data/crops.json"))
    crop_icon_names = set(re.findall(r'"(\w+)"',
        re.search(r'const NAMES := \[(.*?)\n\]',
                  open("scripts/ui/icon_library.gd").read(), re.S).group(1)))
    seen_crops = set()
    for crop in crops:
        cid = str(crop.get("id", ""))
        if cid == "":
            errors.append("crops.json: a crop with no id")
            continue
        if cid in seen_crops:
            errors.append(f"crops.json: duplicate crop id '{cid}'")
        seen_crops.add(cid)
        stages = crop.get("stage_seconds", [])
        if not isinstance(stages, list) or len(stages) != FARM_STAGES - 1:
            errors.append(f"crops.json: crop '{cid}' needs {FARM_STAGES - 1} "
                          f"stage_seconds (one per change between the "
                          f"{FARM_STAGES} stages), has "
                          f"{len(stages) if isinstance(stages, list) else '?'}")
        else:
            for i, seconds in enumerate(stages):
                if not isinstance(seconds, int) or seconds <= 0:
                    errors.append(f"crops.json: crop '{cid}' stage {i} takes "
                                  f"{seconds!r}. A stage of zero is a stage the "
                                  f"child never sees")
        if int(crop.get("yield", 0)) <= 0:
            errors.append(f"crops.json: crop '{cid}' yields nothing. Eight hours "
                          f"of waiting has to put something in the basket")
        if int(crop.get("thirst_seconds", 0)) <= 0:
            errors.append(f"crops.json: crop '{cid}' has no thirst_seconds, so "
                          f"its water level would fall instantly or never")
        if str(crop.get("name_key", "")) == "":
            errors.append(f"crops.json: crop '{cid}' has no name_key")
        icon = str(crop.get("icon", ""))
        if icon != "" and icon not in crop_icon_names:
            errors.append(f"crops.json: crop '{cid}' asks for icon '{icon}', "
                          f"which IconLibrary cannot draw -- it would render as "
                          f"nothing at all")
    if not crops:
        errors.append("crops.json: no crops. The garden would open on four "
                      "patches of earth and an empty seed rack")

# --- 5r. every order has to be fillable, and worth filling
#
# The same rule as the album's "every card can be earned": an order asking for
# a crop that does not exist is a request he can never satisfy, sitting on the
# board forever. It is not an error at runtime -- the button simply never
# lights -- which is why it has to be one here.
if os.path.exists("data/garden_orders.json"):
    orders = json.load(open("data/garden_orders.json"))
    crop_ids = {str(c.get("id", "")) for c in json.load(open("data/crops.json"))} \
        if os.path.exists("data/crops.json") else set()
    order_icon_names = set(re.findall(r'"(\w+)"',
        re.search(r'const NAMES := \[(.*?)\n\]',
                  open("scripts/ui/icon_library.gd").read(), re.S).group(1)))
    seen_orders = set()
    for order in orders:
        oid = str(order.get("id", ""))
        if oid == "":
            errors.append("garden_orders.json: an order with no id")
            continue
        if oid in seen_orders:
            errors.append(f"garden_orders.json: duplicate order id '{oid}' -- "
                          f"deliveries are recorded by id, so two orders "
                          f"sharing one would pay for each other")
        seen_orders.add(oid)
        wants = order.get("wants", {})
        if not isinstance(wants, dict) or not wants:
            errors.append(f"garden_orders.json: order '{oid}' asks for nothing")
        else:
            for crop_id, how_many in wants.items():
                if crop_id not in crop_ids:
                    errors.append(f"garden_orders.json: order '{oid}' asks for "
                                  f"'{crop_id}', which is not a crop -- he could "
                                  f"never fill it")
                if not isinstance(how_many, int) or how_many <= 0:
                    errors.append(f"garden_orders.json: order '{oid}' asks for "
                                  f"{how_many!r} of '{crop_id}'")
        if int(order.get("reward_coins", 0)) <= 0:
            errors.append(f"garden_orders.json: order '{oid}' pays nothing. "
                          f"Growing three carrots for somebody has to be worth "
                          f"something or it is a chore")
        if str(order.get("name_key", "")) == "":
            errors.append(f"garden_orders.json: order '{oid}' has no name_key")
        icon = str(order.get("npc_icon", ""))
        if icon != "" and icon not in order_icon_names:
            errors.append(f"garden_orders.json: order '{oid}' asks for icon "
                          f"'{icon}', which IconLibrary cannot draw")

# --- 5p. a room says it is a room, and nobody names one by hand
#
# "Is this world finished" and "how much of the island is left" both have to
# skip the free-play rooms, or a world he has beaten sits at 5/6 forever and
# the shop items behind it never open. That skip lived as four separate
# `id == "hero_studio"` comparisons in four files, which was fine while there
# was one room and is exactly how a rule stops applying to the second one.
rooms = [l for l in levels if l.get("room", False)]
for room in rooms:
    rid = room.get("id", "?")
    reward = room.get("reward", {})
    if int(reward.get("coins", 0)) != 0 or str(reward.get("badge", "")) != "":
        errors.append(f"levels.json: room '{rid}' hands out a reward. A room is "
                      f"somewhere he goes, not something he finishes -- paying "
                      f"for walking in makes it a level with no way to fail")
    if room.get("requires") is not None and room.get("bonus", False):
        errors.append(f"levels.json: room '{rid}' is marked both room and bonus. "
                      f"Pick one; they are excluded from different counts")

for path in gd:
    if path.startswith("tests"):
        continue
    # Comments and docstrings may name a room -- explaining why the rule exists
    # is not the same as depending on the name. Only real code counts.
    for n, raw in enumerate(open(path).read().splitlines(), start=1):
        if raw.lstrip().startswith("#"):
            continue
        for room in rooms:
            rid = room.get("id", "")
            if rid and f'"{rid}"' in raw:
                errors.append(f"{path}:{n}: names the room '{rid}' in code. Ask "
                              f"the level whether it is a room -- "
                              f"level.get(\"room\") or GameData.is_room(id) -- so "
                              f"the second room gets the same treatment as the "
                              f"first without anyone having to remember four "
                              f"places")

# --- 5o. there is one clock, and everything reads it through GameClock
#
# A clock that is read from wherever it is needed cannot be pointed anywhere,
# and anything that depends on real time then has no test that does not
# involve waiting until tomorrow. It is also how three hours of an app sitting
# suspended in a bag got banked as three hours of a child playing: the site
# that measured the session and the site that decided what "today" meant had
# no idea they were talking about the same clock.
#
# scripts/core/game_clock.gd is the one place allowed to call Time directly.
for path in gd:
    if path.endswith("game_clock.gd") or path.startswith("tests"):
        continue
    src = open(path).read()
    for hit in re.finditer(r'\bTime\.get_\w+\s*\(', src):
        line = src[:hit.start()].count("\n") + 1
        errors.append(f"{path}:{line}: reads Time directly. Every clock on the "
                      f"island goes through GameClock (scripts/core/"
                      f"game_clock.gd) so that a probe can move time on "
                      f"purpose -- use GameClock.now_unix() / now_date() / "
                      f"ticks_ms() / elapsed_since()")

# --- 5f. the shop may not contain a slot machine
#
# The brief bans random rewards, probability, draws and timed disappearance in
# so many words. The strongest way to honour that is to leave the concepts no
# place to live: if a field for them ever appears in the shop data, this fails.
GAMBLING = ("random", "chance", "probability", "gacha", "lottery", "draw_",
            "rarity", "weight", "odds", "expires", "limited_time", "countdown")
for shop_file in glob.glob("data/shop_*.json"):
    blob = open(shop_file).read().lower()
    for word in GAMBLING:
        if f'"{word}' in blob:
            errors.append(f"{shop_file}: contains a '{word}' field. The shop "
                          f"is not allowed to have randomness, rarity or a "
                          f"countdown anywhere in it")

# --- 5g. the shop catalogue holds together
#
# Three JSON files that reference each other, an icon library, and a price
# policy. Every one of those is a lookup, and this repo has learned what a
# lookup nobody checks turns into: four worlds drawn as the same beach, eight
# levels wearing the same flag. So the catalogue is checked as a whole.
if os.path.exists("data/shop_items.json"):
    shop_items = json.load(open("data/shop_items.json"))
    shop_cats = json.load(open("data/shop_categories.json"))
    shop_bundles = json.load(open("data/shop_bundles.json"))
    icon_names = set(re.findall(r'"(\w+)"',
        re.search(r'const NAMES := \[(.*?)\n\]',
                  open("scripts/ui/icon_library.gd").read(), re.S).group(1)))
    cat_ids = {c["id"] for c in shop_cats}
    item_ids = {i["id"] for i in shop_items}

    # The price bands from the brief. A shop where a hat costs more than a ride
    # is one a child cannot reason about.
    BANDS = {
        "head": (15, 60), "body": (15, 60), "back": (15, 60),
        "hands": (10, 60), "feet": (15, 60), "colour": (10, 60),
        "pal": (40, 90), "action": (5, 20), "keepsake": (5, 25),
        "wardrobe": (15, 60), "fx": (25, 50), "base": (25, 70),
        "ride": (70, 120),
        # A face is free (0) or costs about what a companion does. The ten
        # free ones are priced 0 deliberately: they are in the item list so
        # that ONE drawer and ONE purchase flow cover the whole cast.
        "who": (0, 90),
    }
    # A drawer built from data rather than from the item list. 整套 shows the
    # twelve themed outfits, which live in outfit_presets.json.
    DATA_DRIVEN_CATS = {"set"}
    seen_ids = set()
    for it in shop_items:
        iid = it["id"]
        if iid in seen_ids:
            errors.append(f"shop_items.json: duplicate id '{iid}'")
        seen_ids.add(iid)
        if it["category"] not in cat_ids:
            errors.append(f"shop_items.json: '{iid}' is in category "
                          f"'{it['category']}', which does not exist")
        # A blank card is silent, and the child cannot tell what he is being
        # offered. A thing may carry EITHER a painted picture on disk or an
        # icon IconLibrary can draw -- but it must carry one of them.
        # A face carries no picture file: item_card draws the real figure from
        # its skin, which is checked separately below.
        art = it.get("art", "")
        if it["category"] == "who":
            pass
        elif art:
            if not os.path.exists(res(art)):
                errors.append(f"shop_items.json: '{iid}' points at {art}, "
                              f"which is not on disk")
        elif it.get("icon", "") not in icon_names:
            errors.append(f"shop_items.json: '{iid}' has neither a picture "
                          f"nor an icon IconLibrary can draw")
        lo, hi = BANDS.get(it["category"], (1, 1000))
        if not lo <= it["price"] <= hi:
            errors.append(f"shop_items.json: '{iid}' costs {it['price']}, "
                          f"outside the {lo}-{hi} band for {it['category']}")
        # A garment nobody can wear is a garment nobody should be sold.
        #
        # Only things worn ON the body, though. A companion walks beside the
        # hero rather than being painted onto him, so it works for every
        # character -- including the puppy, who can wear nothing at all and
        # would otherwise have an empty shop.
        WORN_ON_BODY = {"head", "body", "back", "hands", "feet", "colour"}
        if it["slot"] in WORN_ON_BODY and not it["character_compatibility"]:
            errors.append(f"shop_items.json: '{iid}' fills the "
                          f"'{it['slot']}' slot but fits no character")

    for cat in shop_cats:
        if cat["id"] in DATA_DRIVEN_CATS:
            continue
        if not any(i["category"] == cat["id"] for i in shop_items):
            errors.append(f"shop_categories.json: '{cat['id']}' has no items; "
                          f"it would be a tab that opens onto nothing")
        if cat["icon"] not in icon_names:
            errors.append(f"shop_categories.json: '{cat['id']}' wants icon "
                          f"'{cat['icon']}', which IconLibrary cannot draw")

    for box in shop_bundles:
        for member in box["contains"]:
            if member not in item_ids:
                errors.append(f"shop_bundles.json: '{box['id']}' contains "
                              f"'{member}', which is not an item")
        singles = sum(i["price"] for i in shop_items if i["id"] in box["contains"])
        if box["price"] >= singles:
            errors.append(f"shop_bundles.json: '{box['id']}' costs "
                          f"{box['price']} but its pieces cost {singles} "
                          f"separately -- a box must be worth buying")

    # Exactly one free teaching gift, or the first visit has no lesson.
    gifts = [i["id"] for i in shop_items
             if i["unlock_condition"].get("type") == "free_gift"]
    if len(gifts) != 1:
        errors.append(f"shop_items.json: {len(gifts)} free gifts; the first "
                      f"visit needs exactly one")

# --- 5h. a template may not offer something no level ever asks for
#
# The adventure template can build a three-phase rock boss with a telegraphed
# slam, a row of timed fire vents, and a step-the-plates-in-order puzzle. It
# could do all three for months and no child ever saw any of them, because not
# one level config named them. Same story in two other templates: an "order"
# puzzle and a "robot" blueprint, written, working, unreachable.
#
# Unused code is untested code, and unused CONTENT is worse: it is work already
# paid for and thrown away. So every capability a template advertises has to be
# reachable from data. The fix when this fires is never to delete the feature --
# it is to give it to the level whose name already promises it.
# The adventure's beats are the arms of one match statement in _build_sections.
adv = open("scripts/adventure/adventure.gd").read()
block = re.search(r'func _build_sections.*?(?=\n\nfunc )', adv, re.S)
offered = set(re.findall(r'^\t\t\t"(\w+)"', block.group(0), re.M)) if block else set()
used = {s.get("kind", "") for l in levels
        for s in l.get("config", {}).get("sections", [])}
for kind in sorted(offered - used):
    errors.append(f"adventure.gd: the '{kind}' beat is built but no level asks "
                  f"for it -- a child can never see it")

# The other two keep their options in a dictionary literal.
for path, key, kinds_used in [
        ("scripts/minigames/puzzle_mechanism.gd", "puzzle",
         {l.get("config", {}).get("puzzle", "pipes") for l in levels
          if l["game_type"] == "puzzle_mechanism"}),
        ("scripts/minigames/build_repair.gd", "machine",
         {l.get("config", {}).get("machine", "") for l in levels
          if l["game_type"] == "build_repair"})]:
    src = open(path).read()
    if key == "puzzle":
        # Named in the file's own doc comment, one per line: "pipes  turn ..."
        have = set(re.findall(r'^##   (\w+)\s{2,}', src, re.M))
    else:
        table = re.search(r'const BLUEPRINTS := \{(.*?)\n\}', src, re.S)
        have = set(re.findall(r'^\t"(\w+)":', table.group(1), re.M)) if table else set()
    for kind in sorted(have - kinds_used):
        errors.append(f"{os.path.basename(path)}: '{kind}' is implemented but "
                      f"no level uses it -- a child can never see it")

# --- 5j. a data file nobody loads
#
# data/monsters.json shipped while the one line that reads it stayed behind on
# the other machine. The game booted fine, GameData.monsters was empty, and
# 怪兽图鉴 drew an empty shelf -- the only symptom being "I can't see it".
# Every file in data/ has to be named in game_data.gd.
gd_data = open("scripts/core/game_data.gd").read()
for path in sorted(glob.glob("data/*.json")):
    if os.path.basename(path) == "strings.json":
        continue                      # I18n loads this one
    if f'"res://{path}"' not in gd_data:
        errors.append(f"{path}: nothing in game_data.gd loads it -- it will "
                      f"be silently empty at runtime")

# --- 3a3. a screen that catches input may not listen for it somewhere else
#
# `UiKit.play_area(self, true)` puts a full-screen MOUSE_FILTER_STOP Control
# over the level. That Control then EATS every press and drag -- including
# InputEventScreenTouch and InputEventScreenDrag -- so a node that catches
# input through `_unhandled_input` never hears a thing.
#
# On a desktop that looked survivable, because a tap still reached the Control
# and most templates only tap. 英雄基地 is made entirely of drags, and it did
# nothing at all: reported from an iPad as "拖动没响应". Four of the five
# templates on play_area() had always used gui_input; the fifth was the one
# that broke.
for path in glob.glob("scripts/**/*.gd", recursive=True):
    src = open(path).read()
    if "play_area(self, true)" not in src and "play_area(self,true)" not in src:
        continue
    if "gui_input.connect" in src:
        continue
    if re.search(r'^func _(unhandled_)?input\(', src, re.M):
        errors.append(f"{os.path.basename(path)}: puts a MOUSE_FILTER_STOP "
                      f"play area over the screen and then listens on "
                      f"_input/_unhandled_input -- the Control eats the "
                      f"press, so nothing is ever touchable")

# --- 3a4. the screen is not always 1280x720
#
# `stretch/aspect` is "expand", so the viewport is 1280 wide everywhere and
# 720 tall only on a 16:9 screen. A 4:3 iPad gets 1280x960. Anything that
# writes 720 (or a y near it) into a drawn layout puts furniture a third of
# the way up the child's screen -- and any "below this line" rule written as a
# fixed y ends up slicing through the middle of the play area.
BOTTOM = [
    # the y slot of a Vector2, down where the bottom of a 16:9 screen is
    re.compile(r'Vector2\([^,()]+,\s*(?:6[2-9]\d|7[0-2]\d)(?:\.\d+)?\s*[),]'),
    # 720 used as "the height of the screen"
    re.compile(r'(?<![\w.])720(?:\.0)?\s*[-*/]'),
]
for path in (glob.glob("scripts/minigames/*.gd") + glob.glob("scripts/adventure/*.gd")
             + glob.glob("scripts/ui/*.gd") + glob.glob("scripts/shop/*.gd")):
    src = open(path).read()
    # The exemption used to be file-wide: one `get_viewport_rect()` anywhere in
    # the file and the whole thing went unchecked. reward_center.gd measures the
    # viewport in ONE line and hard-codes the album page's whole layout in the
    # other 580 -- and that page is where "iPad shows a blank card" lives. A
    # file that asks the screen how tall it is once has not thereby asked
    # everywhere. Exempt the FUNCTION that measures, not the file.
    measured: set = set()
    current = -1
    for i, line in enumerate(src.splitlines(), 1):
        if line.startswith(("func ", "static func ")):
            current = i
        if "get_viewport_rect()" in line or "get_visible_rect()" in line:
            measured.add(current)
    current = -1
    for i, line in enumerate(src.splitlines(), 1):
        if line.startswith(("func ", "static func ")):
            current = i
        if line.lstrip().startswith("#"):
            continue
        if current in measured:
            continue      # this function already asks the screen how tall it is
        if any(rx.search(line) for rx in BOTTOM):
            warnings.append(f"{os.path.basename(path)}:{i}: a y near the "
                            f"bottom of a 720-tall screen, hard-coded -- a "
                            f"4:3 tablet viewport is 960 tall")

# --- 5l. a sound that is not there makes no noise and no error
#
# `AudioManager.play_sfx()` on a path that does not exist does exactly nothing
# -- no warning, no crash, just a button that feels dead. The gift box in
# 英雄小屋 shipped asking for chest_open.ogg, which had never been generated,
# and the one moment the whole purchase flow builds up to was silent.
#
# res:// checking (rule 1) deliberately skips assets/ because audio and fonts
# are optional by design. Sound effects are not optional: every one of them is
# generated by tools/make_audio.py, so a path with no file behind it is a typo
# or a sound somebody forgot to add to the generator.
audio_asked = set()
for path in gd:
    for m in re.finditer(r'"(res://assets/audio/[a-z0-9_/]+\.ogg)"', open(path).read()):
        audio_asked.add((m.group(1), os.path.basename(path)))
for sound, where in sorted(audio_asked):
    if not os.path.exists(res(sound)):
        errors.append(f"{where}: asks for {sound}, which is not on disk -- "
                      f"play_sfx() on a missing file is silent, not an error")

# ...and the same for spoken lines. AudioManager.say() returns whether it
# actually spoke, so a missing line is survivable -- but it should be in the
# script for somebody to record, not lost.
voice_dir = "assets/audio/voice/level"
script_doc = ""
if os.path.exists("docs/VOICE_SCRIPT.md"):
    script_doc = open("docs/VOICE_SCRIPT.md").read()
for path in gd:
    for m in re.finditer(r'AudioManager\.say\(\s*"([a-z0-9_]+)"', open(path).read()):
        line_id = m.group(1)
        have = any(os.path.exists(os.path.join(voice_dir, line_id + ext))
                   for ext in (".ogg", ".wav"))
        if not have and line_id not in script_doc:
            warnings.append(f"{os.path.basename(path)}: says '{line_id}', which "
                            f"is neither recorded nor in docs/VOICE_SCRIPT.md")

# --- 5i. every card in the 怪兽图鉴 can actually be earned
#
# A collection is a promise: ten slots means ten are gettable. A card nothing
# in the game ever awards is a slot that stays grey for ever, and a six-year-
# old cannot tell "not yet" from "never" -- he just keeps looking.
#
# It has already gone wrong twice in one week. The six duel bosses recorded
# nothing at all, so the biggest monsters in the game left no trace in the
# book; and three of the small ones were only ever fought in dark_castle_04,
# five worlds after their own island. This is the static half -- the album
# probe plays it for real -- and it is here because the failure is silent.
monsters = json.load(open("data/monsters.json"))
monster_ids = [str(m.get("id", "")) for m in monsters]
gd_text = "".join(
    open(os.path.join(r, f)).read()
    for r, _, fs in os.walk("scripts") for f in fs if f.endswith(".gd"))
level_text = json.dumps(levels)
for mid in monster_ids:
    if f'"{mid}"' not in level_text and f'"{mid}"' not in gd_text:
        errors.append(f"monsters.json: '{mid}' has a card in the album but "
                      f"nothing in the game ever awards it -- that slot can "
                      f"never be filled")

# ...and nothing may fight a monster the album has never heard of, or the card
# he earns is a card that does not exist. A level names a monster in two
# places: a duel's config, and a `monsters` list on an adventure section.
named_in_levels = set()
for lv in levels:
    cfg = lv.get("config", {})
    if cfg.get("monster", {}).get("id"):
        named_in_levels.add(str(cfg["monster"]["id"]))
    for sec in cfg.get("sections", []):
        for mid in sec.get("monsters", []):
            named_in_levels.add(str(mid))
        if sec.get("monster"):
            named_in_levels.add(str(sec["monster"]))
for mid in sorted(named_in_levels - set(monster_ids)):
    errors.append(f"levels.json: something fights '{mid}', which is not in "
                  f"monsters.json")

# --- 5k. every monster has its own picture, and every picture has a monster
#
# The creature in the fight, the small foe on a ledge and the card in the book
# are one drawing loaded from one file. So: a monster with no file falls back
# to the code-drawn creature and quietly stops matching its own card; a file
# with no monster is art nobody will ever see; and two identical files are two
# cards showing the same animal, which is the failure the old hand-drawn set
# had for months and nobody noticed.
ART_DIR = "assets/characters/monsters"
art_files = {os.path.splitext(os.path.basename(p))[0]: p
             for p in glob.glob(os.path.join(ART_DIR, "*.png"))}
drawn = []
for mid in monster_ids:
    if mid not in art_files:
        drawn.append(mid)
for extra in sorted(set(art_files) - set(monster_ids)):
    errors.append(f"{ART_DIR}/{extra}.png: no monster in monsters.json uses "
                  f"this picture")
if drawn and len(drawn) != len(monster_ids):
    errors.append(f"monsters.json: {', '.join(drawn)} have no picture while "
                  f"the rest do -- they will come out in the old code-drawn "
                  f"style and stop matching their own album card")

by_hash = {}
for mid, path in sorted(art_files.items()):
    with open(path, "rb") as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    if digest in by_hash:
        errors.append(f"{ART_DIR}: '{mid}.png' is byte-for-byte the same file "
                      f"as '{by_hash[digest]}.png' -- two cards, one creature")
    by_hash[digest] = mid

# The hand-drawn builder is still there for any monster without a picture, and
# these two rules guard it. They only make sense while such a monster exists:
# with fifteen painted monsters there is nothing to compare, and firing on an
# empty set would just be noise demanding ears nobody wears.
if drawn:
    seen_look = {}
    for m in monsters:
        if str(m.get("id")) not in drawn:
            continue
        look = (m.get("body_color"), m.get("horns"), m.get("spikes"),
                m.get("eyes"), round(float(m.get("width", 1.0)), 2))
        if look in seen_look:
            errors.append(f"monsters.json: '{m.get('id')}' is drawn exactly "
                          f"like '{seen_look[look]}' -- two cards, one creature")
        seen_look[look] = m.get("id")

    mon_src = open("scripts/battle/monster.gd").read()
    ear_block = re.search(r'func _draw_ears.*?(?=\n\nfunc )', mon_src, re.S)
    if ear_block:
        ear_kinds = set(re.findall(r'^\t\t\t"(\w+)":', ear_block.group(0), re.M))
        ear_kinds.add("none")
        ears_used = {str(m.get("ears", "round")) for m in monsters
                     if str(m.get("id")) in drawn}
        for kind in sorted(ear_kinds - ears_used):
            errors.append(f"monster.gd: the '{kind}' ear shape is drawn but no "
                          f"code-drawn monster wears it")

# --- 6. every badge is reachable
awarded = {lv.get("reward", {}).get("badge", "") for lv in levels}
for b in sorted(badges - awarded):
    warnings.append(f"rewards.json: badge '{b}' is not awarded by any level")

# --- 7. game_type -> scene mapping, and which levels are actually playable
mapping = dict(re.findall(r'"(\w+)":\s*"(res://[^"]+)"',
                          open("scripts/core/game_data.gd").read()))
playable = []
for lv in levels:
    gt = lv["game_type"]
    if gt not in mapping:
        errors.append(f"game_data.gd: no scene mapped for game_type '{gt}'")
    elif os.path.exists(res(mapping[gt])):
        playable.append(lv["id"])

# --- 8. autoloads exist and are ordered before their dependents
proj = open("project.godot").read()
autoloads = re.findall(r'^(\w+)="\*(res://[^"]+)"', proj, re.M)
for name, path in autoloads:
    if not os.path.exists(res(path)):
        errors.append(f"project.godot: autoload {name} -> missing {path}")
order = [n for n, _ in autoloads]
for i, (name, path) in enumerate(autoloads):
    src = open(res(path)).read()
    ready = re.search(r'func _ready\(\).*?(?=\nfunc |\Z)', src, re.S)
    if not ready:
        continue
    for other in order[i+1:]:
        if re.search(r'\b%s\.' % other, ready.group(0)):
            errors.append(f"autoload order: {name}._ready() uses {other}, "
                          f"which loads after it")

# --- 3a5. a sprite with no picture in it
#
# Sprite2D.new() gives a node that positions, scales, rotates and reports a
# perfectly sensible transform while drawing absolutely nothing. The companion
# on the dressing-room stage was built this way for weeks: the picture was
# loaded, measured, and used to compute the scale -- and never assigned. It
# looked like "choosing the puppy does nothing", which is not a phrase anybody
# would search the drawing code for.
for path in gd:
    lines = open(path).read().splitlines()
    for i, line in enumerate(lines):
        m = re.search(r'(?:var\s+)?(\w+)\s*(?::=|=|:\s*Sprite2D\s*=)\s*'
                      r'Sprite2D\.new\(\)', line)
        if not m:
            continue
        name = m.group(1)
        window = "\n".join(lines[i:i + 16])
        if not re.search(r'\b%s\.texture\s*=' % re.escape(name), window):
            errors.append(f"{os.path.relpath(path)}:{i+1}: '{name}' is a "
                          f"Sprite2D that never gets a texture -- it will "
                          f"draw nothing at all")

# --- 5m. a face the game cannot draw
#
# A skin is data: crest_kind and chest_pattern are strings a .tres hands to
# HeroArt's match statements. A typo does not crash and does not warn -- the
# match falls through and the character is simply drawn bald, which nobody
# notices until a six-year-old asks where the cat ears went. So every value
# any skin asks for must be an arm HeroArt actually draws, and every arm
# HeroArt draws should be worn by somebody.
skins = {}
for path in sorted(glob.glob("resources/skins/*.tres")):
    src = open(path).read()
    skins[os.path.basename(path)[:-5]] = {
        "crest": (re.search(r'crest_kind\s*=\s*"(\w+)"', src) or [None, ""])[1]
                 if re.search(r'crest_kind\s*=\s*"(\w+)"', src) else "",
        "pattern": (re.search(r'chest_pattern\s*=\s*"(\w+)"', src).group(1)
                    if re.search(r'chest_pattern\s*=\s*"(\w+)"', src) else ""),
        "renderer": (re.search(r'renderer\s*=\s*"(\w+)"', src).group(1)
                     if re.search(r'renderer\s*=\s*"(\w+)"', src) else "hero"),
    }
hero_art_src = open(res("res://scripts/world/hero_art.gd")).read()
drawn_arms = match_arms("scripts/world/hero_art.gd")
# `"blade", _:` is the default arm and match_arms only reads all-quoted labels.
drawn_arms |= set(re.findall(r'^\s*"(\w+)"\s*,\s*_\s*:\s*$',
                             hero_art_src, re.M))
used_crest, used_pattern = set(), set()
for sid, d in sorted(skins.items()):
    if d["renderer"] != "hero":
        continue
    for key, field in (("crest", "crest_kind"), ("pattern", "chest_pattern")):
        value = d[key]
        if value == "":
            continue          # the .tres omitted it: the export default applies
        (used_crest if key == "crest" else used_pattern).add(value)
        if value not in drawn_arms:
            errors.append(f"{sid}.tres: {field} '{value}' is not something "
                          f"hero_art.gd draws -- that character renders bare")
# The enum in character_skin.gd is what an editor offers; it must not promise
# a shape the drawing does not have.
skin_script = open(res("res://scripts/skin/character_skin.gd")).read()
for field in ("crest_kind", "chest_pattern"):
    m = re.search(r'@export_enum\(([^)]*)\)\s*(?:\n)?var %s' % field, skin_script)
    if not m:
        continue
    for value in re.findall(r'"(\w+)"', m.group(1)):
        if value not in drawn_arms:
            errors.append(f"character_skin.gd: {field} offers '{value}', "
                          f"which hero_art.gd cannot draw")
        elif value not in (used_crest if field == "crest_kind" else used_pattern):
            warnings.append(f"{field} '{value}' is drawn but no character "
                            f"wears it")

# --- 5n. the cast holds together
#
# Fourteen faces across three files: characters.json says who exists,
# strings.json names them, resources/skins holds the design, and shop_items
# carries the four that cost stars. A face missing from any one of them is a
# blank card, an empty name, or a character who can never be chosen.
cast = json.load(open("data/characters.json"))["characters"]
who_items = {i["id"]: i for i in shop_items if i["category"] == "who"}
for cid, meta in sorted(cast.items()):
    skin_path = res(meta.get("skin", ""))
    if not os.path.exists(skin_path):
        errors.append(f"characters.json: '{cid}' points at {meta.get('skin')}, "
                      f"which is not on disk")
    for locale in ("zh", "en"):
        if meta.get("name_key", "") not in strings.get(locale, {}):
            errors.append(f"strings.json: no {locale} name for character '{cid}'")
    if "who_" + cid not in who_items:
        errors.append(f"shop_items.json: character '{cid}' has no card in the "
                      f"形象 drawer, so he can never be chosen")
for iid, entry in sorted(who_items.items()):
    cid = entry.get("character_id", "")
    if cid not in cast:
        errors.append(f"shop_items.json: '{iid}' is a card for character "
                      f"'{cid}', who is not in characters.json")
    free = bool(cast.get(cid, {}).get("unlocked", False))
    if free and entry["price"] != 0:
        errors.append(f"shop_items.json: '{iid}' is free from the start but "
                      f"is priced at {entry['price']}")
    if not free and entry["price"] <= 0:
        errors.append(f"shop_items.json: '{iid}' costs nothing but is not "
                      f"unlocked, so nothing can ever hand it over")

print("=" * 60)
print(f"scripts: {len(gd)}   scenes: {len(tscn)}   levels: {len(levels)}")
print(f"playable now: {len(playable)}/{len(levels)}  -> {', '.join(playable)}")
missing_templates = sorted({lv["game_type"] for lv in levels
                            if not os.path.exists(res(mapping.get(lv["game_type"], "")))})
print(f"templates still to build: {', '.join(missing_templates) or 'none'}")
print("=" * 60)
for w in warnings:
    print("WARN ", w)
for e in errors:
    print("ERROR", e)
print("=" * 60)
print(f"{len(errors)} errors, {len(warnings)} warnings")
sys.exit(1 if errors else 0)
