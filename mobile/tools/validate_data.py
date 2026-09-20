import csv
import json
import sys
from pathlib import Path


def load_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def load_keys(path):
    with open(path, "r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        return sorted([r["key"] for r in reader])


def main(argv):
    root = Path(argv[0]).resolve().parent.parent if len(argv) > 0 else Path(".")
    data_dir = root / "data"
    buildings = load_json(data_dir / "buildings.json")
    balance = load_json(data_dir / "balance.json")
    moons = load_json(data_dir / "moons.json")
    grid = load_json(data_dir / "grid.json")
    tech = load_json(data_dir / "tech_tree.json")
    en_keys = load_keys(data_dir / "strings_en.csv")
    ar_keys = load_keys(data_dir / "strings_ar.csv")
    passed = 0
    failed = 0

    def report(name, ok, detail=""):
        nonlocal_pass = [passed, failed]
        line = name + " PASS " + detail if ok else name + " FAIL " + detail
        sys.stdout.write(line.strip() + "\n")
        return ok

    results = []
    want_ids = sorted(["authority", "bar", "cantine", "elevator", "factory", "farm", "farmarea", "kitchen", "living", "maintenance", "mine", "mineshaft", "oremine", "oxygen", "quarter", "solar", "storage", "teleport"])
    ok = sorted(buildings.keys()) == want_ids and len(buildings) == 18
    results.append(report("buildings_count_18", ok, "found " + str(len(buildings))))
    allowed = {"stone", "alloy", "biomass", "ore", "stim"}
    used = set()
    bad = []
    for bid, entry in buildings.items():
        for slot in ("input", "output"):
            node = entry.get(slot)
            if isinstance(node, dict) and "resource" in node:
                used.add(node["resource"])
                if node["resource"] not in allowed:
                    bad.append(bid + ":" + slot + "=" + str(node["resource"]))
    ok = len(bad) == 0 and used.issubset(allowed)
    results.append(report("canonical_resources_only", ok, "used " + ",".join(sorted(used))))
    pre = tech.get("preconditions", {})
    tabs = tech.get("tabs", {})
    ok = set(pre.keys()) == set(buildings.keys())
    results.append(report("tech_preconditions_keys", ok, "keys " + str(len(pre))))
    bad_refs = []
    for k, v in pre.items():
        if v is not None and v not in buildings:
            bad_refs.append(k + "->" + str(v))
    for group, members in tabs.items():
        for m in members:
            if m not in buildings:
                bad_refs.append(group + ":" + m)
    flat = []
    for members in tabs.values():
        flat.extend(members)
    ok = len(bad_refs) == 0 and sorted(flat) == want_ids
    results.append(report("tech_tree_refs", ok, "bad " + str(len(bad_refs))))
    moon_list = moons.get("moons", [])
    want_pack = {"stone": 60, "alloy": 20, "biomass": 30, "ore": 0, "stim": 10}
    ok = len(moon_list) == 3
    results.append(report("moons_count_3", ok, "found " + str(len(moon_list))))
    pack_ok = True
    for m in moon_list:
        if m.get("start_resources") != want_pack:
            pack_ok = False
        g = m.get("grid", {})
        if g.get("width") != 210 or g.get("height") != 210:
            pack_ok = False
    results.append(report("moons_start_pack", pack_ok, "stone=60 alloy=20 biomass=30 ore=0 stim=10"))
    ok = len(en_keys) >= 84 and len(en_keys) == len(ar_keys) and en_keys == ar_keys
    results.append(report("strings_match_min84", ok, "en " + str(len(en_keys)) + " ar " + str(len(ar_keys))))
    ok = int(grid.get("width", -1)) == 210 and int(grid.get("height", -1)) == 210
    results.append(report("grid_210x210", ok, str(grid.get("width")) + "x" + str(grid.get("height"))))
    ok = float(balance.get("energy", {}).get("per_solar", -1)) == 1.5
    results.append(report("balance_energy_per_solar", ok, "1.5"))
    ok = int(balance.get("enemy", {}).get("cap", -1)) == 3
    results.append(report("balance_enemy_cap_3", ok, "cap 3"))
    passed = sum(1 for v in results if v)
    failed = sum(1 for v in results if not v)
    sys.stdout.write("validate: " + str(passed) + " PASS, " + str(failed) + " FAIL" + "\n")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
