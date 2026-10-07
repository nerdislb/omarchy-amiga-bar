#version 440
// Liquid metal for the Chrom & Platin themes (design round 07.10.2026,
// recommendation): a chrome tube along a rounded rect (mode 0, rims), along a
// circle with a filled arc (mode 1, quota rings) or a cylinder bar (mode 2,
// meters). The environment is a dark studio whose light stripes lie around the
// outline's normal; `t` turns them (still unless the material flows), `sweep`
// runs one glint along the shape, and a small per-channel offset gives the
// orange/blue fringes at the brightest stripe edges – strongest inside the
// glint. Ported from the round's WebGL renderer (src/metal.js).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // item size, px
    vec4 rect;      // the shape inside the item: x, y, w, h, px
    float radius;   // corner radius (mode 0, 2), px
    float tube;     // tube width (mode 0, 1), px
    float mode;     // 0 rim, 1 ring, 2 pill
    float arc;      // ring: filled fraction from the top, clockwise; pill: filled fraction from the left (1 = all)
    float dim;      // brightness of the unfilled part (ring)
    float boost;    // extra light (hover)
    float sweep;    // glint position along the shape (0–1)
    float sweepAmt; // glint strength (0 = none)
    float t;        // stripe phase
    float disp;     // dispersion (fringe width)
    float spark;    // fringe strength
    float sharp;    // stripe sharpness (0 soft – 1 sharp)
    float gain;     // stripe brightness
    float base;     // studio brightness
    float lightOn;  // 1 = light theme (bright studio)
    vec4 tint;      // metal colour
    vec4 track;     // pill: the unfilled part's colour
};

const float PI = 3.14159265, TAU = 6.2831853;

float sdRR(vec2 p, vec4 r, float rad) {
    vec2 c = r.xy + r.zw * 0.5;
    rad = min(rad, 0.5 * min(r.z, r.w));
    vec2 q = abs(p - c) - r.zw * 0.5 + rad;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;
}
float field(vec2 p) {
    if (mode > 0.5 && mode < 1.5) return length(p - (rect.xy + rect.zw * 0.5)) - rect.z * 0.5;
    return sdRR(p, rect, radius);
}
float stripes(float ph) {
    float s = 0.0;
    for (int k = 0; k < 4; k++) {
        float fk = float(k);
        float c = fk * 2.15 + 0.55 * sin(t * 0.21 + fk * 1.7);
        float d = abs(mod(ph - c + PI, TAU) - PI);
        float w = mix(0.26, 0.075, sharp) * (1.0 + 0.45 * fk / 3.0);
        s += exp(-d * d / (w * w)) * (1.35 - 0.28 * fk);
    }
    return s;
}
vec3 shade(vec3 N, float phi, float along) {
    vec3 R = reflect(vec3(0.0, 0.0, -1.0), N);
    float up = R.y, elev = clamp(R.z, 0.0, 1.0);
    float b = lightOn > 0.5 ? mix(0.30, 0.95, smoothstep(-0.75, 0.85, up))
                            : mix(0.09, 0.66, smoothstep(-0.65, 0.85, up));
    b *= base;
    float ph = phi + along * TAU * (mode > 0.5 && mode < 1.5 ? 0.0 : 1.0) + t;
    float L = stripes(ph);
    float dd = disp * 0.03;
    float sr = stripes(ph - dd), sb = stripes(ph + dd);
    float k = mix(0.75, 1.35, 1.0 - elev) * gain * (1.0 + boost);
    vec3 col = vec3(b + L * k);
    float sw = 0.0;
    if (sweepAmt > 0.0) { float d = abs(fract(along - sweep + 0.5) - 0.5); sw = sweepAmt * exp(-d * d / 0.0025); }
    float sp = (sr - sb) * k * smoothstep(0.15, 0.9, L);
    col += spark * (1.0 + 4.0 * sw) * (max(sp, 0.0) * vec3(1.0, 0.5, 0.12) + max(-sp, 0.0) * vec3(0.18, 0.5, 1.0));
    col += sw * vec3(1.15);
    return col * tint.rgb;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float d = field(p);
    vec2 e = vec2(0.6, 0.0);
    vec2 g = vec2(field(p + e.xy) - field(p - e.xy), field(p + e.yx) - field(p - e.yx));
    g = g / max(length(g), 1e-5);
    float phi = atan(-g.y, g.x);
    vec2 c = rect.xy + rect.zw * 0.5;
    // rings: angle from the top, clockwise; rects: a continuous diagonal coordinate (no seam)
    float along = (mode > 0.5 && mode < 1.5) ? fract(atan(p.x - c.x, -(p.y - c.y)) / TAU + 1.0) : (p.x * 0.9 + p.y * 0.45) / 700.0;
    vec3 col;
    float cov;
    if (mode < 1.5) {
        float hw = tube * 0.5;
        float dc = d + hw;
        cov = clamp(hw - abs(dc) + 0.5, 0.0, 1.0);
        if (cov <= 0.0) { fragColor = vec4(0.0); return; }
        float a = clamp(abs(dc) / hw, 0.0, 1.0);
        float h = sqrt(max(0.0, 1.0 - a * a));
        vec2 n2 = g * sign(dc) * a;
        vec3 N = normalize(vec3(n2.x, -n2.y, h + 0.05));
        col = shade(N, phi, along) * mix(0.55, 1.0, h);
        if (mode > 0.5 && arc < 0.999) col = mix(col * dim, col, step(along, arc));
    } else {
        cov = clamp(0.5 - d, 0.0, 1.0);
        if (cov <= 0.0) { fragColor = vec4(0.0); return; }
        float bev = 0.5 * min(rect.z, rect.w);
        float slope = 1.0 - clamp(-d / bev, 0.0, 1.0);
        float hz = sqrt(max(0.03, 1.0 - slope * slope));
        vec3 N = normalize(vec3(g.x * slope, -g.y * slope, hz));
        col = shade(N, phi, along);
        if (arc < 0.999) col = mix(track.rgb + col * 0.12, col, step((p.x - rect.x) / rect.z, arc));
    }
    float alpha = cov * qt_Opacity;
    fragColor = vec4(col * alpha, alpha);
}
