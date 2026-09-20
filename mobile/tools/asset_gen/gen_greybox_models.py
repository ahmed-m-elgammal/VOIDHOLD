#!/usr/bin/env python3
"""E2-04/05/07 + E2-08 — VOIDHOLD greybox model kit (.glb).

Silhouette-first greybox/hero prototypes, engine-ready for Godot 4.7:
  domes/greybox/fence_post.glb          straight emitter post
  domes/greybox/fence_post_corner.glb   corner post (amber marker)
  domes/greybox/fence_gate_post.glb     gate/entrance post pair + lintel
  domes/greybox/dome_entrance.glb       E2-04 airlock threshold + doors + beacon
  domes/greybox/elevator.glb            E2-05 surface elevator + beacon
  domes/greybox/oxygen.glb              E2-07 oxygen recycler (5x5)
  domes/greybox/living.glb              E2-07 habitat (5x5)
  domes/greybox/farmarea.glb            E2-07 greenhouse vault (4x4)
  domes/greybox/solar.glb               E2-07 wind power unit (3x3)
  domes/greybox/storage.glb             E2-07 storage hub (7x7)
  domes/greybox/teleport.glb            E2-07 dome teleport (4x4)
  domes/greybox/dome_shell.glb          80x80 dome boundary placeholder (r=40)
  world/ground/dressing/rock_large.glb  E2-08 low rock
  world/ground/dressing/rock_small.glb  E2-08 low rock
  world/ground/dressing/ice_shard.glb   E2-08 ice shard cluster
  world/ground/dressing/snow_drift.glb  E2-08 compact snow drift

Units: 1 tile = 1 m. Pivots: footprint center at y=0. Footprints match
mobile/data/buildings.json width/height. Emissive parts use VH_CyanGlow /
VH_WarmGlow materials so Godot's Mobile renderer shows them without extra
lights (one directional light rule).

Usage: python3 gen_greybox_models.py [--out-base DIR] [--seed 42]
"""
import argparse, math, os, random
from gltf_writer import GLBBuilder, VH_MATERIALS, rot_y, rot_x, tr

def box(b, mat, cx, cz, w, h, d, y0=0.0, ang=0.0):
    """Axis-aligned or Y-rotated box; (cx,cz) center, y0 bottom."""
    hw, hd = w / 2, d / 2
    pts = [(-hw, 0, -hd), (hw, 0, -hd), (hw, 0, hd), (-hw, 0, hd)]
    pts = [tr(rot_y(p, ang), cx, y0, cz) for p in pts]
    top = [tr(p, 0, h, 0) for p in pts]
    b.add_quad(mat, pts[0], pts[1], pts[2], pts[3])          # bottom
    b.add_quad(mat, top[3], top[2], top[1], top[0])          # top
    for i in range(4):                                       # sides
        j = (i + 1) % 4
        b.add_quad(mat, pts[i], pts[j], top[j], top[i])

def cyl(b, mat, cx, cz, r0, r1, h, seg=14, y0=0.0, cap=True):
    """Truncated cone / cylinder with caps."""
    for i in range(seg):
        a0 = 2 * math.pi * i / seg
        a1 = 2 * math.pi * (i + 1) / seg
        p00 = (math.cos(a0) * r0, y0, math.sin(a0) * r0)
        p01 = (math.cos(a1) * r0, y0, math.sin(a1) * r0)
        p10 = (math.cos(a0) * r1, y0 + h, math.sin(a0) * r1)
        p11 = (math.cos(a1) * r1, y0 + h, math.sin(a1) * r1)
        p00, p01, p10, p11 = [tr(p, cx, 0, cz) for p in (p00, p01, p10, p11)]
        b.add_quad(mat, p00, p01, p11, p10)
        if cap:
            c0, c1 = tr(p00, 0, 0, 0), tr(p01, 0, 0, 0)
            b.add_tri(mat, (cx, y0, cz), p01, p00)
            b.add_tri(mat, (cx, y0 + h, cz), p10, p11)

