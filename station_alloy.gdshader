shader_type spatial;

uniform vec4 finish : source_color = vec4(0.14, 0.22, 0.31, 1.0);
uniform float grain = 0.14;
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 uv = UV;
	float stipple = fract(sin(dot(floor(uv * vec2(270.0, 450.0)), vec2(15.13, 84.39))) * 28462.13);
	float brush = sin(uv.y * 1600.0) * 0.19 * (1.0 - smoothstep(0.00025, 0.002, fwidth(uv.y)))
		+ sin(uv.y * 94.0) * 0.07 + stipple * 0.39;
	float bevel = smoothstep(0.0, 0.037, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	float seams = smoothstep(0.018, 0.042, abs(fract(local_pos.x * 1.25 + 0.5) - 0.5));
	ALBEDO = finish.rgb * (0.77 + bevel * 0.23 + grain * brush) * (0.85 + seams * 0.15);
	ROUGHNESS = 0.45 + brush * 0.19;
	METALLIC = 0.27;
}
