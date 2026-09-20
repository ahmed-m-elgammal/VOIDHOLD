#!/usr/bin/env python3
"""Minimal glTF 2.0 binary (.glb) writer for VOIDHOLD greybox models.

Builds valid glTF 2.0 containers with:
  - one mesh per model, one primitive per material (few draw calls)
  - POSITION + NORMAL accessors, flat-shaded triangles
  - named pbrMetallicRoughness materials (stable names per art bible)
  - alpha-blend support for glass, emissive factors for glow parts

Only what the greybox kit needs — no skins, no animations, no textures
(colors are material factors; PBR maps arrive with Epic 5 authored art).
"""
import json, struct

# ------------------------------------------------------------ materials ----
# Stable material names shared by every VOIDHOLD model (art bible palette).
VH_MATERIALS = {
    "VH_AlloyDark":  dict(baseColor=[0.227, 0.278, 0.314, 1.0], metal=0.65, rough=0.55),
    "VH_AlloyPaint": dict(baseColor=[0.306, 0.361, 0.404, 1.0], metal=0.35, rough=0.60),
    "VH_Snow":       dict(baseColor=[0.910, 0.933, 0.957, 1.0], metal=0.0, rough=0.92),
    "VH_Rock":       dict(baseColor=[0.420, 0.447, 0.502, 1.0], metal=0.0, rough=0.85),
    "VH_Ice":        dict(baseColor=[0.749, 0.863, 0.933, 1.0], metal=0.0, rough=0.22),
    "VH_AmberPaint": dict(baseColor=[1.0, 0.690, 0.125, 1.0], metal=0.15, rough=0.50),
    "VH_CyanGlow":   dict(baseColor=[0.180, 0.278, 0.302, 1.0], metal=0.0, rough=0.40,
                          emissive=[0.25, 1.0, 1.0]),
    "VH_WarmGlow":   dict(baseColor=[0.420, 0.322, 0.208, 1.0], metal=0.0, rough=0.50,
                          emissive=[1.0, 0.62, 0.22]),
    "VH_GlassGreen": dict(baseColor=[0.600, 0.820, 0.670, 0.72], metal=0.0, rough=0.18,
                          alpha="BLEND", double=True),
    "VH_GlassDark":  dict(baseColor=[0.133, 0.188, 0.235, 0.85], metal=0.1, rough=0.25,
                          alpha="BLEND", double=True),
    "VH_DomeShell":  dict(baseColor=[0.62, 0.78, 0.88, 0.14], metal=0.0, rough=0.12,
                          alpha="BLEND", double=True),
    "VH_White":      dict(baseColor=[0.86, 0.89, 0.92, 1.0], metal=0.1, rough=0.55),
}

