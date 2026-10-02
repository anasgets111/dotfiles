// Cava's spectrum as bars on one quad, from `lib/cava.lua` through `modules/bar/indicators/media.lua`.
uniform vec4 levels[64]; // 256 bars, four to an element
uniform float count;
uniform float gap; // px between bars
uniform float min_height; // px, the flat row at rest
uniform vec4 color; // premultiplied, from `theme.rgba`

void main() {
    if (count < 1.0) {
        fragColor = vec4(0.0);
        return;
    }
    float slot = v_uv.x * count;
    int index = min(int(slot), int(count) - 1);
    float level = max(min_height / u_size.y, levels[index / 4][index % 4]);
    // Never spend more than half a slot on the gap, or narrow bars vanish.
    float gap_fraction = clamp(gap * count / u_size.x, 0.0, 0.5);

    // Bars are a few px wide: hard edges alias and the tops stair-step. Half `fwidth` keeps each
    // edge to about one pixel, and centring the phase antialiases both sides of a bar.
    float xw = 0.5 * fwidth(slot);
    float x = 0.5 * (1.0 - gap_fraction) - abs(fract(slot) - 0.5);
    float coverage = gap_fraction > 0.0 ? smoothstep(-xw, xw, x) : 1.0;
    float yw = 0.5 * fwidth(v_uv.y);
    coverage *= smoothstep(-yw, yw, v_uv.y - (1.0 - level));

    fragColor = color * coverage;
}
