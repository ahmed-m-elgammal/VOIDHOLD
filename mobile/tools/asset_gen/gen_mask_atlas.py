#!/usr/bin/env python3
"""E2-01 — logical mask atlas generated from the data contract.

Reads mobile/data/grid.json (the canonical baked logical grid) and emits:

  logical_mask_a.png  210x210 RGBA  R=walkable  G=mineable  B=farmable  A=oreMineable
  logical_mask_b.png  210x210 RGBA  R=noFence   G=spawn    B=reserved A=reserved
  logical_mask_preview.png  8x nearest upscale with human-readable colors

Each pixel maps 1:1 to one logical tile. Import in Godot with nearest
filtering and mipmaps OFF. The masks are generated directly from the data
contract, never hand-painted, so they always match simulation data.

Usage: python3 gen_mask_atlas.py [--grid PATH] [--out DIR]
"""
import argparse, json, os
import numpy as np
from PIL import Image

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--grid", default="/home/z/my-project/VOIDHOLD/mobile/data/grid.json")
    ap.add_argument("--out", default="/home/z/my-project/VOIDHOLD/mobile/assets/world/masks")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    g = json.load(open(args.grid))
    W, H = g["width"], g["height"]

    def stamp(prop):
        m = np.zeros((H, W), np.float32)
        for x, y in g.get(prop, []):
            if 0 <= x < W and 0 <= y < H:
                m[y, x] = 1.0
        return m

    walkable, mineable = stamp("walkable"), stamp("mineable")
    farmable, oremine = stamp("farmable"), stamp("oreMineable")
    nofence, spawns = stamp("noFence"), stamp("spawns")

    a = np.stack([walkable, mineable, farmable, oremine], axis=-1)
    b = np.stack([nofence, spawns, np.zeros_like(walkable), np.zeros_like(walkable)], axis=-1)

    Image.fromarray((a * 255).astype(np.uint8)).save(os.path.join(args.out, "logical_mask_a.png"), optimize=True)
    Image.fromarray((b * 255).astype(np.uint8)).save(os.path.join(args.out, "logical_mask_b.png"), optimize=True)
    print(f"  wrote logical_mask_a.png / logical_mask_b.png  ({W}x{H}, 1px = 1 tile)")

    # human-readable preview (8x nearest, color-coded)
    up = 8
    img = Image.new("RGB", (W * up, H * up), (10, 14, 20))
    px = img.load()
    colors = {
        "walkable": (232, 238, 244), "mineable": (107, 114, 128),
        "farmable": (53, 208, 127), "oreMineable": (255, 176, 32),
        "noFence": (95, 212, 232), "spawn": (255, 77, 77),
    }
    order = [("walkable", walkable), ("mineable", mineable), ("farmable", farmable),
             ("oreMineable", oremine), ("noFence", nofence), ("spawn", spawns)]
    base = np.zeros((H, W, 3), np.float32)
    for name, m in order:                       # later layers win; spawn last = top
        hit = m > 0.5
        base[hit] = np.array(colors[name], np.float32) / 255.0
    arr = (base * 255).astype(np.uint8)
    img = Image.fromarray(arr).resize((W * up, H * up), Image.NEAREST)
    img.save(os.path.join(args.out, "logical_mask_preview.png"), optimize=True)
    print("  wrote logical_mask_preview.png")

    counts = {k: len(v) for k, v in g.items() if isinstance(v, list)}
    print("  tile counts:", counts)

if __name__ == "__main__":
    main()