class GLBBuilder:
    """Accumulate triangles per material, then emit a .glb byte string."""

    def __init__(self, name):
        self.name = name
        self.tris = {}  # material name -> list[(v0, v1, v2)] with v=(x,y,z)

    def add_tri(self, mat, v0, v1, v2):
        self.tris.setdefault(mat, []).append((v0, v1, v2))

    def add_quad(self, mat, v0, v1, v2, v3):
        self.add_tri(mat, v0, v1, v2)
        self.add_tri(mat, v0, v2, v3)

    # ------------------------------------------------------------- output --
    def emit(self):
        mat_names = list(self.tris.keys())
        bin_data = bytearray()
        buffer_views, accessors, primitives = [], [], []

        def push_view(data, target):
            offset = len(bin_data)
            pad = (4 - offset % 4) % 4
            bin_data.extend(b"\x00" * pad)
            offset = len(bin_data)
            bin_data.extend(data)
            buffer_views.append(dict(buffer=0, byteOffset=offset,
                                     byteLength=len(data), target=target))
            return len(buffer_views) - 1

        for mat in mat_names:
            tris = self.tris[mat]
            pos, idx = [], []
            for (a, b, c) in tris:
                base = len(pos)
                pos += [a, b, c]
                idx += [base, base + 1, base + 2]
            # flat normals from face geometry
            nrm = []
            for (a, b, c) in tris:
                ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
                vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
                nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
                ln = (nx * nx + ny * ny + nz * nz) ** 0.5 or 1.0
                n = (nx / ln, ny / ln, nz / ln)
                nrm += [n, n, n]

            pos_f = struct.pack("<%df" % (len(pos) * 3),
                                *[c for v in pos for c in v])
            nrm_f = struct.pack("<%df" % (len(nrm) * 3),
                                *[c for v in nrm for c in v])
            idx_u32 = struct.pack("<%dI" % len(idx), *idx)

            minx = min(v[0] for t in tris for v in t)
            miny = min(v[1] for t in tris for v in t)
            minz = min(v[2] for t in tris for v in t)
            maxx = max(v[0] for t in tris for v in t)
            maxy = max(v[1] for t in tris for v in t)
            maxz = max(v[2] for t in tris for v in t)

            pv = push_view(pos_f, 34962)
            nv = push_view(nrm_f, 34962)
            iv = push_view(idx_u32, 34963)

            accessors.append(dict(bufferView=pv, componentType=5126, count=len(pos),
                                  type="VEC3", min=[minx, miny, minz], max=[maxx, maxy, maxz]))
            pa = len(accessors) - 1
            accessors.append(dict(bufferView=nv, componentType=5126, count=len(nrm), type="VEC3"))
            na = len(accessors) - 1
            accessors.append(dict(bufferView=iv, componentType=5125, count=len(idx), type="SCALAR"))
            ia = len(accessors) - 1

            primitives.append(dict(attributes=dict(POSITION=pa, NORMAL=na),
                                   indices=ia, material=mat_names.index(mat)))

        pad_end = (4 - len(bin_data) % 4) % 4
        bin_data.extend(b"\x00" * pad_end)

        materials = []
        for name in mat_names:
            m = VH_MATERIALS[name]
            entry = dict(name=name,
                         pbrMetallicRoughness=dict(
                             baseColorFactor=m["baseColor"],
                             metallicFactor=m["metal"],
                             roughnessFactor=m["rough"]))
            if m.get("emissive"):
                entry["emissiveFactor"] = m["emissive"]
            if m.get("alpha") == "BLEND":
                entry["alphaMode"] = "BLEND"
            if m.get("double"):
                entry["doubleSided"] = True
            materials.append(entry)

        gltf = dict(
            asset=dict(version="2.0",
                       generator="VOIDHOLD asset_gen (procedural greybox)"),
            scene=0,
            scenes=[dict(name=self.name, nodes=[0])],
            nodes=[dict(name=self.name, mesh=0)],
            meshes=[dict(name=self.name + "_mesh", primitives=primitives)],
            materials=materials,
            accessors=accessors,
            bufferViews=buffer_views,
            buffers=[dict(byteLength=len(bin_data))],
        )

        json_blob = json.dumps(gltf, separators=(",", ":")).encode()
        json_pad = (4 - len(json_blob) % 4) % 4
        json_blob += b" " * json_pad

        total = 12 + 8 + len(json_blob) + 8 + len(bin_data)
        out = bytearray()
        out += struct.pack("<III", 0x46546C67, 2, total)          # magic 'glTF', version, length
        out += struct.pack("<II", len(json_blob), 0x4E4F534A)     # JSON chunk
        out += json_blob
        out += struct.pack("<II", len(bin_data), 0x004E4942)      # BIN chunk
        out += bin_data
        return bytes(out)


# ------------------------------------------------------- geometry helpers --
import math

def rot_y(v, ang):
    c, s = math.cos(ang), math.sin(ang)
    return (v[0] * c + v[2] * s, v[1], -v[0] * s + v[2] * c)

def rot_x(v, ang):
    c, s = math.cos(ang), math.sin(ang)
    return (v[0], v[1] * c - v[2] * s, v[1] * s + v[2] * c)

def rot_z(v, ang):
    c, s = math.cos(ang), math.sin(ang)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c, v[2])

def tr(v, dx, dy, dz):
    return (v[0] + dx, v[1] + dy, v[2] + dz)
