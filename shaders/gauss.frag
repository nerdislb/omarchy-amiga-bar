#version 440
// Separable Gaussian blur for the Lavur sheet (InkSheet): one direction per
// pass, two widths at once – .r with σ s1, .g with σ s2 (s2 ≤ 0: .g = .r).
// The first pass reads the source's alpha (a mask), the second the first
// pass's .r and .g. Taps on whole logical pixels, at most ±24.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 dir;       // one logical pixel along the blur, in texture coordinates
    float s1;       // σ of the first blur, px
    float s2;       // σ of the second blur, px (≤ 0: none)
    float first;    // 1: read the source's alpha for both; 0: read .r and .g
};
layout(binding = 1) uniform sampler2D src;

void main() {
    float n = min(24.0, ceil(3.0 * max(s1, s2)));
    float k1 = -0.5 / max(s1 * s1, 0.0001);
    float k2 = -0.5 / max(s2 * s2, 0.0001);
    float a1 = 0.0, w1 = 0.0, a2 = 0.0, w2 = 0.0;
    for (int i = -24; i <= 24; i++) {
        float f = float(i);
        if (abs(f) > n) continue;
        vec4 t = texture(src, qt_TexCoord0 + dir * f);
        float g1 = exp(k1 * f * f);
        a1 += (first > 0.5 ? t.a : t.r) * g1;
        w1 += g1;
        if (s2 > 0.0) {
            float g2 = exp(k2 * f * f);
            a2 += (first > 0.5 ? t.a : t.g) * g2;
            w2 += g2;
        }
    }
    float b1 = a1 / w1;
    fragColor = vec4(b1, s2 > 0.0 ? a2 / w2 : b1, 0.0, 1.0);
}
