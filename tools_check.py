import json, os, re, sys, glob

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
for f in gd + tscn + tres + ["project.godot"]:
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
    for method in re.findall(r'\.connect\(\s*(_\w+)', src):
        if method not in defined:
            errors.append(f"{f}: connect() references {method}(), which is not "
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
        r'|memory|rescue|platformer|blaster|colour)\.[a-z0-9_]+)"', src))
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

STUDIO = "hero_studio"          # the free-play room; not one of the thirty
# Bonus levels are treats sitting beside the curriculum -- always unlocked,
# never required, and deliberately outside the ratio. Counting them would let
# somebody "fix" a platformer-heavy island by adding bonus puzzles, which
# fixes the number and not the problem.
numbered = [l for l in levels
            if l.get("id") != STUDIO and not l.get("bonus", False)]
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
        "action": (5, 20), "keepsake": (5, 25), "wardrobe": (15, 60),
        "fx": (25, 50), "base": (25, 70), "pal": (60, 90), "ride": (70, 120),
    }
    seen_ids = set()
    for it in shop_items:
        iid = it["id"]
        if iid in seen_ids:
            errors.append(f"shop_items.json: duplicate id '{iid}'")
        seen_ids.add(iid)
        if it["category"] not in cat_ids:
            errors.append(f"shop_items.json: '{iid}' is in category "
                          f"'{it['category']}', which does not exist")
        # A missing icon is a blank card. Silent, and the child cannot tell
        # what he is being offered.
        if it["icon"] not in icon_names:
            errors.append(f"shop_items.json: '{iid}' wants icon "
                          f"'{it['icon']}', which IconLibrary cannot draw")
        lo, hi = BANDS.get(it["category"], (1, 1000))
        if not lo <= it["price"] <= hi:
            errors.append(f"shop_items.json: '{iid}' costs {it['price']}, "
                          f"outside the {lo}-{hi} band for {it['category']}")
        # A garment nobody can wear is a garment nobody should be sold.
        if it["slot"] and not it["character_compatibility"]:
            errors.append(f"shop_items.json: '{iid}' fills the "
                          f"'{it['slot']}' slot but fits no character")

    for cat in shop_cats:
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
