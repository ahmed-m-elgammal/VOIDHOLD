#!/usr/bin/env python3
"""E2-01 — VOIDHOLD planet ground material set.

Generates seamlessly tileable PBR texture sets (albedo, OpenGL normal,
roughness, AO) for four ground materials of the frozen exomoon:

  snow       #E8EEF4 broad soft dunes, faint sparkle
  compacted  trodden snow / construction paths, flatter and darker
  rock       #6B7280 exposed basalt with cracks and mineral patches
  ice        blue glacial ice, smooth with deep pressure cracks

Plus a low-frequency macro variation map used by the ground shader to
break up tiling across the 210x210 planet surface.

Usage: python3 gen_ground_textures.py [--size 1024] [--out DIR]
Original procedural work generated for VOIDHOLD: Moon Colony.
"""
import argparse, os
import numpy as np
from PIL import Image

import vh_common as vh

def save(img_arr, path):
    Image.fromarray(vh.to_u8(img_arr)).save(path, optimize=True)
    print("  wrote", path)

# ----------------------------------------------------------------- snow ---
def gen_snow(S, seed=101):
    rng = np.random.default_rng(seed)
    broad = vh.fbm(S, seed, 3, 4)                       # dunes
    medium = vh.fbm(S, seed + 7, 12, 4)
    fine = vh.fbm(S, seed + 13, 48, 3)
    h = broad * 0.65 + medium * 0.25 + fine * 0.10
    h = vh.warp(S, h, S * 0.02, seed + 3)

    base = vh.hex2rgb(vh.PALETTE["snow"])
    shade = vh.hex2rgb("#C9D6E2")                       # crevice blue tint
    spark_mask = (fine > 0.985).astype(np.float32)      # sparse glints
    alb = vh.mix(base, shade, np.clip((1.0 - broad) * 0.75 + medium * 0.20, 0, 1))
    alb *= (1.0 - (1.0 - vh.ao_from_height(h, 5, 0.9)) * 0.55)[..., None]
    alb += spark_mask[..., None] * 0.06
    alb = np.clip(alb + vh.grain(rng, S, 0.008)[..., None], 0, 1)

    rough = 0.90 - medium * 0.08 - spark_mask * 0.25 + fine * 0.04
    nrm = vh.normal_map(h, 1.6)
    ao = vh.ao_from_height(h, 6, 1.0)
    return alb, nrm, rough, ao

# ------------------------------------------------------------ compacted ---
def gen_compacted(S, seed=202):
    rng = np.random.default_rng(seed)
    flat = vh.fbm(S, seed, 4, 4)
    streaks = vh.fbm(S, seed + 5, 6, 4)
    fine = vh.fbm(S, seed + 9, 40, 3)
    # directional traffic streaks: stretch noise vertically (tile-safe)
    lat = vh._lattice(np.random.default_rng(seed + 11), 16)
    sv = (np.arange(S) + 0.5) / S
    su = (np.arange(S) + 0.5) / S
    streak = vh._sample(lat, np.repeat(su[None, :], S, 0) * 0.35,
                        np.repeat(sv[:, None], S, 1))
    h = flat * 0.35 + streak * 0.25 + fine * 0.40
    h = vh.warp(S, h, S * 0.015, seed + 3)

    base = vh.hex2rgb("#D6DEE6")                        # slightly dirtier white
    dark = vh.hex2rgb("#B4C2CE")
    alb = vh.mix(base, dark, (1.0 - flat) * 0.5 + streak * 0.2)
    alb *= (1.0 - (1.0 - vh.ao_from_height(h, 4, 0.8)) * 0.45)[..., None]
    alb = np.clip(alb + vh.grain(rng, S, 0.012)[..., None], 0, 1)

    rough = 0.82 + fine * 0.10
    nrm = vh.normal_map(h, 2.2)
    ao = vh.ao_from_height(h, 5, 1.1)
    return alb, nrm, rough, ao

