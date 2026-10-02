// Cava's spectrum as a bundle of glowing waves: phase-shifted sines whose envelope is the spectrum.
uniform vec4 levels[64]; // 256 bars, four to an element
uniform float phase; // cava frames so far; the carrier drifts with them and stops with the music
uniform float strength; // overall alpha
uniform vec4 stops[5]; // premultiplied, from `theme.SPECTRUM`, left to right

const int LINES = 6;
const int POINTS = 32; // envelope control points, eight bars each

float point(int k) {
    k = clamp(k, 0, POINTS - 1);
    vec4 a = levels[k * 2];
    vec4 b = levels[k * 2 + 1];
    return dot(a + b, vec4(0.125));
}

// Catmull-Rom through the control points, so the envelope is smooth where the bars step.
float envelope(float x) {
    float s = x * float(POINTS) - 0.5;
    int k = int(floor(s));
    float t = s - float(k);
    float p0 = point(k - 1);
    float p1 = point(k);
    float p2 = point(k + 1);
    float p3 = point(k + 2);
    return 0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
        + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t);
}

vec4 palette(float x) {
    float s = clamp(x, 0.0, 1.0) * 4.0;
    int i = min(int(s), 3);
    return mix(stops[i], stops[i + 1], s - float(i));
}

void main() {
    float x = v_uv.x;
    // Square-rooted: music averages about 0.12, which drew a near-flat line. Tapered at both ends so
    // the bundle meets the box edge on the midline.
    float amp = min(sqrt(max(envelope(x), 0.0)) * 0.8, 0.46) * smoothstep(0.0, 0.08, x) * smoothstep(1.0, 0.92, x);
    float light = 0.0;
    for (int i = 0; i < LINES; i++) {
        float f = float(i) / float(LINES - 1);
        // Each line its own carrier, phase and share of the envelope, so the bundle fans and crosses.
        float carrier = sin(6.2831853 * (x * (2.0 + 0.6 * f) + f * 0.55) + phase * (0.06 + 0.03 * f));
        float y = 0.5 + amp * (0.25 + 0.75 * f) * carrier;
        float dy = v_uv.y - y;
        // Distance in px from screen-space derivatives, so a steep stretch stays as thin as a flat one.
        float d = abs(dy) / max(length(vec2(dFdx(dy), dFdy(dy))), 1e-4);
        light += (smoothstep(0.9, 0.0, d) + 0.22 * exp(-d / 2.5)) * (0.45 + 0.55 * f);
    }
    fragColor = palette(x) * min(light, 1.0) * strength;
}
