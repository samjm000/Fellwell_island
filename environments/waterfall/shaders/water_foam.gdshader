// Fellwell Island: impact foam. Boils in place at the base of the fall, never slides.
// Put on a ColorRect centred on the impact; the foam ellipse fills ~83% of the rect.
shader_type canvas_item;

uniform sampler2D foam_tex : repeat_enable, filter_linear;
uniform float anim_time = 0.0;
uniform float impact : hint_range(0.0, 1.0) = 1.0;
uniform vec2 rect_size = vec2(1092.0, 348.0);
uniform float art_scale = 1.818;        // plate pixels per design unit
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 night_tint = vec3(0.26, 0.33, 0.58);

void fragment() {
	vec2 p = UV * rect_size / art_scale;
	float e = length((UV - 0.5) * 2.0 * 1.2);
	float t = anim_time;
	float f1 = texture(foam_tex, p / 200.0 + vec2(0.0, -t * 0.16)).r;
	float f2 = texture(foam_tex, p * vec2(1.0, 1.7) / 130.0 + vec2(t * 0.07, -t * 0.24)).r;
	float boil = texture(foam_tex, p / 320.0 + vec2(t * 0.02, t * 0.035)).g;
	float fv = f1 * 0.5 + f2 * 0.5 + boil * 0.35 - e * 0.75;
	float thr = mix(0.95, 0.38, impact);
	float foam = smoothstep(thr, thr + 0.14, fv) * impact;
	float churn = smoothstep(1.15, 0.15, e) * impact * 0.55;
	float a = clamp(foam * 0.95 + churn, 0.0, 1.0);
	vec3 col = vec3(0.94, 0.99, 1.0);
	col += night * 0.8 * 0.9 * vec3(0.22, 0.33, 0.44) / max(night_tint, vec3(0.05));
	COLOR = vec4(col, a);
}
