// Fellwell Island: mist around the plunge pool. Rises slowly, lingers after the flow stops.
// Put on a ColorRect centred on the mist; the mist ellipse fills ~the whole rect.
shader_type canvas_item;

uniform sampler2D foam_tex : repeat_enable, filter_linear;
uniform float anim_time = 0.0;
uniform float mist : hint_range(0.0, 1.0) = 1.0;
uniform vec2 rect_size = vec2(1564.0, 836.0);
uniform float art_scale = 1.818;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 night_tint = vec3(0.26, 0.33, 0.58);

void fragment() {
	vec2 p = UV * rect_size / art_scale;
	float t = anim_time;
	float mm = smoothstep(1.0, 0.15, length((UV - 0.5) * 2.0));
	float mn = texture(foam_tex, p / 520.0 + vec2(t * 0.012, t * 0.045)).b
		* texture(foam_tex, p / 300.0 + vec2(-t * 0.02, t * 0.06)).g;
	float a = clamp(mm * (0.35 + mn * 2.2), 0.0, 1.0) * mist * 0.62;
	vec3 col = vec3(0.92, 0.97, 1.0);
	col += night * 0.7 * 0.9 * vec3(0.22, 0.33, 0.44) / max(night_tint, vec3(0.05));
	COLOR = vec4(col, a);
}
