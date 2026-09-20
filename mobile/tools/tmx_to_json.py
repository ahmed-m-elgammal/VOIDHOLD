import base64
import gzip
import json
import struct
import sys
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path


def is_true(value):
    if value is None:
        return False
    if isinstance(value, bool):
        return value
    text = str(value).strip().lower()
    return text == "true" or text == "1" or text == "yes"


def decode_gids(data_node, width, height):
    count = width * height
    encoding = data_node.get("encoding")
    compression = data_node.get("compression")
    if encoding == "base64":
        text = "".join(data_node.itertext()).strip()
        raw = base64.b64decode(text)
        if compression == "gzip":
            raw = gzip.decompress(raw)
        elif compression == "zlib":
            raw = zlib.decompress(raw)
        total = int(len(raw) / 4)
        values = struct.unpack("<" + "I" * total, raw)
        return [int(v & 0x1FFFFFFF) for v in values[:count]]
    if encoding == "csv":
        text = "".join(data_node.itertext()).strip()
        out = []
        for part in text.replace("\n", ",").split(","):
            part = part.strip()
            if part == "":
                continue
            out.append(int(part) & 0x1FFFFFFF)
        return out[:count]
    tiles = data_node.findall("tile")
    if tiles:
        return [(int(t.get("gid", "0")) & 0x1FFFFFFF) for t in tiles[:count]]
    return [0] * count


def load_gid_props(root):
    props_by_gid = {}
    for tileset in root.findall("tileset"):
        first = int(tileset.get("firstgid", "1"))
        for tile in tileset.findall("tile"):
            gid = first + int(tile.get("id", "0"))
            props = {}
            prop_parent = tile.find("properties")
            if prop_parent is not None:
                for p in prop_parent.findall("property"):
                    name = p.get("name")
                    if name is not None:
                        props[name] = p.get("value")
            props_by_gid[gid] = props
    return props_by_gid


def find_layer(root, wanted, fallback):
    layers = root.findall("layer")
    for layer in layers:
        if layer.get("name") == wanted:
            return layer
    if 0 <= fallback < len(layers):
        return layers[fallback]
    return None


def empty_payload(width, height):
    return {
        "width": width,
        "height": height,
        "walkable": [],
        "mineable": [],
        "farmable": [],
        "oreMineable": [],
        "noFence": [],
        "spawns": []
    }


def build_payload(root):
    width = int(root.get("width", "210"))
    height = int(root.get("height", "210"))
    gid_props = load_gid_props(root)
    obstacle_layer = find_layer(root, "planet obstacles", 1)
    spawn_layer = find_layer(root, "enemy spawn", 3)
    if obstacle_layer is None or spawn_layer is None:
        return empty_payload(width, height)
    obstacle_data = obstacle_layer.find("data")
    spawn_data = spawn_layer.find("data")
    if obstacle_data is None or spawn_data is None:
        return empty_payload(width, height)
    obstacle_gids = decode_gids(obstacle_data, width, height)
    spawn_gids = decode_gids(spawn_data, width, height)
    walkable = []
    mineable = []
    farmable = []
    ore_mineable = []
    no_fence = []
    for y in range(height):
        for x in range(width):
            idx = y * width + x
            gid = obstacle_gids[idx] if idx < len(obstacle_gids) else 0
            if gid == 0:
                walkable.append([x, y])
                continue
            props = gid_props.get(gid, {})
            if is_true(props.get("noFence")):
                no_fence.append([x, y])
            else:
                walkable.append([x, y])
            if is_true(props.get("isMineable")):
                mineable.append([x, y])
            if is_true(props.get("isFarmable")):
                farmable.append([x, y])
            if is_true(props.get("isOreMineable")):
                ore_mineable.append([x, y])
    spawns = []
    for y in range(height):
        for x in range(width):
            idx = y * width + x
            if idx < len(spawn_gids) and spawn_gids[idx] != 0:
                spawns.append([x, y])
    return {
        "width": width,
        "height": height,
        "walkable": walkable,
        "mineable": mineable,
        "farmable": farmable,
        "oreMineable": ore_mineable,
        "noFence": no_fence,
        "spawns": spawns
    }


def main(argv):
    here = Path(__file__).resolve()
    default_tmx = here.parents[2] / "maps" / "map.tmx"
    default_out = here.parents[1] / "data" / "grid.json"
    tmx_path = Path(argv[1]) if len(argv) > 1 else default_tmx
    out_path = Path(argv[2]) if len(argv) > 2 else default_out
    width = 210
    height = 210
    payload = empty_payload(width, height)
    if tmx_path.is_file():
        root = ET.parse(str(tmx_path)).getroot()
        width = int(root.get("width", "210"))
        height = int(root.get("height", "210"))
        payload = build_payload(root)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(payload, f)
    sys.stdout.write("wrote " + str(out_path) + " " + str(width) + "x" + str(height) + " walkable=" + str(len(payload["walkable"])) + " mineable=" + str(len(payload["mineable"])) + " farmable=" + str(len(payload["farmable"])) + " oreMineable=" + str(len(payload["oreMineable"])) + " noFence=" + str(len(payload["noFence"])) + " spawns=" + str(len(payload["spawns"])) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
