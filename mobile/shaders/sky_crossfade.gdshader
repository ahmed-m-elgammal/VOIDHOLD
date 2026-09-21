// VOIDHOLD E2-01 — day/night sky crossfade (Godot 4.7, Mobile renderer)
// Blends the day and night equirect panoramas continuously from the
// daylight value, replacing the hard panorama switch at the noon
// threshold. day_tex/night_tex are equirectangular panoramas
// (top of image = zenith), sampled with the standard lat/long mapping.
shader_type sky;

uniform sampler2D day_tex : filter_linear, repeat_enable, source_color;
uniform sampler2D night_tex : filter_linear, repeat_enable, source_color;
uniform float blend : hint_range(0.0, 1.0) = 1.0;   // 0 night .. 1 day
uniform float night_dim : hint_range(0.0, 2.0) = 0.9;

void sky() {
        vec3 dir = normalize(EYEDIR);
        vec2 uv = vec2(
                atan(dir.x, -dir.z) / (2.0 * PI) + 0.5,
                acos(clamp(dir.y, -1.0, 1.0)) / PI
        );
        vec3 day = texture(day_tex, uv).rgb;
        vec3 night = texture(night_tex, uv).rgb * night_dim;
        COLOR = mix(night, day, blend);
}