# ----------------------------------------------------------------- rock ---
def gen_rock(S, seed=303):
    rng = np.random.default_rng(seed)
    jag = vh.fbm(S, seed, 5, 5)
    crk = vh.ridged(S, seed + 4, 6, 4)
    patches = vh.fbm(S, seed + 8, 3, 3)
    h = jag * 0.75 + vh.warp(S, crk, S * 0.03, seed + 2) * 0.25
    cracks = np.clip((crk > 0.88).astype(np.float32) * (crk - 0.88) / 0.12, 0, 1)

    base = vh.hex2rgb(vh.PALETTE["rock"])
    light = vh.hex2rgb("#838B94")
    dark = vh.hex2rgb("#4B5560")
    mineral = vh.hex2rgb("#5A6B78")                     # cooler mineral seams
    alb = vh.mix(base, light, (jag - 0.5) * 1.2)
    alb = vh.mix(alb, dark, patches * 0.55)
    alb = vh.mix(alb, mineral, (patches > 0.62).astype(np.float32) * 0.4)
    alb *= (1.0 - cracks * 0.5)[..., None]
    alb *= (1.0 - (1.0 - vh.ao_from_height(h, 5, 1.3)) * 0.6)[..., None]
    alb = np.clip(alb + vh.grain(rng, S, 0.015)[..., None], 0, 1)

    rough = 0.78 - jag * 0.10 + cracks * 0.15
    nrm = vh.normal_map(h, 3.2)
    ao = vh.ao_from_height(h, 6, 1.5)
    return alb, nrm, rough, ao

# ------------------------------------------------------------------ ice ---
def gen_ice(S, seed=404):
    rng = np.random.default_rng(seed)
    smooth = vh.fbm(S, seed, 3, 4)
    crk = vh.ridged(S, seed + 6, 5, 5, 0.6)
    crk = vh.warp(S, crk, S * 0.025, seed + 2)
    fine = vh.fbm(S, seed + 10, 32, 3)
    h = smooth * 0.5 + fine * 0.2 + crk * 0.3
    deep = np.clip((crk > 0.90).astype(np.float32) * (crk - 0.90) / 0.10, 0, 1)

    base = vh.hex2rgb(vh.PALETTE["ice"])
    deep_blue = vh.hex2rgb("#7FA8CC")
    bright = vh.hex2rgb("#E4F1FA")
    alb = vh.mix(bright, base, smooth * 0.8)
    alb = vh.mix(alb, deep_blue, deep * 0.85)           # cracks read deep blue
    alb *= (1.0 - (1.0 - vh.ao_from_height(h, 5, 0.8)) * 0.35)[..., None]
    alb = np.clip(alb + vh.grain(rng, S, 0.006)[..., None], 0, 1)

    rough = 0.42 - smooth * 0.18 + deep * 0.20          # glossy surface, rough cracks
    rough = np.clip(rough, 0.12, 0.85)
    nrm = vh.normal_map(h, 2.4)
    ao = vh.ao_from_height(h, 6, 1.2)
    return alb, nrm, rough, ao

# ------------------------------------------------------- macro variation ---
def gen_macro(S, seed=909):
    tone = vh.fbm(S, seed, 3, 4)
    tint = vh.fbm(S, seed + 3, 5, 3)
    drift = vh.warp(S, vh.fbm(S, seed + 5, 4, 4), S * 0.05, seed + 7)
    r = 0.5 + (tone - 0.5) * 0.9                        # R: tone shift
    g = drift                                            # G: snow accumulation
    b = tint                                             # B: mineral/ice tint shift
    return np.stack([r, g, b], axis=-1)

GENS = {"snow": gen_snow, "compacted": gen_compacted, "rock": gen_rock, "ice": gen_ice}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--out", default="/home/z/my-project/VOIDHOLD/mobile/assets/world/ground")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    for name, fn in GENS.items():
        print(f"[{name}] {args.size}px")
        alb, nrm, rough, ao = fn(args.size)
        save(alb, os.path.join(args.out, f"{name}_albedo.png"))
        save(nrm, os.path.join(args.out, f"{name}_normal_gl.png"))
        save(rough, os.path.join(args.out, f"{name}_roughness.png"))
        save(ao, os.path.join(args.out, f"{name}_ao.png"))
        # 4-up preview sheet for review
        prev = np.ones((args.size, args.size * 4 + 6, 3), np.float32) * 0.1
        for i, m in enumerate([alb, nrm, np.repeat(rough[..., None], 3, -1), np.repeat(ao[..., None], 3, -1)]):
            prev[:, i * (args.size + 2): i * (args.size + 2) + args.size] = m
        save(prev, os.path.join(args.out, f"_preview_{name}.png"))

    print("[macro] 512px")
    save(vh.to_u8(gen_macro(512)) / 255.0, os.path.join(args.out, "macro_variation.png"))

if __name__ == "__main__":
    main()
