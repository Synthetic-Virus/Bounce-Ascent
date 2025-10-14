shader_type canvas_item;

// CRT effect parameters
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_count : hint_range(100.0, 1000.0) = 400.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.002;
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.02;

// Random function for noise
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;

    // Chromatic aberration
    float r = texture(TEXTURE, uv + vec2(chromatic_aberration, 0.0)).r;
    float g = texture(TEXTURE, uv).g;
    float b = texture(TEXTURE, uv - vec2(chromatic_aberration, 0.0)).b;
    vec4 color = vec4(r, g, b, 1.0);

    // Scanlines
    float scanline = sin(uv.y * scanline_count) * scanline_intensity;
    color.rgb -= scanline;

    // Vignette
    vec2 center = uv - vec2(0.5);
    float vignette = 1.0 - dot(center, center) * vignette_intensity * 2.0;
    color.rgb *= vignette;

    // Noise
    float noise = random(uv + TIME * 0.1) * noise_intensity;
    color.rgb += noise;

    COLOR = color;
}
