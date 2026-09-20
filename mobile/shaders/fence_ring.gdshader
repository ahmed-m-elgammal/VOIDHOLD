// VOIDHOLD E2-03 — laser fence strand shader (Godot 4.7, Mobile renderer)
// Unshaded additive emissive: vertical strands + traveling pulse.
// Applied to quad segments forming the dome boundary ring. UV.x runs along
// the segment (scaled by world length), UV.y runs bottom->top.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D strand_tex : filter_linear, repeat_enable;
uniform sampler2D pulse_tex : filter_linear, repeat_enable;
uniform vec3 glow_color : source_color = vec3(0.28, 0.85, 1.0);
uniform float strand_count = 3.0;   // strands per world tile
uniform float pulse_speed = 0.22;   // UV.x scroll per second
uniform float brightness = 1.35;
uniform float daylight = 1.0;       // 0 night .. 1 day; fence pops at night

void fragment() {
	float strand = texture(strand_tex, vec2(fract(UV.x * strand_count), UV.y)).r;
	float pulse = texture(pulse_tex, vec2(fract(UV.x - TIME * pulse_speed), UV.y)).r;
	float falloff = sin(clamp(UV.y, 0.0, 1.0) * PI);
	float night_boost = mix(1.65, 1.0, daylight);
	float body = strand * (0.4 + 0.6 * pulse) * falloff;
	ALBEDO = glow_color * body * brightness * night_boost;
	ALPHA = clamp(body, 0.0, 1.0);
}
