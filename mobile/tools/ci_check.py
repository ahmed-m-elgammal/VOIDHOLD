import csv
import json
import sys
import time
from pathlib import Path


MOBILE = Path(__file__).resolve().parents[1]
DATA = MOBILE / "data"
REPORTS = MOBILE / "reports"
GAME = MOBILE.parent
BUNDLE = "com.voidhold.colony"
GRID_KEYS = ("walkable", "mineable", "farmable", "oreMineable", "noFence", "spawns")
PROVENANCE_MARKERS = ("imagesoga", "ogaunused", "music-oga")
SAVE_BUDGET_MS = 300.0
FRAME_P95_LOW_MS = 33.3
FRAME_P95_MID_HIGH_MS = 20.0
FAST_FORWARD_LOW_S = 5.0
FAST_FORWARD_MID_HIGH_S = 2.0
SKIP_DIRS = {".godot", "build", ".git", "__pycache__", ".hg", ".svn"}


def record(results, name, ok, detail):
    results.append({"name": name, "ok": bool(ok), "detail": str(detail)})
    return bool(ok)


def check_json(results):
    files = sorted(DATA.glob("*.json"))
    if not files:
        return record(results, "json-parse", False, "no json files under data/")
    bad = []
    count = 0
    for path in files:
        try:
            with open(path, "r", encoding="utf-8") as handle:
                json.load(handle)
            count += 1
        except (OSError, ValueError) as exc:
            bad.append(path.name + ": " + str(exc))
    if bad:
        return record(results, "json-parse", False, "; ".join(bad[:8]))
    return record(results, "json-parse", True, str(count) + " files parsed")