def sphere(b, mat, cx, cy, cz, r, seg=16, bands=10, hemisphere=False, jitter=0.0, rng=None):
    rows = bands + 1
    grid = []
    for i in range(rows):
        phi = (math.pi / 2 if hemisphere else math.pi) * i / bands
        row = []
        for j in range(seg + 1):
            th = 2 * math.pi * j / seg
            rr = r * (1.0 + (rng.random() - 0.5) * jitter if rng and jitter else 0.0)
            y = rr * math.cos(phi)
            x = rr * math.sin(phi) * math.cos(th)
            z = rr * math.sin(phi) * math.sin(th)
            row.append(tr((x, y, z), cx, cy, cz))
        grid.append(row)
    for i in range(bands):
        for j in range(seg):
            p00, p01 = grid[i][j], grid[i][j + 1]
            p10, p11 = grid[i + 1][j], grid[i + 1][j + 1]
            if i == 0 and not hemisphere:
                b.add_tri(mat, (cx, cy - r, cz), p10, p11) if False else None
                b.add_quad(mat, p00, p01, p11, p10)
            elif i == 0:
                continue
            else:
                b.add_quad(mat, p00, p01, p11, p10)

def drift(b, mat, cx, cz, r, h, seg=14, rng=None):
    """Half-ellipsoid snow drift sitting on the ground."""
    rows = 6
    grid = []
    for i in range(rows + 1):
        phi = (math.pi / 2) * i / rows
        row = []
        for j in range(seg + 1):
            th = 2 * math.pi * j / seg
            rr = r * (1.0 + (rng.random() - 0.5) * 0.25 if rng else 0.0)
            y = h * math.cos(phi)
            x = rr * math.sin(phi) * math.cos(th)
            z = rr * math.sin(phi) * math.sin(th)
            row.append(tr((x, y, z), cx, 0, cz))
        grid.append(row)
    for i in range(rows):
        for j in range(seg):
            if i == 0:
                continue
            b.add_quad(mat, grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j])

# --------------------------------------------------------------- models ----

def build_fence_post():
    b = GLBBuilder("VH_FencePost")
    box(b, "VH_AlloyDark", 0, 0, 0.22, 1.45, 0.22)
    box(b, "VH_AlloyPaint", 0, 0, 0.30, 0.10, 0.30, y0=1.45)
    cyl(b, "VH_CyanGlow", 0, 0, 0.055, 0.055, 0.16, 8, y0=1.55)     # emitter tip
    box(b, "VH_AmberPaint", 0, 0, 0.24, 0.06, 0.06, y0=1.10)        # service band
    return b

def build_fence_post_corner():
    b = build_fence_post()
    b.name = "VH_FencePostCorner"
    box(b, "VH_AmberPaint", 0, 0, 0.26, 0.26, 0.26, y0=1.71)        # corner marker
    return b

def build_fence_gate():
    b = GLBBuilder("VH_FenceGate")
    for x in (-1.7, 1.7):
        box(b, "VH_AlloyDark", x, 0, 0.34, 2.3, 0.34)
        cyl(b, "VH_CyanGlow", x, 0, 0.05, 0.05, 0.14, 8, y0=2.30)
    box(b, "VH_AlloyPaint", 0, 0, 3.8, 0.28, 0.34, y0=2.0)          # lintel
    box(b, "VH_CyanGlow", 0, 0, 3.2, 0.05, 0.05, y0=1.86)           # gate scan strip
    return b

def build_dome_entrance():
    b = GLBBuilder("VH_DomeEntrance")
    box(b, "VH_AlloyDark", 0, 0, 3.6, 0.18, 2.4)                    # threshold
    for x in (-1.6, 1.6):
        box(b, "VH_AlloyPaint", x, 0, 0.45, 2.4, 0.5, y0=0.18)      # frames
    box(b, "VH_AlloyPaint", 0, 0, 3.65, 0.5, 0.5, y0=2.58 - 0.5)    # header
    box(b, "VH_GlassDark", -0.72, -0.15, 1.3, 2.1, 0.22, y0=0.18)   # doors
    box(b, "VH_GlassDark", 0.72, -0.15, 1.3, 2.1, 0.22, y0=0.18)
    box(b, "VH_CyanGlow", -0.72, -0.3, 1.34, 0.05, 0.06, y0=1.6)    # door strips
    box(b, "VH_CyanGlow", 0.72, -0.3, 1.34, 0.05, 0.06, y0=1.6)
    cyl(b, "VH_WarmGlow", 0, 0.2, 0.14, 0.14, 0.22, 8, y0=2.42)     # overhead beacon
    box(b, "VH_White", 0, 0.9, 2.0, 0.02, 1.6, y0=0.001)            # cleared approach
    return b

