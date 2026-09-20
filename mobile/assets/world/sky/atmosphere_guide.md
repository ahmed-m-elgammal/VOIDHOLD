# Atmosphere / lighting guide — E2-02

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
