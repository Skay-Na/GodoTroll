shader_type canvas_item;

uniform vec4 chroma_key_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float pickup_range : hint_range(0.0, 1.0) = 0.15;
uniform float fade_range : hint_range(0.0, 1.0) = 0.1;
uniform float spill_suppression : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    float dist = distance(color.rgb, chroma_key_color.rgb);
    
    // 1. 基础透明度
    color.a = smoothstep(pickup_range, pickup_range + fade_range, dist);
    
    // 2. 溢色抑制 (Spill Suppression)
    // 主要是为了去掉人物边缘残留的绿光
    if (dist < pickup_range + fade_range * 2.0) {
        float rb_avg = (color.r + color.b) * 0.5;
        if (color.g > rb_avg) {
            color.g = mix(color.g, rb_avg, spill_suppression);
        }
    }
    
    COLOR = color;
}
