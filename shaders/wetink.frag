#version 440
// Wet ink for the Lavur bloom (MaterialCard, Tusche Island notes): the bloom's
// body in ink, cleared by the water from the source outward – the pigment
// travels as a ridge into the tide line (bar round 03.10.2026, study 6).
// `mask` is the bloom's sheet layer (its alpha = inside the bloom).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // size of the mask (the sheet layer), px
    vec2 center;    // the source (where the water comes from), mask px
    vec4 region;    // this item's place on the mask: x, y, w, h, px
    vec4 ink;       // pigment colour
    float front;    // radius the water has cleared, px
    float band;     // width of the pigment ridge in front of it, px
    float body;     // ink before the water passes
    float ridge;    // extra ink in the ridge
    float resid;    // ink left behind the front
    float jitter;   // how far the front swells, px
    float seed;
};
layout(binding = 1) uniform sampler2D mask;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void main() {
    // the item covers only `region`: map to the mask's pixels (the mask holds every bloom)
    vec2 px = region.xy + qt_TexCoord0 * region.zw;
    float m = texture(mask, px / size).a;
    if (m <= 0.002) {
        fragColor = vec4(0.0);
        return;
    }
    vec2 d2 = px - center;
    float ang = atan(d2.y, d2.x);
    float wob = jitter * (0.45 * sin(2.0 * ang + seed) + 0.3 * sin(5.0 * ang + seed * 2.1)
                        + 0.15 * sin(11.0 * ang + seed * 3.7) + 0.1 * sin(23.0 * ang + seed * 5.3));
    float dist = length(d2) + wob + 5.0 * (vnoise(px / 12.0) - 0.5);
    float cleared = 1.0 - smoothstep(front - band, front, dist);          // 1 = the water has passed
    float rg = (dist - front + band * 0.35) / (band * 0.2);
    float b = body * (1.0 - cleared) + ridge * exp(-rg * rg) + resid * cleared;
    // granulation: pigment settles in the paper's tooth (2–3 px) and gathers in soft clouds (~10 px)
    float gran = 0.55 + 0.9 * (0.6 * vnoise(px / 2.5) + 0.4 * vnoise(px / 9.0));
    float a = clamp(b * gran, 0.0, 1.0) * m * ink.a * qt_Opacity;
    fragColor = vec4(ink.rgb * a, a);
}
