#version 440
// Liquid metal for the Chrom & Platin themes (design round 07.10.2026,
// recommendation): a chrome tube along a rounded rect (mode 0, rims), along a
// circle with a filled arc (mode 1, quota rings), a cylinder bar (mode 2,
// meters) or only a glint running along a rounded rect (mode 3, window frames:
// the tube shows only around the glint, placed by arc length, so it keeps an
// even pace round the corners). The environment is a dark studio whose light
// stripes lie around the outline's normal; `t` turns them (still unless the
// material flows), `sweep` runs one glint along the shape, and a small
// per-channel offset gives the orange/blue fringes at the brightest stripe
// edges – strongest inside the glint. Ported from the round's WebGL renderer
// (src/metal.js).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // item size, px
    vec4 rect;      // the shape inside the item: x, y, w, h, px
    float radius;   // corner radius (mode 0, 2, 3), px
    float tube;     // tube width (mode 0, 1, 3), px
    float mode;     // 0 rim, 1 ring, 2 pill, 3 frame glint
    float arc;      // ring: filled fraction from the top, clockwise; pill: filled fraction from the left (1 = all);
                    // frame glint: the glint's length ahead of its head, a fraction of the perimeter
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
    vec4 track;     // pill, and rings in style 1/2: the unfilled part's colour (with its alpha)
    float ringStyle; // rings: 0 chrome all round (the rest dimmed), 1 chrome arc on a flat track,
                     // 2 a solid arc in `ink` with a chrome glint at its head, on a flat track
    vec4 ink;       // ring style 2: the arc's colour
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
// position along the rounded rect's outline (0–1), clockwise from the top
// edge's left end: straight edges and quarter arcs by their true length
float perimeterPos(vec2 p) {
    vec2 q = p - rect.xy;
    float w = rect.z, h = rect.w;
    float rr = min(radius, 0.5 * min(w, h));
    float ew = w - 2.0 * rr, eh = h - 2.0 * rr, qa = 0.5 * PI * rr;
    float P = 2.0 * (ew + eh) + 4.0 * qa;
    float s;
    if (q.x > w - rr && q.y < rr) s = ew + qa * atan(q.x - (w - rr), rr - q.y) / (0.5 * PI);
    else if (q.x > w - rr && q.y > h - rr) s = ew + qa + eh + qa * atan(q.y - (h - rr), q.x - (w - rr)) / (0.5 * PI);
    else if (q.x < rr && q.y > h - rr) s = 2.0 * ew + 2.0 * qa + eh + qa * atan(rr - q.x, q.y - (h - rr)) / (0.5 * PI);
    else if (q.x < rr && q.y < rr) s = 2.0 * ew + 3.0 * qa + 2.0 * eh + qa * atan(rr - q.y, rr - q.x) / (0.5 * PI);
    else {
        // a straight edge: the nearest one
        float dt = q.y, db = h - q.y, dl = q.x, dr = w - q.x;
        float m = min(min(dt, db), min(dl, dr));
        if (m == dt) s = q.x - rr;
        else if (m == dr) s = ew + qa + (q.y - rr);
        else if (m == db) s = ew + 2.0 * qa + eh + (w - rr - q.x);
        else s = 2.0 * ew + 3.0 * qa + eh + (h - rr - q.y);
    }
    return fract(s / max(1.0, P));
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
// along: position for the stripes (rings: the angle; rects: a diagonal
// coordinate in px / 700); sweepPos: the glint's coordinate (rings and frame
// glints: wrapping round; rects: 0–1 across the shape, not wrapping – one glint)
vec3 shade(vec3 N, float phi, float along, float sweepPos) {
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
    if (sweepAmt > 0.0) {
        bool wrap = (mode > 0.5 && mode < 1.5) || mode > 2.5;
        float d = wrap ? abs(fract(sweepPos - sweep + 0.5) - 0.5) : abs(sweepPos - sweep);
        sw = sweepAmt * exp(-d * d / (wrap ? 0.0025 : 0.0016));
    }
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
    float gl = length(g);
    // a zero gradient (the centre line of a bar) has no direction: atan(0, 0) is undefined
    g = gl > 1e-4 ? g / gl : vec2(0.0, -1.0);
    float phi = atan(-g.y, g.x);
    vec2 c = rect.xy + rect.zw * 0.5;
    bool ringMode = mode > 0.5 && mode < 1.5;
    bool frameMode = mode > 2.5;
    // frame glints draw nothing away from the glint
    if (frameMode && sweepAmt <= 0.0) { fragColor = vec4(0.0); return; }
    // rings: angle from the top, clockwise; rects: a continuous diagonal coordinate (no seam)
    float along = ringMode ? fract(atan(p.x - c.x, -(p.y - c.y)) / TAU + 1.0) : (p.x * 0.9 + p.y * 0.45) / 700.0;
    float sweepPos = ringMode ? along
                   : frameMode ? perimeterPos(p)
                   : ((p.x - rect.x) + 0.5 * (p.y - rect.y)) / max(1.0, rect.z + 0.5 * rect.w);
    vec3 col;
    float cov;
    float alphaMul = 1.0;
    if (mode < 1.5 || frameMode) {
        float hw = tube * 0.5;
        float dc = d + hw;
        cov = clamp(hw - abs(dc) + 0.5, 0.0, 1.0);
        // frame glints: a comet along the outline (a short lead ahead of the head,
        // a tail behind it 2.5× as long), dark steel shoulders round it so it
        // reads over the border's own bright stripes too, and a soft light, 2–3 px
        float glintMask = 0.0, shoulder = 0.0, halo = 0.0;
        if (frameMode) {
            float sd = fract(sweepPos - sweep + 0.5) - 0.5;
            float len = max(0.002, sd > 0.0 ? arc : arc * 2.5);
            glintMask = sweepAmt * exp(-sd * sd / (len * len));
            shoulder = sweepAmt * exp(-sd * sd / (4.8 * len * len));
            float off = max(0.0, abs(dc) - hw);
            halo = glintMask * 0.4 * exp(-off * off / 6.0) * (1.0 - cov);
            if (shoulder < 0.004) { fragColor = vec4(0.0); return; }
        }
        if (cov <= 0.0 && halo <= 0.003) { fragColor = vec4(0.0); return; }
        float a = clamp(abs(dc) / hw, 0.0, 1.0);
        float h = sqrt(max(0.0, 1.0 - a * a));
        vec2 n2 = g * sign(dc) * a;
        vec3 N = normalize(vec3(n2.x, -n2.y, h + 0.05));
        col = shade(N, phi, along, sweepPos) * mix(0.55, 1.0, h);
        if (ringMode) {
            float inArc = arc >= 0.999 ? 1.0 : step(along, arc);
            if (ringStyle < 0.5) {
                if (arc < 0.999) col = mix(col * dim, col, inArc);
            } else {
                vec3 arcCol = col;
                if (ringStyle > 1.5) {
                    // solid: the arc in ink, shaded as a tube, a chrome glint at its head
                    float hd = abs(fract(along - arc + 0.5) - 0.5);
                    float head = arc >= 0.999 ? 0.0 : exp(-hd * hd / 0.0018);
                    arcCol = ink.rgb * mix(0.78, 1.0, h) + col * head;
                }
                col = mix(track.rgb, arcCol, inArc);
                alphaMul = mix(track.a, 1.0, inArc);
            }
        }
        if (frameMode) {
            // the tube: dark steel in the shoulders, the chrome glint in the core
            vec3 dark = tint.rgb * (lightOn > 0.5 ? 0.16 : 0.07) * mix(0.7, 1.0, h);
            float core = clamp(glintMask / max(shoulder, 1e-3), 0.0, 1.0);
            float ta = cov * max(glintMask, 0.85 * shoulder) * qt_Opacity, ha = halo * qt_Opacity;
            vec3 hc = tint.rgb * (lightOn > 0.5 ? 0.9 : 1.0);
            fragColor = vec4(mix(dark, col, core) * ta + hc * ha, ta + ha);
            return;
        }
    } else {
        cov = clamp(0.5 - d, 0.0, 1.0);
        if (cov <= 0.0) { fragColor = vec4(0.0); return; }
        float bev = 0.5 * min(rect.z, rect.w);
        float slope = 1.0 - clamp(-d / bev, 0.0, 1.0);
        float hz = sqrt(max(0.03, 1.0 - slope * slope));
        vec3 N = normalize(vec3(g.x * slope, -g.y * slope, hz));
        col = shade(N, phi, along, sweepPos);
        // the unfilled part is the track only (its own alpha), no metal
        if (arc < 0.999) {
            float filled = arc > 0.0 ? step((p.x - rect.x) / rect.z, arc) : 0.0;
            col = mix(track.rgb, col, filled);
            alphaMul = mix(track.a, 1.0, filled);
        }
    }
    float alpha = cov * alphaMul * qt_Opacity;
    fragColor = vec4(col * alpha, alpha);
}
