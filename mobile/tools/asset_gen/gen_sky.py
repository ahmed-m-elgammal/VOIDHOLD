#!/usr/bin/env python3
"""E2-02 — sky, atmosphere, and distant moon for VOIDHOLD.

Emits:
  sky_day_panorama.png    2048x1024 equirect panorama, neutral cold daylight
  sky_night_panorama.png  2048x1024 warm-focus night state
  distant_moon.png        1024x1024 RGBA sprite of the parent gas giant's icy moon
  atmosphere_guide.md     fog/light values for the Godot Environment

The panoramas are consumed directly by Godot's PanoramaSkyMaterial.
Stars are sparse and upper-hemisphere only; the horizon keeps a thin cold
haze band that separates the playable ground from the void, per the Epic 2
asset brief. No giant distracting planet in the sky itself — the moon is
delivered as a separate sprite so it can be placed at a controlled distance.

Usage: python3 gen_sky.py [--size 2048] [--out DIR]
"""
import argparse, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import vh_common as vh

def hex2rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255.0

def vgrad(size, stops):
    """Vertical gradient from normalized-height color stops [(t, rgb), ...]."""
    ts = np.array([s[0] for s in stops], np.float32)
    cs = np.stack([s[1] for s in stops]).astype(np.float32)
    v = np.linspace(1.0, 0.0, size, dtype=np.float32)  # top of image = zenith
    out = np.zeros((size, 3), np.float32)
    for c in range(3):
        out[:, c] = np.interp(v, ts, cs[:, c])
    return out[None, :, :].repeat(size, 0)  # placeholder, replaced below

