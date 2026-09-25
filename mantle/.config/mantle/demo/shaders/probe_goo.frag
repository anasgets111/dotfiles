// TEMP demo for the shader node: a pill that splits into four gooey blobs as u_progress goes 0 -> 1,
// each blob staggered, with an SDF drop shadow. All geometry derives from u_progress + params.
uniform vec4 tint;
uniform float softness;
uniform float stagger;

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / max(k, 1e-3), 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float field(vec2 p) {
    vec2 mid = u_size * 0.5;
    float r = u_size.y * 0.22;
    float gap = u_size.x * 0.2;
    float d = 1e5;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        // Each blob leaves a little later than the one before it.
        float t = clamp(u_progress * (1.0 + 3.0 * stagger) - fi * stagger, 0.0, 1.0);
        vec2 c = mid + vec2((fi - 1.5) * gap * t, 0.0);
        d = smin(d, length(p - c) - r * (0.75 + 0.25 * t), softness);
    }
    return d;
}

void main() {
    vec2 p = v_uv * u_size;
    float d = field(p);
    float shape = clamp(0.5 - d, 0.0, 1.0);
    // Hue drifts across the width so the blobs read as separate.
    vec3 col = mix(tint.rgb, tint.bgr, v_uv.x);
    float shadow = 0.5 * (1.0 - smoothstep(-6.0, 16.0, field(p - vec2(0.0, 7.0))));
    vec4 fill = vec4(col * tint.a, tint.a) * shape;
    fragColor = fill + vec4(0.0, 0.0, 0.0, shadow) * (1.0 - fill.a);
}
