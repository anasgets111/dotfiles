#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float barCount;
    float gapPx;
    float minHeightPx;
    float pxWidth;
    float pxHeight;
    vec4 barColor;
    mat4 levels0;
    mat4 levels1;
    mat4 levels2;
    mat4 levels3;
    mat4 levels4;
    mat4 levels5;
    mat4 levels6;
    mat4 levels7;
    mat4 levels8;
    mat4 levels9;
    mat4 levels10;
    mat4 levels11;
    mat4 levels12;
    mat4 levels13;
    mat4 levels14;
    mat4 levels15;
} ubuf;

float matrixLevel(mat4 levels, int index) {
    int row = index / 4;
    int column = index - row * 4;
    return levels[column][row];
}

float levelAt(int index) {
    int group = index / 16;
    int local = index - group * 16;
    if (group == 0) return matrixLevel(ubuf.levels0, local);
    if (group == 1) return matrixLevel(ubuf.levels1, local);
    if (group == 2) return matrixLevel(ubuf.levels2, local);
    if (group == 3) return matrixLevel(ubuf.levels3, local);
    if (group == 4) return matrixLevel(ubuf.levels4, local);
    if (group == 5) return matrixLevel(ubuf.levels5, local);
    if (group == 6) return matrixLevel(ubuf.levels6, local);
    if (group == 7) return matrixLevel(ubuf.levels7, local);
    if (group == 8) return matrixLevel(ubuf.levels8, local);
    if (group == 9) return matrixLevel(ubuf.levels9, local);
    if (group == 10) return matrixLevel(ubuf.levels10, local);
    if (group == 11) return matrixLevel(ubuf.levels11, local);
    if (group == 12) return matrixLevel(ubuf.levels12, local);
    if (group == 13) return matrixLevel(ubuf.levels13, local);
    if (group == 14) return matrixLevel(ubuf.levels14, local);
    if (group == 15) return matrixLevel(ubuf.levels15, local);
    return 0.0;
}

void main() {
    float n = ubuf.barCount;
    if (n < 1.0 || ubuf.pxWidth < 1.0 || ubuf.pxHeight < 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    float slot = qt_TexCoord0.x * n;
    float slotPx = ubuf.pxWidth / n;
    // Never spend more than half a slot on the gap, or narrow bars vanish.
    float gap = clamp(ubuf.gapPx / slotPx, 0.0, 0.5);

    float level = levelAt(int(floor(slot)));
    float minH = ubuf.minHeightPx / ubuf.pxHeight;
    float h = max(minH, level);

    // Bars are ~1.5 px wide, so hard edges alias and the tops stair-step.
    // Half fwidth keeps each transition to roughly one pixel; centring the
    // phase antialiases both bar edges instead of only the trailing one.
    float xw = 0.5 * fwidth(slot);
    float phase = fract(slot) - 0.5;
    float xDist = 0.5 * (1.0 - gap) - abs(phase);
    float cov = gap > 0.0 ? smoothstep(-xw, xw, xDist) : 1.0;

    float yw = 0.5 * fwidth(qt_TexCoord0.y);
    float yDist = qt_TexCoord0.y - (1.0 - h);
    cov *= smoothstep(-yw, yw, yDist);

    fragColor = ubuf.barColor * ubuf.qt_Opacity * cov;
}