def read_keys(path):
    with open(path, "r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None or "key" not in reader.fieldnames:
            return None, ["missing key column in " + path.name]
        seen = set()
        dups = []
        for row in reader:
            key = (row.get("key") or "").strip()
            if key == "":
                continue
            if key in seen:
                dups.append(key)
            seen.add(key)
    return seen, dups


def check_strings(results):
    en_path = DATA / "strings_en.csv"
    ar_path = DATA / "strings_ar.csv"
    if not en_path.is_file() or not ar_path.is_file():
        return record(results, "csv-keys", False, "strings_en.csv or strings_ar.csv absent")
    try:
        en_keys, en_dups = read_keys(en_path)
        ar_keys, ar_dups = read_keys(ar_path)
    except OSError as exc:
        return record(results, "csv-keys", False, "unreadable csv: " + str(exc))
    problems = []
    problems.extend("duplicate en key " + key for key in en_dups[:5])
    problems.extend("duplicate ar key " + key for key in ar_dups[:5])
    if en_keys is not None and ar_keys is not None:
        for key in sorted(en_keys - ar_keys)[:10]:
            problems.append("absent from ar: " + key)
        for key in sorted(ar_keys - en_keys)[:10]:
            problems.append("absent from en: " + key)
    if problems:
        return record(results, "csv-keys", False, "; ".join(problems[:12]))
    return record(results, "csv-keys", True, str(len(en_keys)) + " keys match en/ar")


def check_grid(results):
    path = DATA / "grid.json"
    try:
        with open(path, "r", encoding="utf-8") as handle:
            grid = json.load(handle)
    except (OSError, ValueError) as exc:
        return record(results, "grid", False, "unreadable grid.json: " + str(exc))
    width = grid.get("width")
    height = grid.get("height")
    if not isinstance(width, int) or not isinstance(height, int) or width <= 0 or height <= 0:
        return record(results, "grid", False, "invalid dims")
    problems = []
    cells_by_key = {}
    for key in GRID_KEYS:
        cells = grid.get(key, [])
        if not isinstance(cells, list):
            problems.append(key + " not a list")
            continue
        points = set()
        for cell in cells:
            if not isinstance(cell, list) or len(cell) != 2:
                problems.append(key + " has malformed cell")
                break
            if not all(isinstance(v, int) for v in cell):
                problems.append(key + " has non-integer cell")
                break
            x, y = cell
            if x < 0 or y < 0 or x >= width or y >= height:
                problems.append(key + " out of bounds at [" + str(x) + ", " + str(y) + "]")
                break
            points.add((x, y))
        cells_by_key[key] = points
    if problems:
        return record(results, "grid", False, "; ".join(problems[:6]))
    overlap = cells_by_key.get("walkable", set()) & cells_by_key.get("noFence", set())
    if overlap:
        sample = sorted(overlap)[:4]
        return record(results, "grid", False, "walk intersects noFence at " + str(sample))
    spawns = len(cells_by_key.get("spawns", set()))
    if spawns <= 0:
        return record(results, "grid", False, "no spawns")
    detail = (
        str(width) + "x" + str(height)
        + " walk=" + str(len(cells_by_key["walkable"]))
        + " noFence=" + str(len(cells_by_key["noFence"]))
        + " spawns=" + str(spawns)
    )
    return record(results, "grid", True, detail)


def check_provenance(results):
    # Scan every shipped asset tree for quarantined-pack markers. The
    # legacy roots are kept for historical completeness; mobile/assets is
    # the live Epic 2+ asset library and must always be covered.
    roots = [MOBILE / "assets", GAME / "art_final", MOBILE / "art"]
    hits = []
    scanned = 0
    skipped = []
    for root in roots:
        if not root.is_dir():
            skipped.append(root.name)
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            # Markdown provenance/README docs legitimately reference the
            # quarantine marker list itself; scan shipped assets, not docs.
            if path.suffix.lower() in (".md", ".rst", ".txt"):
                continue
            scanned += 1
            try:
                text = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            lowered = text.lower()
            if any(mark in lowered for mark in PROVENANCE_MARKERS):
                try:
                    hits.append(path.relative_to(GAME).as_posix())
                except ValueError:
                    hits.append(str(path))
    if hits:
        return record(results, "provenance", False, "; ".join(hits[:10]))
    note = str(scanned) + " files scanned"
    if skipped:
        note = note + " (" + ",".join(skipped) + " absent)"
    return record(results, "provenance", True, note)


def check_renderer(results):
    path = MOBILE / "project.godot"
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError as exc:
        return record(results, "renderer", False, "unreadable project.godot: " + str(exc))
    if "gl_compatibility" in text:
        return record(results, "renderer", False, "gl_compatibility present")
    if 'renderer/rendering_method="mobile"' in text:
        return record(results, "renderer", True, "rendering_method mobile")
    return record(results, "renderer", False, "rendering_method is not mobile")


def parse_preset(text):
    values = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("[") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("\"", "'"):
            value = value[1:-1]
        values[key.strip()] = value
    return values


def check_export(results):
    path = MOBILE / "export_presets.cfg"
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError as exc:
        return record(results, "export", False, "unreadable export_presets.cfg: " + str(exc))
    values = parse_preset(text)
    problems = []
    if values.get("gradle_build/target_sdk_version") != "36":
        problems.append("target_sdk=" + values.get("gradle_build/target_sdk_version", "?") + " want 36")
    if values.get("gradle_build/min_sdk_version") != "24":
        problems.append("min_sdk=" + values.get("gradle_build/min_sdk_version", "?") + " want 24")
    if values.get("package/unique_name") != BUNDLE:
        problems.append("android bundle=" + values.get("package/unique_name", "?"))
    if values.get("application/bundle_identifier") != BUNDLE:
        problems.append("ios bundle=" + values.get("application/bundle_identifier", "?"))
    if problems:
        return record(results, "export", False, "; ".join(problems))
    return record(results, "export", True, "target 36 min 24 bundle " + BUNDLE)


def report_package_size():
    total = 0
    files = 0
    per_dir = {}
    largest = []
    for path in MOBILE.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(MOBILE)
        if any(part in SKIP_DIRS for part in rel.parts):
            continue
        size = path.stat().st_size
        total += size
        files += 1
        top = rel.parts[0] if len(rel.parts) > 1 else "(root)"
        per_dir[top] = per_dir.get(top, 0) + size
        largest.append((size, rel.as_posix()))
    largest.sort(reverse=True)
    payload = {
        "bytes": total,
        "mb": round(total / 1048576.0, 2),
        "files": files,
        "by_dir": {k: {"bytes": v, "mb": round(v / 1048576.0, 2)} for k, v in sorted(per_dir.items())},
        "largest": [{"path": p, "bytes": s} for s, p in largest[:10]],
    }
    REPORTS.mkdir(parents=True, exist_ok=True)
    with open(REPORTS / "package-size.json", "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")
    return payload


def measure_grid_load_ms():
    path = DATA / "grid.json"
    start = time.perf_counter()
    with open(path, "r", encoding="utf-8") as handle:
        json.load(handle)
    return (time.perf_counter() - start) * 1000.0


def measure_save_ms():
    buildings = []
    for i in range(96):
        buildings.append({"id": i, "kind": "mine", "damage": 0.0, "output": 1.0, "workers": 2})
    units = []
    for i in range(48):
        units.append({"id": i, "caste": "helot", "fullness": 0.9, "job": "work"})
    payload = {
        "save_version": 1,
        "playtime_s": 3600.0,
        "domes": [{"id": 0, "buildings": buildings, "units": units}],
    }
    worst = 0.0
    for _ in range(5):
        start = time.perf_counter()
        text = json.dumps(payload)
        json.loads(text)
        worst = max(worst, (time.perf_counter() - start) * 1000.0)
    return worst


def check_perf(results):
    grid_ms = measure_grid_load_ms()
    save_ms = measure_save_ms()
    save_ok = save_ms < SAVE_BUDGET_MS
    payload = {
        "thresholds": {
            "frame_p95_ms": {"low": FRAME_P95_LOW_MS, "mid_high": FRAME_P95_MID_HIGH_MS},
            "save_ms": SAVE_BUDGET_MS,
            "fast_forward_s": {"low": FAST_FORWARD_LOW_S, "mid_high": FAST_FORWARD_MID_HIGH_S},
        },
        "measurements": {
            "grid_load_ms": round(grid_ms, 2),
            "save_roundtrip_ms": round(save_ms, 2),
            "save_status": "pass" if save_ok else "fail",
            "frame_p95_ms": None,
            "frame_status": "pending-device",
            "fast_forward_s": None,
            "fast_forward_status": "pending-device",
        },
    }
    REPORTS.mkdir(parents=True, exist_ok=True)
    with open(REPORTS / "perf-budget.json", "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")
    detail = (
        "save " + str(round(save_ms, 2)) + "ms/300ms"
        + " grid_load " + str(round(grid_ms, 2)) + "ms"
        + " frame+ff pending-device"
        + " -> reports/perf-budget.json"
    )
    return record(results, "perf-budget", save_ok, detail)


def main():
    results = []
    check_json(results)
    check_strings(results)
    check_grid(results)
    check_provenance(results)
    check_renderer(results)
    check_export(results)
    size = report_package_size()
    record(
        results,
        "package-size",
        True,
        str(size["mb"]) + " MB across " + str(size["files"]) + " files -> reports/package-size.json",
    )
    check_perf(results)
    failures = 0
    for item in results:
        mark = "PASS" if item["ok"] else "FAIL"
        if not item["ok"]:
            failures += 1
        sys.stdout.write("[" + mark + "] " + item["name"] + " - " + item["detail"] + "\n")
    summary = "PASS" if failures == 0 else "FAIL"
    sys.stdout.write(
        "RESULT: " + summary + " " + str(len(results) - failures) + "/" + str(len(results)) + "\n"
    )
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
