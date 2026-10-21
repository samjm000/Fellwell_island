// Fellwell Island: wet-rock darkening under and around the curtain.
// Same ribbon mesh as the curtain; multiplies whatever is beneath it.
shader_type canvas_item;
render_mode blend_mul;

uniform float wet : hint_range(0.0, 1.0) = 1.0;
uniform vec3 wet_colour = vec3(0.72, 0.77, 0.84);

void fragment() {
	float d = abs(UV.x - 0.5) * 2.0;
	float mask = (1.0 - smoothstep(0.85, 1.45, d))
		* smoothstep(-0.03, 0.04, UV.y) * (1.0 - smoothstep(0.95, 1.03, UV.y));
	COLOR = vec4(mix(vec3(1.0), wet_colour, wet * mask), 1.0);
}
