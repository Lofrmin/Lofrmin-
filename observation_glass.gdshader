shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.36, 0.57, 0.67, 1.0);

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.4);
	vec2 margins = min(UV, 1.0 - UV);
	float gasket = 1.0 - smoothstep(0.004, 0.045, min(margins.x, margins.y));
	float reflection = exp(-abs(UV.y - 0.13 - VIEW.y * 0.22) * 45.0) * (0.45 + 0.55 * sin(UV.x * 3.14));
	ALBEDO = tint.rgb;
	ALPHA = 0.025 + 0.095 * rim + 0.11 * gasket + 0.045 * reflection;
}
