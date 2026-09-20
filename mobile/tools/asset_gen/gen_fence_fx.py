#!/usr/bin/env python3
"""E2-03 + E2-06 — dome fence FX and placement feedback textures.

Fence kit (E2-03):
  fence_strand_gradient.png  256x64 thin cyan laser strand, additive-friendly
  fence_pulse_sheet.png      2048x128, 8 frames of a traveling pulse
  fence_post_glow.png        128x128 emitter-tip glow sprite

Placement feedback (E2-06):
  grid_overlay.png           128x128 1-tile cell, thin edge lines
  ghost_valid/blocked/warning.png  translucent building ghost tints
  entrance_arrow.png         128x128 approach chevron
  worker_radius_ring.png     512x512 amber radius ring
  selection_ring.png         512x512 white selection ring
  link_marker.png            256x128 dome-link marker (two nodes, dashed)

All RGBA, no text (EN+AR localization rule). Original procedural work.
Usage: python3 gen_fence_fx.py [--out-base DIR]
"""
import argparse, os
import numpy as np
from PIL import Image, ImageFilter

import vh_common as vh

def save_rgba(arr_rgb, arr_a, path):
    rgba = np.dstack([vh.to_u8(arr_rgb), vh.to_u8(arr_a)])
    Image.fromarray(rgba).save(path, optimize=True)
    print("  wrote", path)

def strand_frame(w=256, h=128, phase=0.0, core=1.0):
    """Laser strand strip: thin bright core + soft falloff, pulse at phase."""
    x = np.linspace(0.0, 1.0, w, dtype=np.float32)
    y = np.linspace(-1.0, 1.0, h, dtype=np.float32)
    xx, yy = np.meshgrid(x, y)
    core_w = 0.06
    strand = np.exp(-(yy * yy) / (2 * core_w * core_w)) * core
    glow = np.exp(-(yy * yy) / (2 * 0.28 * 0.28)) * 0.35
    # traveling pulse brightening
    pulse = np.exp(-((xx - phase) ** 2) / (2 * 0.055 ** 2)) * 0.9
    inten = np.clip(strand + glow + pulse * (strand + glow * 2.0), 0, 1.6)
    col = np.array(vh.hex2rgb("#5FD4E8"), np.float32)
    white = np.array([0.85, 0.97, 1.0], np.float32)
    rgb = col * inten[..., None]
    hot = np.clip(inten - 0.75, 0, 1)[..., None]
    rgb = rgb * (1 - hot) + white * inten[..., None] * hot
    return np.clip(rgb, 0, 1), np.clip(inten, 0, 1)

def gen_fence(out):
    rgb, a = strand_frame()
    save_rgba(rgb, a, os.path.join(out, "fence_strand_gradient.png"))

    # 8-frame pulse sheet (2048x128): frames side by side, pulse travels L->R
    F, frame_w, frame_h = 8, 256, 128
    sheet = np.zeros((frame_h, F * frame_w, 3), np.float32)
    sheet_a = np.zeros((frame_h, F * frame_w), np.float32)
    for f in range(F):
        rgb, a = strand_frame(frame_w, frame_h, phase=f / F, core=0.9)
        sheet[:, f * frame_w:(f + 1) * frame_w] = rgb
        sheet_a[:, f * frame_w:(f + 1) * frame_w] = a
    save_rgba(sheet, sheet_a, os.path.join(out, "fence_pulse_sheet.png"))

    # emitter-tip glow: radial soft dot
    S = 128
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.sqrt((xx - S / 2) ** 2 + (yy - S / 2) ** 2) / (S / 2)
    core = np.exp(-(d * d) / (2 * 0.13 ** 2))
    halo = np.exp(-(d * d) / (2 * 0.42 ** 2)) * 0.5
    inten = np.clip(core + halo, 0, 1)
    rgb = np.array(vh.hex2rgb("#5FD4E8"), np.float32) * inten[..., None]
    hot = np.clip(core - 0.6, 0, 1)[..., None]
    rgb = rgb * (1 - hot) + np.array([0.9, 0.98, 1.0], np.float32) * inten[..., None] * hot
    save_rgba(np.clip(rgb, 0, 1), inten, os.path.join(out, "fence_post_glow.png"))

