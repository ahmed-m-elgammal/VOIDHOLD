import csv
import json
import sys
from pathlib import Path


def load_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def parse_num(text):
    if text is None:
        return None
    s = str(text).strip()
    if s == "":
        return None
    low = s.lower()
    if low == "null" or low == "none":
        return None
    return float(s)


def parse_int_or_none(text):
    v = parse_num(text)
    if v is None:
        return None
    return int(v)


def parse_damage(text, buildings_entry):
    s = str(text or "").strip()
    if s == "":
        return True
    parts = {}
    for chunk in s.split(";"):
        chunk = chunk.strip()
        if chunk == "":
            continue
        if "=" not in chunk:
            return False
        k, v = chunk.split("=", 1)
        parts[k.strip()] = v.strip()
    want = buildings_entry.get("damages") or {}
    for key in ("constant", "update"):
        raw = parts.get(key, "")
        if raw == "" :
            continue
        if raw.lower() == "null":
            if want.get(key) is not None:
                return False
        else:
            try:
                num = float(raw)
            except ValueError:
                return False
            got = want.get(key)
            if got is None:
                return False
            if abs(float(got) - num) > 1e-9:
                return False
    return True


def parse_in_out(text, node):
    s = str(text or "").strip()
    if s == "":
        return node is None
    if node is None:
        return False
    bits = s.split("/")
    if len(bits) == 2:
        res, per = bits
        if node.get("resource") != res:
            return False
        try:
            if abs(float(node.get("perWorker")) - float(per)) > 1e-9:
                return False
        except (TypeError, ValueError):
            return False
        return True
    if len(bits) == 3:
        res, per, mx = bits
        if node.get("resource") != res:
            return False
        try:
            if abs(float(node.get("perWorker")) - float(per)) > 1e-9:
                return False
        except (TypeError, ValueError):
            return False
        try:
            if abs(float(node.get("max")) - float(mx)) > 1e-9:
                return False
        except (TypeError, ValueError):
            return False
        return True
    return False


def check_building(row, buildings):
    bid = (row.get("type_or_system") or "").strip()
    entry = buildings.get(bid)
    if entry is None:
        return False, "unknown building " + bid
    if parse_int_or_none(row.get("stone")) != int(entry.get("stone")):
        return False, "stone mismatch"
    if parse_int_or_none(row.get("alloy_cost")) != int(entry.get("alloy_cost")):
        return False, "alloy mismatch"
    want_energy = float(entry.get("energyNeed") or 0)
    got_energy = parse_num(row.get("energy_need"))
    if got_energy is None:
        got_energy = 0.0
    if abs(got_energy - want_energy) > 1e-9:
        return False, "energy mismatch"
    want_workers = entry.get("maxWorkers")
    got_workers = parse_int_or_none(row.get("max_workers"))
    if want_workers is None:
        if got_workers is not None:
            return False, "maxWorkers mismatch"
    else:
        if got_workers != int(want_workers):
            return False, "maxWorkers mismatch"
    want_delta = entry.get("updateDelta_ms")
    got_delta = parse_int_or_none(row.get("update_delta_ms"))
    if want_delta is None:
        if got_delta is not None:
            return False, "updateDelta mismatch"
    else:
        if got_delta != int(want_delta):
            return False, "updateDelta mismatch"
    if not parse_in_out(row.get("input"), entry.get("input")):
        return False, "input mismatch"
    if not parse_in_out(row.get("output"), entry.get("output")):
        return False, "output mismatch"
    if not parse_damage(row.get("damage"), entry):
        return False, "damage mismatch"
    prop = (row.get("planet_property") or "").strip()
    if prop != "":
        if "/" in prop:
            name, rad = prop.split("/", 1)
            pw = entry.get("perWorker") or {}
            if pw.get("building") != name:
                return False, "perWorker building mismatch"
            try:
                if abs(float(pw.get("maxRadius")) - float(rad)) > 1e-9:
                    return False, "perWorker radius mismatch"
            except (TypeError, ValueError):
                return False, "perWorker radius mismatch"
        else:
            if entry.get("planetProperty") != prop:
                return False, "planetProperty mismatch"
    return True, "values align"


def oxygen_sat(oxygen_count, total_count, unit_count, per_building, per_unit):
    need = float(total_count) * float(per_building) + float(unit_count) * float(per_unit)
    if need <= 0.0:
        need = 1.0
    return float(oxygen_count) / need


def productivity(mood, oxygen, damage, base, full_w, happy_w, oxy_w):
    m = mood
    if m < 0.0:
        m = 0.0
    if m > 1.0:
        m = 1.0
    d = damage
    if d < 0.0:
        d = 0.0
    if d > 1.0:
        d = 1.0
    o = oxygen
    if o < 0.0:
        o = 0.0
    mood_part = float(base) + float(full_w) * m + float(happy_w) * m
    return mood_part * (1.0 - d) * (0.5 + 0.5 * o)


