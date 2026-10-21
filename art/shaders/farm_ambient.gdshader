shader_type canvas_item;
render_mode unshaded;
uniform sampler2D environment_mask : filter_linear, repeat_disable;
uniform sampler2D detail_mask : filter_linear, repeat_disable;
uniform float environment_phase = 0.0;
uniform float detail_phase = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
varying vec4 farm_tint;
void vertex() { farm_tint = COLOR; }
void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec3 env = texture(environment_mask, UV).rgb;
	vec2 detail = texture(detail_mask, UV).rg;
	float e = environment_phase * TAU;
	float d = detail_phase * TAU;
	// Integer harmonics keep both tracks seamless. Never use Godot TIME rollover.
	float breeze = sin(e * 4.0 + UV.y * 11.0) * 0.65 + sin(e * 7.0 + UV.x * 9.0) * 0.35;
	vec2 offset = vec2(breeze * 2.2, sin(e * 3.0 + UV.x * 12.0) * 0.45) * TEXTURE_PIXEL_SIZE;
	// Displacement is confined to vegetation; black margins anchor stems and fences.
	vec4 swayed = texture(TEXTURE, clamp(UV + offset * env.r * strength, vec2(0.0), vec2(1.0)));
	vec4 result = mix(original, swayed, env.r * strength);
	// Local water refraction moves painted reflections, with stationary banks.
	float wave_a = sin(UV.y * 220.0 + e * 8.0 + sin(UV.x * 38.0 + e * 3.0));
	float wave_b = sin(UV.x * 110.0 - e * 6.0 + UV.y * 70.0);
	vec2 water_offset = vec2(wave_a * 2.6, wave_b * 0.9) * TEXTURE_PIXEL_SIZE;
	vec4 water = texture(TEXTURE, clamp(UV + water_offset * env.g * strength, vec2(0.0), vec2(1.0)));
	result = mix(result, water, env.g * strength);
	float ripple = sin(UV.y * 740.0 + sin(UV.x * 55.0 + e * 3.0) * 1.5 + e * 8.0);
	float sea = sin(UV.y * 630.0 + e * 5.0 + sin(UV.x * 35.0 + e * 2.0));
	float light = sin(UV.x * 17.0 + sin(UV.y * 19.0 + d * 2.0) + d);
	float lantern = 0.55 * sin(d * 23.0) + 0.3 * sin(d * 37.0) + 0.15 * sin(d * 61.0);
	float gain = env.g * ripple * 0.022 + env.b * sea * 0.006;
	gain += detail.r * light * 0.008 + detail.g * lantern * 0.012;
	result.rgb *= 1.0 + strength * gain;
	COLOR = result * farm_tint;
}
