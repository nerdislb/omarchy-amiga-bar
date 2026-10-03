#version 440
// The Lavur sheet's paper (InkSheet): the blurred shapes cut at a gently
// noise-displaced threshold – a calm edge with one large, slow wobble of
// about ±1 px (frame round 03.10.2026, recommendation 6). The noise is in
// the card's own coordinates, so the pattern travels with the card; while
// wet the cut is softer and the wobble drifts.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // this item's size, px
    vec2 origin;    // the card's top-left, px
    float drift;    // the wobble's drift while wet, px
    float lo;       // the cut: smoothstep(lo, hi, blurred + amp · (noise − ½))
    float hi;
    float amp;
    vec4 paper;     // fill colour
};
layout(binding = 1) uniform sampler2D blurred;

float hash(vec2 p, float s) { return fract(sin(dot(p, vec2(127.1, 311.7)) + s * 17.0) * 43758.5453); }
float vnoise(vec2 p, float s) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i, s), hash(i + vec2(1.0, 0.0), s), u.x),
               mix(hash(i + vec2(0.0, 1.0), s), hash(i + vec2(1.0, 1.0), s), u.x), u.y);
}

void main() {
    float raw = texture(blurred, qt_TexCoord0).r;
    vec2 c = qt_TexCoord0 * size - origin;
    c.x += drift;
    // mostly one large, slow octave; the displacement fades out far from the shapes (no specks)
    float n = 0.78 * vnoise(c / 44.0, 7.0) + 0.22 * vnoise(c / 11.0, 10.0);
    float m = smoothstep(lo, hi, raw + amp * (n - 0.5) * smoothstep(0.0, 0.1, raw));
    float a = m * paper.a * qt_Opacity;
    fragColor = vec4(paper.rgb * a, a);
}