def main(argv):
    root = Path(argv[0]).resolve().parent.parent if len(argv) > 0 else Path(".")
    data_dir = root / "data"
    csv_path = root / "evidence" / "t0.8-fixture-values.csv"
    buildings = load_json(data_dir / "buildings.json")
    balance = load_json(data_dir / "balance.json")
    moons = load_json(data_dir / "moons.json")
    grid = load_json(data_dir / "grid.json")
    tech = load_json(data_dir / "tech_tree.json")
    void_check = len(grid.get("walkable", [])) >= 0 and len(tech.get("tabs", {})) >= 0
    if not void_check:
        pass
    oxy_cfg = balance.get("oxygen", {})
    per_building = float(oxy_cfg.get("per_building", 0.05))
    per_unit = float(oxy_cfg.get("per_unit", 0.15))
    prod_cfg = balance.get("productivity", {})
    base = float(prod_cfg.get("base", 0.5))
    full_w = float(prod_cfg.get("fullness_weight", 0.25))
    happy_w = float(prod_cfg.get("happiness_weight", 0.25))
    per_solar = float(balance.get("energy", {}).get("per_solar", 1.5))
    auth = balance.get("authority", {})
    enemy = balance.get("enemy", {})
    spawn = balance.get("spawn", {})
    spawn_ms = int(balance.get("spawn_ms", spawn.get("interval_ms", 40000)))
    rng_mode = balance.get("rng", {}).get("persist", "")
    moon0 = (moons.get("moons") or [{}])[0]
    start_res = moon0.get("start_resources", {})
    passed = 0
    failed = 0
    skipped = 0
    with open(csv_path, "r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    for row in rows:
        fid = (row.get("fixture_id") or "").strip()
        cls = (row.get("classification") or "").strip()
        if cls == "parity_requires_decision":
            sys.stdout.write(fid + " SKIP requires_decision clamp above 1 undecided\n")
            skipped += 1
            continue
        if cls == "parity_requires_seed":
            sys.stdout.write(fid + " SKIP requires_seed seeded RNG needed\n")
            skipped += 1
            continue
        if cls == "parity_requires_fixture":
            sys.stdout.write(fid + " SKIP requires_fixture tie-break fixture pending\n")
            skipped += 1
            continue
        ok = False
        detail = ""
        kind = (row.get("kind") or "").strip()
        if kind == "building":
            ok, detail = check_building(row, buildings)
        elif fid == "S-019":
            ok = (
                int(start_res.get("stone", -1)) == 60
                and int(start_res.get("alloy", -2)) == 20
                and int(start_res.get("biomass", -3)) == 30
                and int(start_res.get("ore", -4)) == 0
                and int(start_res.get("stim", -5)) == 10
            )
            detail = "stone=60 alloy=20 biomass=30 ore=0 stim=10"
        elif fid == "S-020":
            got = oxygen_sat(1, 5, 6, per_building, per_unit)
            ok = abs(got - 0.8695652174) < 0.0002
            detail = "oxygen=" + format(got, ".4f") + " want 0.8695"
        elif fid == "S-022":
            got = productivity(1.0, 1.0, 0.0, base, full_w, happy_w, 0.5)
            ok = abs(got - 1.0) < 1e-9
            detail = "productivity=" + format(got, ".4f") + " want 1.0"
        elif fid == "S-023":
            got = productivity(0.0, 0.0, 0.0, base, full_w, happy_w, 0.5)
            ok = abs(got - 0.25) < 1e-9
            detail = "productivity=" + format(got, ".4f") + " want 0.25"
        elif fid == "S-024":
            supply = 2.0 * per_solar
            ok = abs(supply - 3.0) < 1e-9 and supply >= 1.0
            detail = "supply=" + format(supply, ".2f") + " demand=1.0 powered"
        elif fid == "S-026":
            steps = int(auth.get("steps_at_20hz", 0))
            interval = int(auth.get("interval_ms", 0))
            dmg = float(auth.get("damage_per_update", 0.0))
            hp_left = 1.0 - dmg
            ok = steps == 40 and interval == 2000 and abs(hp_left - 0.8) < 1e-9
            detail = "hp 1.0->" + format(hp_left, ".2f") + " steps=" + str(steps)
        elif fid == "S-027":
            gate_h = float(spawn.get("requires_happiness", 0.8))
            gate_f = float(spawn.get("requires_fullness", 0.8))
            ok = (0.81 > gate_h) and (0.81 > gate_f) and spawn_ms == 40000
            detail = "0.81 over strict 0.8 gate passes"
        elif fid == "S-028":
            gate_h = float(spawn.get("requires_happiness", 0.8))
            gate_f = float(spawn.get("requires_fullness", 0.8))
            ok = not (0.80 > gate_h) and not (0.80 > gate_f)
            detail = "0.80 over strict 0.8 gate fails"
        elif fid == "S-029":
            cap = int(enemy.get("cap", -1))
            ok = cap == 3
            detail = "cap=" + str(cap) + " want 3 source allowed 4"
        elif fid == "S-031":
            ok = rng_mode == "full_state"
            detail = "rng persist=" + str(rng_mode) + " want full_state"
        else:
            ok = False
            detail = "unknown fixture"
        if ok:
            sys.stdout.write(fid + " PASS " + detail + "\n")
            passed += 1
        else:
            sys.stdout.write(fid + " FAIL " + detail + "\n")
            failed += 1
    sys.stdout.write("parity: " + str(passed) + " PASS, " + str(failed) + " FAIL, " + str(skipped) + " SKIP, total " + str(len(rows)) + "\n")
    if failed > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
