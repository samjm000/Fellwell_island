shader_type canvas_item;
// Catmull-Rom reconstruction of the existing pixels when enlarging a painting.
// Minification retains ordinary mipmaps; no detail or replacement art is made.
uniform vec4 source_bounds = vec4(0.0, 0.0, 1.0, 1.0);
varying vec4 painting_modulate;

void vertex() {
    painting_modulate = COLOR;
}

vec2 painting_uv(vec2 at, vec2 pixel_size) {
    vec2 inset = pixel_size * 0.5;
    return clamp(at, source_bounds.xy + inset, source_bounds.zw - inset);
}

void fragment() {
    vec2 footprint_x = dFdx(UV) / TEXTURE_PIXEL_SIZE;
    vec2 footprint_y = dFdy(UV) / TEXTURE_PIXEL_SIZE;
    float footprint = max(length(footprint_x), length(footprint_y));
    vec4 value;
    if (footprint >= 1.0) {
        value = texture(TEXTURE, UV);
    } else {
        vec2 sample_pos = UV / TEXTURE_PIXEL_SIZE;
        vec2 texel = floor(sample_pos - 0.5) + 0.5;
        vec2 f = sample_pos - texel;
        vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
        vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
        vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
        vec2 w3 = f * f * (-0.5 + 0.5 * f);
        vec2 w12 = w1 + w2;
        vec2 p0 = (texel - 1.0) * TEXTURE_PIXEL_SIZE;
        vec2 p12 = (texel + w2 / w12) * TEXTURE_PIXEL_SIZE;
        vec2 p3 = (texel + 2.0) * TEXTURE_PIXEL_SIZE;
        value = textureLod(TEXTURE, painting_uv(vec2(p0.x, p0.y), TEXTURE_PIXEL_SIZE), 0.0) * w0.x * w0.y;
        value += textureLod(TEXTURE, painting_uv(vec2(p12.x, p0.y), TEXTURE_PIXEL_SIZE), 0.0) * w12.x * w0.y;
        value += textureLod(TEXTURE, painting_uv(vec2(p3.x, p0.y), TEXTURE_PIXEL_SIZE), 0.0) * w3.x * w0.y;
        value += textureLod(TEXTURE, painting_uv(vec2(p0.x, p12.y), TEXTURE_PIXEL_SIZE), 0.0) * w0.x * w12.y;
        value += textureLod(TEXTURE, painting_uv(vec2(p12.x, p12.y), TEXTURE_PIXEL_SIZE), 0.0) * w12.x * w12.y;
        value += textureLod(TEXTURE, painting_uv(vec2(p3.x, p12.y), TEXTURE_PIXEL_SIZE), 0.0) * w3.x * w12.y;
        value += textureLod(TEXTURE, painting_uv(vec2(p0.x, p3.y), TEXTURE_PIXEL_SIZE), 0.0) * w0.x * w3.y;
        value += textureLod(TEXTURE, painting_uv(vec2(p12.x, p3.y), TEXTURE_PIXEL_SIZE), 0.0) * w12.x * w3.y;
        value += textureLod(TEXTURE, painting_uv(vec2(p3.x, p3.y), TEXTURE_PIXEL_SIZE), 0.0) * w3.x * w3.y;
    }
    COLOR = clamp(value, vec4(0.0), vec4(1.0)) * painting_modulate;
}