def build_elevator():
    b = GLBBuilder("VH_Elevator")
    box(b, "VH_AlloyDark", 0, 0, 3.8, 0.35, 3.8)                    # platform
    box(b, "VH_AlloyPaint", 0, 0, 2.6, 0.12, 2.6, y0=0.35)          # deck
    cyl(b, "VH_AlloyDark", 0, 0, 0.95, 0.95, 1.15, 16, y0=0.35)     # lift collar
    cyl(b, "VH_GlassDark", 0, 0, 0.72, 0.72, 1.05, 16, y0=0.40)     # collar glass
    for (px, pz) in ((-1.55, -1.55), (1.55, -1.55), (-1.55, 1.55), (1.55, 1.55)):
        cyl(b, "VH_AlloyPaint", px, pz, 0.14, 0.11, 2.5, 8, y0=0.35)  # pylons
        box(b, "VH_AmberPaint", px, pz, 0.34, 0.08, 0.34, y0=1.5)     # rails hint
    box(b, "VH_AmberPaint", -1.55, -1.55, 0.5, 0.05, 0.5, y0=2.85)
    box(b, "VH_AmberPaint", 1.55, -1.55, 0.5, 0.05, 0.5, y0=2.85)
    box(b, "VH_AmberPaint", -1.55, 1.55, 0.5, 0.05, 0.5, y0=2.85)
    box(b, "VH_AmberPaint", 1.55, 1.55, 0.5, 0.05, 0.5, y0=2.85)
    cyl(b, "VH_WarmGlow", 1.55, 1.55, 0.10, 0.10, 0.3, 8, y0=2.93)  # arrival beacon
    box(b, "VH_White", 0, 2.2, 2.4, 0.02, 1.2, y0=0.001)            # cleared approach
    return b

def build_oxygen():
    b = GLBBuilder("VH_OxygenRecycler")
    box(b, "VH_AlloyDark", 0, 0, 3.6, 0.5, 3.6)                     # base
    cyl(b, "VH_AlloyPaint", 0, 0, 1.30, 1.30, 1.5, 16, y0=0.5)
    cyl(b, "VH_AlloyPaint", 0, 0, 1.12, 1.12, 1.5, 16, y0=2.0)
    cyl(b, "VH_AlloyDark", 0, 0, 0.94, 0.94, 1.4, 16, y0=3.5)
    cyl(b, "VH_CyanGlow", 0, 0, 0.98, 0.98, 0.18, 16, y0=2.72)      # flow indicator band
    for i in range(4):                                              # intake fins
        a = math.pi / 4 + i * math.pi / 2
        x, z = math.cos(a) * 1.55, math.sin(a) * 1.55
        box(b, "VH_White", x, z, 0.9, 1.1, 0.08, y0=0.8, ang=-a)
    box(b, "VH_AmberPaint", 1.4, -1.4, 0.5, 0.9, 0.06, y0=0.7)      # maintenance hatch side
    cyl(b, "VH_WarmGlow", 0, 0, 0.10, 0.10, 0.24, 8, y0=4.9)        # emergency light
    return b

def build_living():
    b = GLBBuilder("VH_Habitat")
    box(b, "VH_AlloyDark", 0, 0, 4.2, 0.3, 4.2)                     # pad
    for (cx, cz) in ((-1.0, -0.9), (-1.0, 1.0)):                    # two capsule modules
        cyl(b, "VH_Snow", cx, cz, 1.25, 1.25, 2.6, 16, y0=0.3)
        cyl(b, "VH_Snow", cx, cz, 1.25, 0.9, 0.55, 16, y0=2.9)
    box(b, "VH_AlloyPaint", 1.55, 0.05, 1.1, 1.9, 1.6, y0=0.3)      # airlock block
    box(b, "VH_GlassDark", 1.55, -0.78, 0.7, 1.1, 0.1, y0=0.55)
    for (wx, wz, ang) in ((-1.0, -2.2, 0.0), (0.35, 2.15, 0.0)):    # warm windows
        box(b, "VH_WarmGlow", wx, wz, 0.55, 0.5, 0.06, y0=1.0, ang=ang)
    box(b, "VH_WarmGlow", -2.28, -0.9, 0.06, 0.5, 0.55, y0=1.0)
    box(b, "VH_WarmGlow", -2.28, 1.0, 0.06, 0.5, 0.55, y0=1.0)
    box(b, "VH_AmberPaint", 1.55, 0.05, 1.2, 0.06, 0.3, y0=1.6)     # privacy fin
    return b

