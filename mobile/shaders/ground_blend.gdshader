// VOIDHOLD E2-01 — planet ground blending shader (Godot 4.7, Mobile renderer)
// Blends snow / compacted / rock / ice material sets using the logical mask
// atlas generated from data/grid.json (1 texel = 1 tile, x right / y down).
// Mask sampling is quantized to texel centers and forced to LOD 0 so the
// logical grid stays exact regardless of import filter/mipmap settings.
// debug_view 1/2 render the raw mask atlases for the T2.1 grid spot-check.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D snow_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D compacted_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ice_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_variation : source_color, filter_linear_mipmap, repeat_enable;
// R=walkable G=mineable B=farmable A=oreMineable
uniform sampler2D mask_a : filter_linear, repeat_disable;
// R=noFence G=spawn B/A=reserved
uniform sampler2D mask_b : filter_linear, repeat_disable;

uniform float planet_size = 210.0;
uniform float tile_scale = 16.0; // whole tiles per texture repeat
uniform float macro_scale = 34.0;
uniform float rim_width = 7.0;
uniform int debug_view = 0; // 0 = off, 1 = mask_a, 2 = mask_b

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Exact logical-mask read: 1 texel = 1 tile, LOD forced to 0.
vec4 sample_mask(sampler2D mask_tex, vec2 world_xz, float size) {
	vec2 cell = floor(world_xz) + vec2(0.5);
	vec2 uv = cell / size;
	return textureLod(mask_tex, uv, 0.0);
}

// 5-tap cross blur so zone borders read as ~1 tile soft edges, not aliasing.
vec4 sample_mask_blur(sampler2D mask_tex, vec2 world_xz, float size) {
	vec4 c = sample_mask(mask_tex, world_xz, size) * 0.34;
	c += sample_mask(mask_tex, world_xz + vec2(1.0, 0.0), size) * 0.165;
	c += sample_mask(mask_tex, world_xz + vec2(-1.0, 0.0), size) * 0.165;
	c += sample_mask(mask_tex, world_xz + vec2(0.0, 1.0), size) * 0.165;
	c += sample_mask(mask_tex, world_xz + vec2(0.0, -1.0), size) * 0.165;
	return c;
}

void fragment() {
	vec2 world_xz = v_world.xz;
	vec2 tile_uv = world_xz / tile_scale;
	vec2 macro_uv = world_xz / macro_scale;

	vec4 ma = sample_mask_blur(mask_a, world_xz, planet_size);
	vec4 mb = sample_mask(mask_b, world_xz, planet_size);

	if (debug_view >= 1) {
		// Raw logical masks for the mask/grid spot-check.
		vec3 dbg = vec3(ma.r, ma.g, ma.b) * 0.75 + ma.a * vec3(0.25, 0.45, 0.6);
		if (debug_view == 2) {
			dbg = vec3(mb.r * 0.4, mb.g, mb.g * 0.7) + vec3(0.04, 0.05, 0.08);
		}
		ALBEDO = dbg;
		ROUGHNESS = 0.9;
		METALLIC = 0.0;
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	} else {
		vec4 macro = texture(macro_variation, macro_uv);
		float accum = macro.g;  // snow accumulation: snow wins over rock in dips

		float mine = clamp(ma.g * 1.45 - accum * 0.7, 0.0, 1.0);
		float farm = clamp(ma.b * 1.25, 0.0, 1.0);
		float ore = clamp(ma.a * 1.3, 0.0, 1.0);

		vec3 alb_snow = texture(snow_albedo, tile_uv).rgb;
		vec3 alb_comp = texture(compacted_albedo, tile_uv).rgb;
		vec3 alb_rock = texture(rock_albedo, tile_uv).rgb;
		vec3 alb_ice = texture(ice_albedo, tile_uv).rgb;

		vec3 alb = alb_snow;
		alb = mix(alb, alb_comp, farm);
		alb = mix(alb, alb_ice, ore);
		alb = mix(alb, alb_rock, mine);

		// Broad macro variation: tonal breaks + mineral tint in ore zones.
		alb *= 0.82 + 0.36 * macro.r;
		alb = mix(alb, alb * vec3(0.92, 0.97, 1.1), ore * macro.b * 1.6);
		// Spawn pads: faint warm marking so landings read on the ground.
		alb = mix(alb, alb * 0.92 + vec3(0.1, 0.085, 0.05), mb.g * 0.85);

		// Planet bounds: darken toward the void rim.
		vec2 half_rel = abs(v_world.xz - vec2(planet_size * 0.5)) / (planet_size * 0.5);
		float edge = max(half_rel.x, half_rel.y);
		float rim = smoothstep(1.0 - rim_width / (planet_size * 0.5), 1.0, edge);
		alb *= 1.0 - 0.4 * rim;

		vec3 n_snow = texture(snow_normal, tile_uv).rgb;
		vec3 n_rock = texture(rock_normal, tile_uv).rgb;
		vec3 n = mix(n_snow, n_rock, clamp(mine * 1.2, 0.0, 1.0));

		float rough_snow = 0.5 + 0.14 * macro.g;
		float rough = rough_snow;
		rough = mix(rough, 0.78, farm);
		rough = mix(rough, 0.22, ore);
		rough = mix(rough, 0.9, mine);

		ALBEDO = alb;
		NORMAL_MAP = n;
		ROUGHNESS = rough;
		METALLIC = 0.0;
	}
}
