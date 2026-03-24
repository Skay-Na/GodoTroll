shader_type canvas_item;

// 中心暂留强度：值越大，中心区域相比边缘保留越久
uniform float center_strength : hint_range(0.0, 4.0) = 2.5;

void fragment() {
	// 获取原始像素颜色（包含截图纹理颜色和 modulate.a 混合后的透明度）
	vec4 base = texture(TEXTURE, UV);
	
	// 计算该像素距屏幕中心的距离 (0.0=中心, ~0.7=角落)
	float dist = distance(UV, vec2(0.5, 0.5));
	
	// 当整体 modulate.a 降低时，边缘比中心衰减更快
	// COLOR.a 此时已经是 modulate.a * 原始透明度
	float global_fade = COLOR.a; // 0.0=全透明, 1.0=不透明
	
	// 中心像素乘以一个 boost 系数（中心保留更多）
	float boost = 1.0 - dist * (1.0 - global_fade) * center_strength;
	float final_alpha = global_fade * clamp(boost, 0.0, 1.0);
	
	COLOR = vec4(base.rgb, final_alpha);
}