def build_panorama(W, H, mode, seed=7):
    """Equirect panorama. v: 1.0 = zenith (top), 0.0 = nadir (bottom)."""
    yy = (np.arange(H, dtype=np.float32) + 0.5) / H
    v = 1.0 - yy  # image row 0 = top = zenith
    if mode == "day":
        stops = [
            (1.00, hex2rgb("#0A1018")),   # deep blue-black zenith
            (0.78, hex2rgb("#13202E")),
            (0.55, hex2rgb("#23405A")),
            (0.42, hex2rgb("#3C6484")),
            (0.30, hex2rgb("#6D93AC")),
            (0.24, hex2rgb("#8FA8BC")),   # thin cold haze band at horizon
            (0.22, hex2rgb("#7E99AD")),
            (0.12, hex2rgb("#41586B")),   # below-horizon fades to dark ground fog
            (0.00, hex2rgb("#1A2530")),
        ]
        haze_strength, star_max_v = 1.0, 0.60
    else:  # night
        stops = [
            (1.00, hex2rgb("#05080E")),
            (0.72, hex2rgb("#0B1420")),
            (0.45, hex2rgb("#16283A")),
            (0.30, hex2rgb("#2E4A5E")),
            (0.24, hex2rgb("#5E7C90")),   # faint cold haze
            (0.22, hex2rgb("#51697B")),
            (0.12, hex2rgb("#31414E")),
            (0.00, hex2rgb("#141C24")),
        ]
        haze_strength, star_max_v = 0.7, 0.80

    img = np.zeros((H, W, 3), np.float32)
    for c in range(3):
        ts = np.array([s[0] for s in stops], np.float32)
        cs = np.array([s[1][c] for s in stops], np.float32)
        img[:, :, c] = np.interp(v, ts, cs)[:, None]

    # subtle large-scale sky variation (kept faint — restrained, not noisy)
    var = vh.fbm(W // 2, seed, 3, 3)
    var = np.asarray(Image.fromarray(vh.to_u8(var)).resize((W, H), Image.BILINEAR), np.float32) / 255.0
    img *= (0.94 + var * 0.12)[..., None]

    # sparse stars, upper hemisphere only
    rng = np.random.default_rng(seed + (11 if mode == "day" else 12))
    star_layer = np.zeros((H, W), np.float32)
    n_stars = int(900 * haze_strength)
    ys = (rng.random(n_stars) * star_max_v * H).astype(int)
    xs = rng.integers(0, W, n_stars)
    bright = rng.random(n_stars) ** 2.2  # few bright, many faint
    vals = (0.25 + 0.75 * bright)
    for x, y, val in zip(xs, ys, vals):
        star_layer[y, x] = max(star_layer[y, x], val)
        if val > 0.9:  # rare brighter star with a 1px cross glow
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                yy2, xx2 = (y + dy) % H, (x + dx) % W
                star_layer[yy2, xx2] = max(star_layer[yy2, xx2], val * 0.4)
    star_layer = np.asarray(
        Image.fromarray(vh.to_u8(star_layer)).filter(ImageFilter.GaussianBlur(0.6)),
        np.float32) / 255.0
    # stars fade out toward the horizon haze
    star_fade = np.clip((v - 0.30) / 0.25, 0, 1)
    img += (star_layer * star_fade[:, None] * 0.9)[..., None] * np.array([0.9, 0.95, 1.0], np.float32)

    return np.clip(img, 0.0, 1.0)

def build_distant_moon(S=1024, seed=21):
    """RGBA sprite: pale icy moon, lit from upper-left, soft halo."""
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    cx = cy = S / 2.0
    R = S * 0.36
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    body = d <= R

    # limb + terminator lighting: light dir upper-left (-0.6, -0.5, 0.62)
    nx, ny = (xx - cx) / R, (yy - cy) / R
    nz = np.sqrt(np.clip(1.0 - nx * nx - ny * ny, 0, 1))
    L = np.array([-0.55, -0.55, 0.63], np.float32)
    L /= np.linalg.norm(L)
    lam = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
    lam = lam ** 1.1

    # surface: low-freq icy mare + craters with rims
    mare = vh.fbm(S, seed, 3, 4)
    mare_img = mare
    albedo = np.ones((S, S, 3), np.float32) * hex2rgb("#DCE7EF")
    mare_mask = np.clip((mare_img - 0.52) * 2.2, 0, 1) * 0.30
    albedo *= (1.0 - mare_mask * np.array([0.35, 0.25, 0.15]))[...] if False else 1.0
    albedo[..., 0] *= (1.0 - mare_mask * 0.35)
    albedo[..., 1] *= (1.0 - mare_mask * 0.28)
    albedo[..., 2] *= (1.0 - mare_mask * 0.18)

    # craters: circles with darker floor + bright rim on lit side
    rng = np.random.default_rng(seed + 3)
    rim = np.zeros((S, S), np.float32)
    floor = np.zeros((S, S), np.float32)
    for _ in range(26):
        cr = rng.uniform(S * 0.015, S * 0.06)
        cxx, cyy = rng.uniform(R * 0.75, S - R * 0.75), rng.uniform(R * 0.75, S - R * 0.75)
        dd = np.sqrt((xx - cxx) ** 2 + (yy - cyy) ** 2)
        f = dd < cr * 0.75
        r_ = (dd >= cr * 0.75) & (dd < cr)
        floor[f] = np.maximum(floor[f], 0.35 + rng.random() * 0.2)
        rim[r_] = np.maximum(rim[r_], 0.5)
    albedo *= (1.0 - floor * 0.22)[..., None]
    albedo += rim[..., None] * np.array([0.10, 0.11, 0.12], np.float32)

    # lighting composite
    shade = 0.22 + 0.88 * lam
    albedo *= shade[..., None]
    # thin atmosphere rim on lit limb
    edge = np.clip(1.0 - np.abs(d - R * 0.985) / (S * 0.02), 0, 1) * np.clip(lam, 0, 1)
    albedo += edge[..., None] * np.array([0.25, 0.35, 0.45], np.float32) * 0.5

    alpha = np.clip((R - d) / (S * 0.008), 0, 1)
    # soft outer halo (thin, restrained)
    halo = np.exp(-np.clip(d - R, 0, None) / (S * 0.045)) * np.clip((d - R * 0.92) / (R * 0.08), 0, 1)
    halo_col = np.array([0.55, 0.68, 0.80], np.float32)
    out_rgb = albedo * alpha[..., None] + halo_col * halo[..., None] * 0.45 * (1 - alpha[..., None])
    out_a = np.clip(alpha + halo * 0.35, 0, 1)
    return np.clip(out_rgb, 0, 1), out_a

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=2048)
    ap.add_argument("--out", default="/home/z/my-project/VOIDHOLD/mobile/assets/world/sky")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    W, H = args.size, args.size // 2

    for mode in ("day", "night"):
        img = build_panorama(W, H, mode)
        Image.fromarray(vh.to_u8(img)).save(os.path.join(args.out, f"sky_{mode}_panorama.png"), optimize=True)
        print(f"  wrote sky_{mode}_panorama.png ({W}x{H})")

    rgb, a = build_distant_moon(1024)
    rgba = np.dstack([vh.to_u8(rgb), vh.to_u8(a)])
    Image.fromarray(rgba, "RGBA").save(os.path.join(args.out, "distant_moon.png"), optimize=True)
    print("  wrote distant_moon.png (1024x1024 RGBA)")

    guide = """# Atmosphere / lighting guide — E2-02

Values for `WorldEnvironment` (Godot 4.7, Mobile renderer). Panoramas are
equirect — use `PanoramaSkyMaterial` with `sky_day_panorama.png` /
`sky_night_panorama.png` and lerp `sky_energy`/tint with the day/night cycle.

## Day (neutral cold daylight)
- PanoramaSky: `sky_day_panorama.png`, energy 1.0
- DirectionalLight: color `#FFF6E8`, energy 1.2, rotation (approx) pitch -48 deg, yaw 35 deg
  (matches the lit limb of `distant_moon.png` — light comes from upper-left)
- Ambient (sky contribution): energy 0.6
- Fog: enabled, light energy 0.4 — color `#8FA8BC`, density 0.0015, aerial perspective
  `sky_affect 0.3`; keep horizon haze thin so the void reads beyond the 210x210 bounds

## Night (warm habitation focus)
- PanoramaSky: `sky_night_panorama.png`, energy 1.0
- DirectionalLight: color `#9FB6D4` (cold moonlight), energy 0.25
- Ambient: energy 0.35
- Fog: color `#16283A`, density 0.002
- Warm building windows (`#FFC37A`) and cyan fence glow carry the scene —
  do not raise ambient above 0.45 or the night read is lost

## Distant moon
- Use `distant_moon.png` on a quad or Sprite3D at ~600-900 m distance,
  ~140 m apparent size, always behind fog (`render_priority` low), unshaded
- Do not add a second planet — brief forbids a giant distracting body

## Color anchors
- sky zenith `#0A1018` / horizon haze `#8FA8BC`
- fog day `#8FA8BC` / fog night `#16283A`
"""
    with open(os.path.join(args.out, "atmosphere_guide.md"), "w") as f:
        f.write(guide)
    print("  wrote atmosphere_guide.md")

if __name__ == "__main__":
    main()
