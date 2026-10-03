#version 440
// The Lavur sheet's dried pigment (InkSheet; frame round 03.10.2026,
// recommendation 6 „getrockneter Pigmentrand“): the pigment the water pushed
// out stays just inside the edge – denser in a few short sections, light in
// between –, one broken, faint drying line ~3–4 px further in, and a trace
// of residue near the edge while it dries (the text area stays clean).
// `blurs` holds the paper's mask blurred: .r with σ 2.2 (the rim's distance
// to the edge), .g with σ 4 (the drying line and the residue). All noise is
// in the card's own coordinates.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // this item's size, px
    vec2 origin;    // the card's top-left, px
    vec4 ink;       // pigment colour
    float ridge;    // the rim's alpha where the pigment pooled
    float pool;     // the rim's density between the sections (0–1)
    float echo;     // the drying line's alpha
    float resid;    // the residue near the edge while it dries
    float show;     // the rim comes in while the water reaches the edge (0–1)
    float dry;      // the residue comes in as the wet ink's residue goes (0–1)
    float barY;     // the bar's lower edge, px: no pigment line up into it
};
layout(binding = 1) uniform sampler2D mask;
layout(binding = 2) uniform sampler2D blurs;

float hash(vec2 p, float s) { return fract(sin(dot(p, vec2(127.1, 311.7)) + s * 17.0) * 43758.5453); }
float vnoise(vec2 p, float s) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i, s), hash(i + vec2(1.0, 0.0), s), u.x),
               mix(hash(i + vec2(0.0, 1.0), s), hash(i + vec2(1.0, 1.0), s), u.x), u.y);
}

void main() {
    float m = texture(mask, qt_TexCoord0).a;
    if (m <= 0.002) {
        fragColor = vec4(0.0);
        return;
    }
    vec2 px = qt_TexCoord0 * size;
    vec2 c = px - origin;
    vec2 d = texture(blurs, qt_TexCoord0).rg;    // ≈ 0.5 at the edge, 1 deep inside
    float wN = vnoise(c / 34.0, 11.0), dN = vnoise(c / 12.0, 4.0);
    // sections: where the slow noise is high, the pigment pooled (pool → 1)
    float pooled = pool + (1.0 - pool) * smoothstep(0.38, 0.72, vnoise(c / 70.0, 17.0));
    float q = (d.r - (0.53 + 0.1 * wN)) / (0.055 + 0.07 * wN + 0.03 * pooled);
    float rim = exp(-q * q) * pooled * (0.6 + 0.4 * dN);
    // the drying line: only in places (broken), never a second outline
    float qe = (d.g - 0.82) / 0.045;
    float drying = exp(-qe * qe) * smoothstep(0.55, 0.78, vnoise(c / 48.0, 21.0));
    float nearEdge = 1.0 - smoothstep(0.8, 0.97, d.g);
    float gran = 0.55 + 0.9 * (0.6 * vnoise(c / 2.5, 5.0) + 0.4 * vnoise(c / 9.0, 5.0));
    // where the sheet flows out of the bar the water came from there: no rim up into it
    float junction = smoothstep(barY + 2.0, barY + 16.0, px.y);
    float a = clamp(((ridge * rim + echo * drying) * show * junction + resid * nearEdge * dry) * gran, 0.0, 1.0)
              * m * ink.a * qt_Opacity;
    fragColor = vec4(ink.rgb * a, a);
}
