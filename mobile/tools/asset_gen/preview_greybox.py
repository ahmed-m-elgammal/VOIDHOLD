from pathlib import Path
#!/usr/bin/env python3
"""Render a preview montage of the VOIDHOLD greybox .glb kit.

Tiny orthographic software renderer (painter's algorithm, flat shading,
art-bible palette) — just enough to eyeball silhouettes without a GPU.
"""
import glob, os
import numpy as np
import trimesh
from PIL import Image, ImageDraw

ASSETS = Path(__file__).resolve().parents[2] / "assets"
MODELS = sorted(glob.glob(str(ASSETS / "domes" / "greybox" / "*.glb"))) + \
         sorted(glob.glob(str(ASSETS / "world" / "ground" / "dressing" / "*.glb")))

CELL = 300

def render(mesh, size=CELL):
    v = mesh.vertices.copy()
    f = mesh.faces
    # camera: 3/4 ortho like gameplay (yaw 35deg, pitch -35deg)
    yaw, pitch = np.radians(35), np.radians(35)
    Ry = np.array([[np.cos(yaw), 0, np.sin(yaw)], [0, 1, 0], [-np.sin(yaw), 0, np.cos(yaw)]])
    Rx = np.array([[1, 0, 0], [0, np.cos(pitch), -np.sin(pitch)], [0, np.sin(pitch), np.cos(pitch)]])
    R = Rx @ Ry
    vv = v @ R.T
    lo, hi = vv.min(0), vv.max(0)
    span = max(hi[0] - lo[0], hi[1] - lo[1]) * 1.1
    scale = (size - 40) / span
    cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
    xy = np.stack([(vv[:, 0] - cx) * scale + size / 2,
                   (cy - vv[:, 1]) * scale + size / 2], 1)
    depth = vv[:, 2]
    # face depth + normal shading
    tri_xy = xy[f]; tri_d = depth[f].mean(1)
    n = mesh.face_normals
    light = np.array([0.5, 0.6, 0.62]); light /= np.linalg.norm(light)
    lam = np.clip(n @ light, 0, 1) * 0.75 + 0.25

    order = np.argsort(tri_d)
    img = Image.new("RGB", (size, size), (26, 33, 42))
    d = ImageDraw.Draw(img)
    base = np.array([0.75, 0.80, 0.85])
    for i in order:
        c = tuple((base * lam[i] * 255).astype(int))
        d.polygon([tuple(p) for p in tri_xy[i]], fill=c)
    return img

def main():
    cols = 4
    rows = (len(MODELS) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * CELL, rows * (CELL + 22)), (18, 24, 32))
    dr = ImageDraw.Draw(sheet)
    for i, path in enumerate(MODELS):
        try:
            scene = trimesh.load(path)
            mesh = trimesh.util.concatenate(list(scene.geometry.values()))
            img = render(mesh)
        except Exception as e:
            img = Image.new("RGB", (CELL, CELL), (60, 20, 20))
            print(path, "ERR", e)
        x, y = (i % cols) * CELL, (i // cols) * (CELL + 22)
        sheet.paste(img, (x, y))
        dr.text((x + 8, y + CELL + 4), os.path.basename(path), fill=(220, 228, 236))
    sheet.save("/tmp/greybox_preview.png")
    print("wrote /tmp/greybox_preview.png", sheet.size)

if __name__ == "__main__":
    main()
