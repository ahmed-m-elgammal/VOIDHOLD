#!/usr/bin/env python3
"""VOIDHOLD asset generation — shared library.

Palette, tileable noise, and PBR map helpers used by every generator.
All noise is lattice value-noise that wraps at the texture edge, so every
generated texture is seamlessly tileable by construction.

Author: generated for VOIDHOLD: Moon Colony (procedural, original work).
License: same as the VOIDHOLD repository.
"""
import numpy as np

# --- palette anchors (tasks/epic-2-world-domes/ASSET_REQUIREMENTS.md section 3) ---
PALETTE = {
    "snow":        "#E8EEF4",
    "rock":        "#6B7280",
    "alloy":       "#3A4750",
    "amber":       "#FFB020",
    "warm_light":  "#FFC37A",
    "valid":       "#35D07F",
    "danger":      "#FF4D4D",
    "cyan":        "#5FD4E8",  # controlled tech glow (cyan / ice blue)
    "ice":         "#BFDCEE",  # blue ice base
    "sky_night":   "#0A1018",  # deep blue-black zenith
    "sky_horizon": "#8FA8BC",  # cold horizon haze
}

def hex2rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255.0

def mix(c1, c2, t):
    t = np.clip(t, 0.0, 1.0)[..., None] if t.ndim == 2 else np.clip(t, 0.0, 1.0)
    return c1 * (1 - t) + c2 * t


# --- tileable value noise -------------------------------------------------
def _lattice(rng, cells):
    return rng.random((cells, cells)).astype(np.float32)

def _sample(lat, u, v):
    n = lat.shape[0]
    x = np.mod(u * n, n)
    y = np.mod(v * n, n)
    x0 = np.floor(x).astype(np.int32) % n
    y0 = np.floor(y).astype(np.int32) % n
    x1 = (x0 + 1) % n
    y1 = (y0 + 1) % n
    fx = x - np.floor(x)
    fy = y - np.floor(y)
    sx = fx * fx * (3 - 2 * fx)
    sy = fy * fy * (3 - 2 * fy)
    a = lat[y0, x0]; b = lat[y0, x1]
    c = lat[y1, x0]; d = lat[y1, x1]
    return (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy

def fbm(size, seed, base_cells=4, octaves=5, gain=0.5, lacun=2):
    """Tileable fractal value noise, returns float array [0,1] of shape (size,size)."""
    yy, xx = np.mgrid[0:size, 0:size]
    u = (xx + 0.5) / size
    v = (yy + 0.5) / size
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size), dtype=np.float32)
    amp, cells, norm = 1.0, base_cells, 0.0
    for _ in range(octaves):
        out += amp * _sample(_lattice(rng, cells), u, v)
        norm += amp
        amp *= gain
        cells = int(cells * lacun)
    return out / norm

def ridged(size, seed, base_cells=4, octaves=4, gain=0.55):
    """Tileable ridged noise (cracks / rock crevices), [0,1], sharp at 1."""
    n = fbm(size, seed, base_cells, octaves, gain)
    return 1.0 - np.abs(2.0 * n - 1.0)

def warp(size, field, amount, seed):
    """Domain-warp a field with tileable offsets for organic, non-repetitive look."""
    wx = fbm(size, seed + 1, 4, 4) - 0.5
    wy = fbm(size, seed + 2, 4, 4) - 0.5
    yy, xx = np.mgrid[0:size, 0:size]
    size_f = float(size)
    su = (xx + 0.5 + wx * amount) / size_f
    sv = (yy + 0.5 + wy * amount) / size_f
    lat = None
    # resample field by treating it as a lattice at its own resolution
    n = field.shape[0]
    x = np.mod(su * n, n)
    y = np.mod(sv * n, n)
    x0 = np.floor(x).astype(np.int32) % n
    y0 = np.floor(y).astype(np.int32) % n
    x1 = (x0 + 1) % n
    y1 = (y0 + 1) % n
    fx = x - np.floor(x)
    fy = y - np.floor(y)
    sx = fx * fx * (3 - 2 * fx)
    sy = fy * fy * (3 - 2 * fy)
    a = field[y0, x0]; b = field[y0, x1]
    c = field[y1, x0]; d = field[y1, x1]
    return (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy


# --- PBR map helpers -------------------------------------------------------
def normal_map(height, strength=2.0):
    """OpenGL-convention normal map from a tileable height field (wrap-safe)."""
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx = -dx * strength * height.shape[0] / 256.0
    ny = dy * strength * height.shape[1] / 256.0
    nz = np.ones_like(height)
    ln = np.sqrt(nx * nx + ny * ny + 1.0)
    n = np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], axis=-1)
    return np.clip(n, 0.0, 1.0)

def ao_from_height(height, spread=6, strength=1.4):
    """Cheap cavity AO: darken where the local mean is notably higher than the pixel."""
    import scipy.ndimage as ndi  # optional; fallback below
    try:
        blur = ndi.uniform_filter(height, size=spread * 2 + 1, mode="wrap")
    except Exception:
        k = spread * 2 + 1
        kernel = np.ones((k, k), np.float32) / (k * k)
        pad = np.pad(height, spread, mode="wrap")
        blur = np.zeros_like(height)
        for yy in range(k):
            for xx in range(k):
                blur += pad[yy:yy + height.shape[0], xx:xx + height.shape[1]]
        blur /= (k * k)
    cav = np.clip((blur - height) * strength, 0.0, 1.0)
    return np.clip(1.0 - cav, 0.35, 1.0)

def to_u8(arr):
    return (np.clip(arr, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)

def grain(rng, size, amount=0.02):
    return (rng.random((size, size), dtype=np.float32) - 0.5) * 2 * amount
