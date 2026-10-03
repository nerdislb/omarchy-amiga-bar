#version 440
// One part of the halo under a Lavur sheet (InkSheet): a rounded rectangle
// blurred with a Gaussian of σ px, computed in one pass from its signed
// distance – exact along the straight edges, close at the corners – instead
// of blurring a layer (frame round 03.10.2026, recommendation 6).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // this item's size, px
    vec4 box;       // the rectangle: x, y, w, h, px
    float radius;   // its corner radius, px
    float sigma;    // σ of the blur, px
    vec4 tint;      // colour (alpha ignored)
    float alpha;    // its alpha
};

// the normal distribution's CDF (tanh approximation, error < 0.001)
float phi(float x) {
    float t = clamp(0.7978845608 * (x + 0.044715 * x * x * x), -15.0, 15.0);
    return 1.0 - 1.0 / (exp(2.0 * t) + 1.0);
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 half_ = 0.5 * box.zw;
    float r = min(radius, min(half_.x, half_.y));
    vec2 q = abs(p - (box.xy + half_)) - half_ + r;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;    // < 0 inside
    float a = (box.z > 0.0 && box.w > 0.0 ? phi(-d / max(sigma, 0.001)) : 0.0) * alpha * qt_Opacity;
    fragColor = vec4(tint.rgb * a, a);
}
