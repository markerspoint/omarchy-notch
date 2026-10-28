#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 screenSize;
    vec2 scenePosition;
    vec2 imageSize;
    vec2 lightPosition;
    float bottomRadius;
} ubuf;
layout(binding = 1) uniform sampler2D wallpaperTex;

float outline(vec2 p) {
    float radius = p.y > ubuf.resolution.y * 0.5 ? ubuf.bottomRadius : 0.0;
    radius = min(radius, min(ubuf.resolution.x, ubuf.resolution.y) * 0.5);
    vec2 q = abs(p - ubuf.resolution * 0.5) - ubuf.resolution * 0.5 + radius;
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

vec2 wallpaperUV(vec2 position) {
    vec2 image = max(ubuf.imageSize, vec2(1.0));
    float cover = max(ubuf.screenSize.x / image.x, ubuf.screenSize.y / image.y);
    return clamp((position - ubuf.screenSize * 0.5) / (image * cover) + 0.5, 0.001, 0.999);
}

vec3 frosted(vec2 position) {
    vec3 color = texture(wallpaperTex, wallpaperUV(position)).rgb * 0.40;
    color += texture(wallpaperTex, wallpaperUV(position + vec2(5.0, 0.0))).rgb * 0.15;
    color += texture(wallpaperTex, wallpaperUV(position - vec2(5.0, 0.0))).rgb * 0.15;
    color += texture(wallpaperTex, wallpaperUV(position + vec2(0.0, 5.0))).rgb * 0.15;
    color += texture(wallpaperTex, wallpaperUV(position - vec2(0.0, 5.0))).rgb * 0.15;
    return color;
}

void main() {
    vec2 p = qt_TexCoord0 * ubuf.resolution;
    float distance = outline(p);
    float coverage = 1.0 - smoothstep(-0.8, 0.5, distance);
    float depth = max(-distance, 0.0);
    // Fade the material into the bar: never draw a horizontal top border.
    float join = smoothstep(0.0, 18.0, p.y);
    float rim = exp(-depth / 11.0) * join;
    vec2 gradient = vec2(outline(p + vec2(0.7, 0.0)) - outline(p - vec2(0.7, 0.0)),
                         outline(p + vec2(0.0, 0.7)) - outline(p - vec2(0.0, 0.7)));
    vec2 normal = gradient / max(length(gradient), 0.001);
    // An optical inward displacement that increases near the glass perimeter.
    vec2 refracted = ubuf.scenePosition + p - normal * rim * 14.0;
    vec3 backdrop = frosted(refracted);
    float alpha = rim * 0.48;
    vec3 result = backdrop * alpha;

    vec2 direction = normalize((ubuf.lightPosition - 0.5) * 2.0 + vec2(0.01));
    float facing = pow(max(dot(normal, direction), 0.0), 2.0);
    float edge = exp(-depth / 0.95) * join;
    float highlight = edge * (0.12 + 0.55 * facing);
    // Broad, low-contrast sheen provides depth without washing out the content.
    float sheen = 0.045 * pow(1.0 - qt_TexCoord0.y, 2.0)
        * exp(-abs(qt_TexCoord0.x - ubuf.lightPosition.x) * 2.0) * join;
    float reflection = clamp(highlight + sheen, 0.0, 0.7);
    result = vec3(reflection) + result * (1.0 - reflection);
    alpha = reflection + alpha * (1.0 - reflection);
    fragColor = vec4(result, alpha) * coverage * ubuf.qt_Opacity;
}
