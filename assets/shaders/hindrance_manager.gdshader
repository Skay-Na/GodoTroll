shader_type canvas_item;
// 抓取当前屏幕的画面
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
// 控制旋转的角度
uniform float rotation_degrees = 0.0;

void fragment() {
    // 找到屏幕中心点
    vec2 center = vec2(0.5, 0.5);
    vec2 uv = SCREEN_UV - center;
    
    // 计算旋转矩阵
    float rad = radians(rotation_degrees);
    float s = sin(rad);
    float c = cos(rad);
    
    vec2 rotated_uv = vec2(
        uv.x * c - uv.y * s,
        uv.x * s + uv.y * c
    );
    
    rotated_uv += center;
    
    // 消除旋转过程中的边缘黑边，超出屏幕的区域直接填黑
    if (rotated_uv.x < 0.0 || rotated_uv.x > 1.0 || rotated_uv.y < 0.0 || rotated_uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        COLOR = texture(screen_texture, rotated_uv);
    }
}