def build_farmarea():
    b = GLBBuilder("VH_Greenhouse")
    box(b, "VH_AlloyDark", 0, 0, 3.6, 0.22, 3.6)                    # base slab
    cyl(b, "VH_GlassGreen", 0, 0, 1.65, 0.0, 1.7, 18, y0=0.22, cap=False)  # vault (cone-ish)
    cyl(b, "VH_AlloyPaint", 0, 0, 1.70, 1.70, 0.14, 18, y0=0.22)    # skirt ring
    for i in range(5):                                              # rib hoops
        a = -math.pi / 2 + i * math.pi / 4
        box(b, "VH_White", 0, 0, 0.10, 1.55, 3.3, y0=0.25, ang=a)
    box(b, "VH_AlloyPaint", 0, -1.75, 0.8, 1.0, 0.3, y0=0.22)       # service door
    cyl(b, "VH_WarmGlow", 1.2, 0, 0.07, 0.07, 0.16, 6, y0=1.35)     # grow light hint
    cyl(b, "VH_WarmGlow", -1.2, 0, 0.07, 0.07, 0.16, 6, y0=1.35)
    return b

def build_solar():
    b = GLBBuilder("VH_WindPower")
    cyl(b, "VH_AlloyDark", 0, 0, 1.05, 1.2, 0.4, 14, y0=0.0)        # base
    box(b, "VH_AlloyPaint", 0, 0, 1.1, 1.15, 1.1, y0=0.4)           # generator housing
    cyl(b, "VH_AlloyDark", 0, 0, 0.16, 0.14, 2.6, 8, y0=1.55)       # mast
    for i in range(3):                                              # vertical-axis blades
        a = i * 2 * math.pi / 3
        x, z = math.cos(a) * 0.55, math.sin(a) * 0.55
        box(b, "VH_White", x, z, 0.30, 2.5, 0.10, y0=1.7, ang=-a + 0.5)
    box(b, "VH_CyanGlow", 0, 0, 0.26, 0.10, 0.26, y0=1.28)          # status indicator
    cyl(b, "VH_WarmGlow", 0, 0, 0.07, 0.07, 0.16, 6, y0=4.2)        # top light
    box(b, "VH_AmberPaint", 0.9, 0, 0.08, 0.5, 0.7, y0=0.35)        # cable conduit
    return b

def build_storage():
    b = GLBBuilder("VH_StorageHub")
    box(b, "VH_AlloyDark", 0, 0, 6.6, 0.35, 5.6)                    # apron slab
    box(b, "VH_AlloyPaint", 0, 0.4, 6.4, 2.1, 5.4, y0=0.35)         # main hall
    for i in range(3):                                              # roof segments
        box(b, "VH_AlloyDark", -2.15 + i * 2.15, 0.4, 2.0, 0.22, 5.2, y0=2.45)
    for i in range(3):                                              # bay fronts
        box(b, "VH_GlassDark", -1.7 + i * 1.7, 2.62, 1.1, 1.3, 0.1, y0=0.55)
    box(b, "VH_AmberPaint", 0, 2.62, 6.0, 0.18, 0.3, y0=1.2)        # safety band
    for (bx, bz) in ((-2.4, -3.4), (-0.6, -3.4), (1.2, -3.4), (2.9, -3.4)):
        box(b, "VH_White", bx, bz, 0.85, 0.65, 0.85, y0=0.35)       # resource bins
    box(b, "VH_CyanGlow", 3.0, 0.4, 0.06, 0.35, 0.5, y0=1.5)        # inventory indicator
    return b

