shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 10.0) = 3.0;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 color = vec4(0.0);
    
    float pixel_size = blur_amount * 0.002;
    
    // 5x5 高斯采样
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            float weight = 1.0 / (1.0 + float(x*x + y*y));
            vec2 offset = vec2(float(x), float(y)) * pixel_size;
            color += texture(screen_texture, uv + offset) * weight;
        }
    }
    
    color = color / 25.0;
    color.a = 1.0;
    
    COLOR = color;
}
