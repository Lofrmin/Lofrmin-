shader_type spatial;
render_mode unshaded;

uniform vec4 phosphor : source_color = vec4(0.42, 0.80, 0.78, 1.0);

void fragment() {
	vec2 p = UV;
	vec2 inset = min(p, 1.0 - p);
	float border = smoothstep(0.014, 0.021, min(inset.x, inset.y));
	float graph = exp(-abs(p.y - 0.37 - (0.09 * sin(p.x * 25.0) + 0.04 * sin(p.x * 63.0))) * 90.0);
	graph *= step(0.07, p.x) * step(p.x, 0.67);
	float ticks = step(0.79, p.x) * step(p.x, 0.94) * step(0.85, fract(p.y * 13.0));
	float grid = (step(0.976, fract(p.x * 16.0)) + step(0.96, fract(p.y * 8.0))) * 0.055;
	float scan = exp(-abs(p.y - fract(TIME * 0.25)) * 15.0) * 0.08;
	ALBEDO = vec3(0.010, 0.025, 0.035) + phosphor.rgb * border * (0.10 + graph * 0.74 + ticks * 0.58 + grid + scan);
}