def gen_placement(out):
    # 1-tile grid overlay: thin translucent edge lines
    S = 128
    a = np.zeros((S, S), np.float32)
    edge = 2
    a[:edge, :] = 0.35; a[-edge:, :] = 0.35
    a[:, :edge] = 0.35; a[:, -edge:] = 0.35
    inner = 0.10
    a[edge:-edge, edge:-edge] = np.maximum(a[edge:-edge, edge:-edge], inner)
    rgb = np.ones((S, S, 3), np.float32)
    save_rgba(rgb, a, os.path.join(out, "grid_overlay.png"))

    # ghost tints: vertical gradient, stronger at base
    S = 256
    v = np.linspace(0.0, 1.0, S, dtype=np.float32)
    for name, col, amp in (
        ("ghost_valid", "#35D07F", 0.55),
        ("ghost_blocked", "#FF4D4D", 0.60),
        ("ghost_warning", "#FFB020", 0.55),
    ):
        base = np.array(vh.hex2rgb(col), np.float32)
        a = (0.16 + (1.0 - v) * amp)[:, None].repeat(S, 1)
        rgb = base[None, None, :].repeat(S, 0).repeat(S, 1)
        save_rgba(rgb, np.clip(a, 0, 0.85), os.path.join(out, f"{name}.png"))

    # entrance arrow: chevron pointing +Y (up); rotate in-engine
    S = 128
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    cx = S / 2
    t = (S - yy) / S  # 0 bottom, 1 top
    chev = 0
    a = np.zeros((S, S), np.float32)
    for k, off in enumerate((0.62, 0.38)):  # two chevrons
        band = np.clip(1.0 - np.abs(t - off) / 0.085, 0, 1)
        width = np.clip(1.0 - (np.abs(xx - cx) / (S * 0.30)) + (off - t) * 0.9, 0, 1)
        a = np.maximum(a, band * np.clip(width, 0, 1) * (0.85 - k * 0.25))
    rgb = np.array(vh.hex2rgb("#FFB020"), np.float32)[None, None, :].repeat(S, 0).repeat(S, 1)
    save_rgba(rgb, np.clip(a, 0, 1), os.path.join(out, "entrance_arrow.png"))

    # worker radius ring (amber) + selection ring (white)
    S = 512
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.sqrt((xx - S / 2) ** 2 + (yy - S / 2) ** 2) / (S / 2)
    for name, col, rr, wdt, al in (
        ("worker_radius_ring", "#FFB020", 0.94, 0.012, 0.75),
        ("selection_ring", "#FFFFFF", 0.96, 0.010, 0.9),
    ):
        ring = np.clip(1.0 - np.abs(d - rr) / wdt, 0, 1) * al
        tick = np.clip(1.0 - np.abs(d - rr) / (wdt * 3), 0, 1)
        ang = np.degrees(np.arctan2(yy - S / 2, xx - S / 2)) % 360
        marks = (np.abs(((ang + 45) % 90) - 45) < 3).astype(np.float32)
        ring = np.maximum(ring, tick * marks * 0.5 * al)
        rgb = np.array(vh.hex2rgb(col), np.float32)[None, None, :].repeat(S, 0).repeat(S, 1)
        save_rgba(rgb, np.clip(ring, 0, 1), os.path.join(out, f"{name}.png"))

    # dome link marker: two nodes + dashed line, cyan
    W, H = 256, 128
    a = np.zeros((H, W), np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cy = H / 2
    for cxx, rr in ((26, 14), (W - 26, 14)):
        a += np.clip(rr - np.sqrt((xx - cxx) ** 2 + (yy - cy) ** 2), 0, 1)
        a += np.clip(2.0 - np.abs(np.sqrt((xx - cxx) ** 2 + (yy - cy) ** 2) - rr - 4), 0, 2) * 0.4
    seg = ((xx > 44) & (xx < W - 44))
    dash = (((xx - 44) // 16) % 2 == 0).astype(np.float32)
    a += seg * dash * np.clip(3.0 - np.abs(yy - cy), 0, 3) * 0.5
    a = np.clip(a, 0, 1)
    rgb = np.array(vh.hex2rgb("#5FD4E8"), np.float32)[None, None, :].repeat(H, 0).repeat(W, 1)
    save_rgba(rgb, a, os.path.join(out, "link_marker.png"))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-base", default="/home/z/my-project/VOIDHOLD/mobile/assets")
    args = ap.parse_args()
    fence = os.path.join(args.out_base, "domes", "fence")
    place = os.path.join(args.out_base, "ui", "placement")
    os.makedirs(fence, exist_ok=True)
    os.makedirs(place, exist_ok=True)
    print("[fence]")
    gen_fence(fence)
    print("[placement]")
    gen_placement(place)

if __name__ == "__main__":
    main()
