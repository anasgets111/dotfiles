// The launcher's search pill budding into four rail buttons as `u_progress` runs 0 to 1.
//
// ponytail: `modules/global/launcher/rail.lua` repeats the growth and travel constants to place the
// buttons and their blur. `params` is not tweened, so only `u_progress` can drive both; keep them in step.
// Premultiplied, from `theme.rgba`.
uniform vec4 fill;
uniform float gap;
uniform float layout_width;

float response(float delayTime, float decay, float frequency, float phase) {
    float time = max(0.0, clamp(u_progress, 0.0, 1.0) - delayTime);
    float endTime = 1.0 - delayTime;
    float value = 1.0 - exp(-decay * time) * (cos(frequency * time) + phase * sin(frequency * time));
    float terminal = 1.0 - exp(-decay * endTime)
        * (cos(frequency * endTime) + phase * sin(frequency * endTime));
    return value / terminal;
}

float growth(int index) {
    if (index == 0) return response(0.055, 10.5, 10.5, 1.0);
    float rates[3] = float[3](3.8, 3.1, 2.7);
    float rate = rates[index - 1];
    return response(0.0, rate, rate, 0.0);
}

vec4 buttonShape(int index, float expandedRight, float diameter) {
    float emergence = diameter * 0.3 * (growth(0) - 1.0);
    float center = expandedRight + gap + diameter * 0.5 + emergence;
    if (index > 0) {
        float delays[3] = float[3](0.06, 0.036, 0.032);
        float decays[3] = float[3](7.2, 5.4, 5.4);
        float frequencies[3] = float[3](8.9, 6.2, 5.35);
        int trailing = index - 1;
        float decay = decays[trailing];
        float frequency = frequencies[trailing];
        center += float(index) * (diameter + gap)
            * response(delays[trailing], decay, frequency, decay / frequency);
    }
    float size = diameter * growth(index);
    return vec4(center, diameter * 0.5, size, size);
}

float buttonBlend(int index, vec4 shape, vec4 previous, float mainRight, float diameter) {
    float previousCenter = index == 0 ? mainRight - diameter * 0.5 : previous.x;
    float radii = (min(previous.z, previous.w) + min(shape.z, shape.w)) * 0.5;
    float separation = radii > 0.0 ? abs(shape.x - previousCenter) / radii : 0.0;
    float exposed = smoothstep(0.5, 1.0, separation);
    float release = smoothstep(0.27 + float(index) * 0.063,
        0.47 + float(index) * 0.063, u_progress);
    return min(min(shape.z, shape.w), diameter) * 0.78 * exposed * (1.0 - release);
}

float shapeDistance(vec2 pixel, vec4 shape) {
    if (min(shape.z, shape.w) <= 0.001) return 1e5;
    float radius = min(shape.z, shape.w) * 0.5;
    vec2 edge = abs(pixel - shape.xy) - shape.zw * 0.5 + vec2(radius);
    return min(max(edge.x, edge.y), 0.0) + length(max(edge, vec2(0.0))) - radius;
}

float smoothMinimum(float first, float second, float radius) {
    if (radius <= 0.001) return min(first, second);
    float influence = max(radius - abs(first - second), 0.0) / radius;
    return min(first, second) - influence * influence * radius * 0.25;
}

void main() {
    vec2 pixel = v_uv * u_size;
    float diameter = u_size.y;
    float expandedRight = layout_width - 4.0 * (diameter + gap);
    float mainWidth = mix(layout_width, expandedRight, response(0.0, 6.2, 7.5, 0.4));
    vec4 mainShape = vec4(mainWidth * 0.5, diameter * 0.5, mainWidth, diameter);
    vec4 button0Shape = buttonShape(0, expandedRight, diameter);
    vec4 button1Shape = buttonShape(1, expandedRight, diameter);
    vec4 button2Shape = buttonShape(2, expandedRight, diameter);
    vec4 button3Shape = buttonShape(3, expandedRight, diameter);
    vec4 blends = vec4(
        buttonBlend(0, button0Shape, mainShape, mainWidth, diameter),
        buttonBlend(1, button1Shape, button0Shape, mainWidth, diameter),
        buttonBlend(2, button2Shape, button1Shape, mainWidth, diameter),
        buttonBlend(3, button3Shape, button2Shape, mainWidth, diameter)
    );
    float surface = shapeDistance(pixel, mainShape);
    surface = smoothMinimum(surface, shapeDistance(pixel, button0Shape), blends.x);
    surface = smoothMinimum(surface, shapeDistance(pixel, button1Shape), blends.y);
    surface = smoothMinimum(surface, shapeDistance(pixel, button2Shape), blends.z);
    surface = smoothMinimum(surface, shapeDistance(pixel, button3Shape), blends.w);
    float aa = max(fwidth(surface), 0.001);
    fragColor = fill * (1.0 - smoothstep(-aa * 0.5, aa * 0.5, surface));
}
