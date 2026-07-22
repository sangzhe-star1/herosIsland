import json, os, re, sys, glob

root = "."
errors, warnings = [], []

def res(p):  # res://x -> ./x
    return p.replace("res://", "./", 1)

gd = glob.glob("scripts/**/*.gd", recursive=True)
tscn = glob.glob("scenes/**/*.tscn", recursive=True)
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

# --- 4. localization keys
strings = json.load(open("data/strings.json"))
en, zh = strings["en"], strings["zh"]
used = set()
for f in gd:
    src = open(f).read()
    used |= set(re.findall(r'I18n\.t\(\s*"([^"]+)"', src))
    # keys built indirectly, e.g. praise_key = "result.great"
    used |= set(re.findall(
        r'"((?:app|common|boot|home|map|world|level|badge|growth|character'
        r'|traffic|result|parent|rewards|limit|sorting|bin|item|collect)\.[a-z0-9_]+)"', src))
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

# every world's growth_attribute is real
for w in json.load(open("data/worlds.json")):
    if w["growth_attribute"] not in growth_ids:
        errors.append(f"worlds.json: {w['id']} unknown growth_attribute")

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