def build_teleport():
    b = GLBBuilder("VH_Teleport")
    cyl(b, "VH_AlloyDark", 0, 0, 1.85, 1.85, 0.28, 20, y0=0.0)      # pad
    cyl(b, "VH_CyanGlow", 0, 0, 1.15, 1.15, 0.06, 20, y0=0.28)      # field aperture
    cyl(b, "VH_AlloyPaint", 0, 0, 1.5, 1.5, 0.10, 20, y0=0.28)      # aperture ring
    for i in range(4):                                              # stabilizer pylons
        a = math.pi / 4 + i * math.pi / 2
        x, z = math.cos(a) * 1.55, math.sin(a) * 1.55
        cyl(b, "VH_White", x, z, 0.10, 0.07, 1.5, 8, y0=0.0)
        cyl(b, "VH_CyanGlow", x, z, 0.045, 0.045, 0.22, 6, y0=1.5)
    box(b, "VH_AlloyPaint", 2.2, 0, 0.7, 1.0, 0.55, y0=0.0)         # service console
    box(b, "VH_WarmGlow", 2.2, -0.29, 0.5, 0.3, 0.05, y0=0.55)
    return b

def build_dome_shell():
    b = GLBBuilder("VH_DomeShell")
    sphere(b, "VH_DomeShell", 0, 0, 0, 40.0, seg=28, bands=12, hemisphere=True)
    cyl(b, "VH_AlloyDark", 0, 0, 40.1, 40.1, 0.5, 28, y0=-0.25, cap=False)  # base ring
    return b

def build_rock(rng, name, r, seg=12):
    b = GLBBuilder(name)
    sphere(b, "VH_Rock", 0, 0, 0, r, seg=seg, bands=7, jitter=0.34, rng=rng)
    return b

def build_ice_shard(rng):
    b = GLBBuilder("VH_IceShard")
    for (dx, dz, h, r) in ((0, 0, 1.7, 0.42), (0.65, 0.3, 1.1, 0.30), (-0.5, 0.45, 0.8, 0.24)):
        for i in range(4):                                          # bipyramid shard
            a0 = math.pi / 2 * i / 2 + dx
            pts = [(-r, 0, 0), (0, 0, r), (r, 0, 0), (0, 0, -r)]
            pts = [tr(rot_y(p, a0), dx, 0, dz) for p in pts]
            apex_t, apex_b = tr((0, h, 0), dx, 0, dz), tr((0, -0.2, 0), dx, 0, dz)
            for j in range(4):
                b.add_tri("VH_Ice", pts[j], pts[(j + 1) % 4], apex_t)
                b.add_tri("VH_Ice", pts[(j + 1) % 4], pts[j], apex_b)
    return b

def build_snow_drift(rng):
    b = GLBBuilder("VH_SnowDrift")
    drift(b, "VH_Snow", 0, 0, 1.6, 0.55, seg=16, rng=rng)
    return b

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-base", default="/home/z/my-project/VOIDHOLD/mobile/assets")
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()
    rng = random.Random(args.seed)

    grey = os.path.join(args.out_base, "domes", "greybox")
    dress = os.path.join(args.out_base, "world", "ground", "dressing")
    os.makedirs(grey, exist_ok=True)
    os.makedirs(dress, exist_ok=True)

    jobs = [
        (build_fence_post(), os.path.join(grey, "fence_post.glb")),
        (build_fence_post_corner(), os.path.join(grey, "fence_post_corner.glb")),
        (build_fence_gate(), os.path.join(grey, "fence_gate.glb")),
        (build_dome_entrance(), os.path.join(grey, "dome_entrance.glb")),
        (build_elevator(), os.path.join(grey, "elevator.glb")),
        (build_oxygen(), os.path.join(grey, "oxygen.glb")),
        (build_living(), os.path.join(grey, "living.glb")),
        (build_farmarea(), os.path.join(grey, "farmarea.glb")),
        (build_solar(), os.path.join(grey, "solar.glb")),
        (build_storage(), os.path.join(grey, "storage.glb")),
        (build_teleport(), os.path.join(grey, "teleport.glb")),
        (build_dome_shell(), os.path.join(grey, "dome_shell.glb")),
        (build_rock(rng, "VH_RockLarge", 1.4), os.path.join(dress, "rock_large.glb")),
        (build_rock(rng, "VH_RockSmall", 0.7), os.path.join(dress, "rock_small.glb")),
        (build_ice_shard(rng), os.path.join(dress, "ice_shard.glb")),
        (build_snow_drift(rng), os.path.join(dress, "snow_drift.glb")),
    ]
    for b, path in jobs:
        data = b.emit()
        with open(path, "wb") as f:
            f.write(data)
        tris = sum(len(v) for v in b.tris.values())
        print(f"  wrote {os.path.relpath(path, args.out_base)}  ({tris} tris, {len(data)} bytes)")

if __name__ == "__main__":
    main()
