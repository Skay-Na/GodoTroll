shader_type canvas_item;

// 控制白光从中心向外扩散的半径（0.0=只有中心点，1.5=铺满屏幕）
uniform float radius : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	// 计算当前像素到屏幕中心的距离
	float dist = distance(UV, vec2(0.5, 0.5));
	
	// smoothstep 在 radius 边缘产生一个柔和的过渡边界（让边缘不那么生硬）
	float edge = smoothstep(radius, radius - 0.15, dist);
	
	// 最终颜色：纯白，透明度由扩散范围和节点的 modulate.a 共同决定
	COLOR = vec4(1.0, 1.0, 1.0, edge * COLOR.a);
}
