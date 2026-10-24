#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// 最後の一手の着地点から、盤の線と光を短く波打たせる。
[[ stitchable ]] half4 mateRipple(float2 position, SwiftUI::Layer layer, float2 origin, float time) {
    float2 delta = position - origin;
    float distance = length(delta);
    float local = time - distance / 850.0;
    if (local <= 0.0 || time > 0.9) return layer.sample(position);
    float envelope = exp(-local * 12.0) * (1.0 - smoothstep(0.55, 0.9, time));
    float wave = sin(local * 46.0) * envelope;
    float2 direction = delta / max(distance, 1.0);
    half4 color = layer.sample(position + direction * wave * 12.0);
    color.rgb += half3(0.12, 0.09, 0.025) * half(abs(wave)) * color.a;
    return color;
}
