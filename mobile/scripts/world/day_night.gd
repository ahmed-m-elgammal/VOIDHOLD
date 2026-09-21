class_name DayNight
extends Node

# E2-01/T2.1 day-night lerp: drives sun, sky, fog, and the solar multiplier.
# daylight goes 0 (night) .. 1 (noon); solar_multiplier feeds DomeSim.tune
# via PlanetWorld so solar output dips at night (visible in the debug HUD).

var t: float = 0.1                 # phase 0..1 (0 dawn, 0.25 noon, 0.5 dusk, 0.75 midnight)
var daylight: float = 1.0
var solar_multiplier: float = 1.0

var sun: DirectionalLight3D = null
var env: WorldEnvironment = null
var moon_sprite: GeometryInstance3D = null

var cycle_seconds: float = 360.0
var day_fraction: float = 0.66
var solar_night: float = 0.35
var sun_energy_day: float = 1.2
var sun_energy_night: float = 0.25
var ambient_day: float = 0.6
var ambient_night: float = 0.35

var _sky_mat: PanoramaSkyMaterial = null      # legacy hard-switch fallback
var _sky_cross: ShaderMaterial = null         # sky_crossfade.gdshader
var _tex_day: Texture2D = null
var _tex_night: Texture2D = null
var _night_showing: bool = false

const DAY_COLOR := Color("fff6e8")
const NIGHT_COLOR := Color("9fb6d4")
const FOG_DAY := Color("8fa8bc")
const FOG_NIGHT := Color("16283a")

static func load_json(path: String) -> Dictionary:
        var out: Dictionary = {}
        if FileAccess.file_exists(path) == false:
                return out
        var f: FileAccess = FileAccess.open(path, FileAccess.READ)
        if f == null:
                return out
        var text: String = f.get_as_text()
        f.close()
        var p: JSON = JSON.new()
        if p.parse(text) != OK:
                return out
        if p.data is Dictionary:
                return p.data
        return out

func configure_from_balance() -> void:
        var b: Dictionary = load_json("res://data/balance.json")
        if b.get("day_night") is Dictionary:
                var d: Dictionary = b["day_night"]
                cycle_seconds = float(d.get("cycle_seconds", cycle_seconds))
                day_fraction = clampf(float(d.get("day_fraction", day_fraction)), 0.05, 0.95)
                solar_night = clampf(float(d.get("solar_night", solar_night)), 0.0, 1.0)
                sun_energy_day = float(d.get("sun_energy_day", sun_energy_day))
                sun_energy_night = float(d.get("sun_energy_night", sun_energy_night))
                ambient_day = float(d.get("ambient_day", ambient_day))
                ambient_night = float(d.get("ambient_night", ambient_night))

func _ready() -> void:
        configure_from_balance()
        _tex_day = load("res://assets/world/sky/sky_day_panorama.png")
        _tex_night = load("res://assets/world/sky/sky_night_panorama.png")
        _detect_sky_material()

func _detect_sky_material() -> void:
        # env may be assigned after add_child (see PlanetWorld._ready order),
        # so detection is re-run lazily until it succeeds.
        if _sky_cross != null or _sky_mat != null:
                return
        if env == null or env.environment == null or env.environment.sky == null:
                return
        var mat: Material = env.environment.sky.sky_material
        # True crossfade: blend day/night panoramas every frame (E2-01
        # handoff: no hard switch at the noon threshold).
        if mat is ShaderMaterial:
                _sky_cross = mat
        elif mat is PanoramaSkyMaterial:
                _sky_mat = mat as PanoramaSkyMaterial

func _process(delta: float) -> void:
        if cycle_seconds > 0.0:
                t = fposmod(t + delta / cycle_seconds, 1.0)
        # Sun height: t=0 dawn, 0.25 noon, 0.5 dusk, 0.75 midnight.
        var sun_h: float = sin(t * TAU)
        daylight = clampf(sun_h * 1.45 + 0.1, 0.0, 1.0)
        solar_multiplier = lerpf(solar_night, 1.0, daylight)
        _apply_visuals(sun_h)

func _apply_visuals(sun_h: float) -> void:
        if sun != null:
                var pitch: float = -clampf(remap(sun_h, -0.25, 1.0, 16.0, 52.0), 16.0, 52.0)
                var yaw: float = lerpf(215.0, 35.0, clampf(sun_h * 0.5 + 0.5, 0.0, 1.0))
                sun.rotation_degrees = Vector3(pitch, yaw, 0.0)
                sun.light_color = NIGHT_COLOR.lerp(DAY_COLOR, daylight)
                sun.light_energy = lerpf(sun_energy_night, sun_energy_day, daylight)
        if env != null and env.environment != null:
                env.environment.ambient_light_energy = lerpf(ambient_night, ambient_day, daylight)
                env.environment.fog_light_color = FOG_NIGHT.lerp(FOG_DAY, daylight)
                env.environment.fog_density = lerpf(0.002, 0.0015, daylight)
        # Sky: continuous crossfade when the crossfade shader is present;
        # hard panorama swap kept only as a legacy fallback.
        _detect_sky_material()
        if _sky_cross != null:
                _sky_cross.set_shader_parameter("blend", smoothstep(0.14, 0.72, daylight))
        elif _sky_mat != null and _tex_night != null:
                var want_night: bool = daylight < 0.5
                if want_night != _night_showing:
                        _sky_mat.panorama = _tex_night if want_night else _tex_day
                        _night_showing = want_night
        if moon_sprite != null:
                var m: GeometryInstance3D = moon_sprite
                m.transparency = clampf(0.25 + 0.5 * (1.0 - daylight), 0.0, 0.8)

func phase_label() -> String:
        if t < 0.08 or t >= 0.92:
                return "dawn"
        if t < 0.42:
                return "day"
        if t < 0.58:
                return "dusk"
        return "night"
