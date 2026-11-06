shader_type spatial;

uniform vec4 finish_color : source_color;
uniform float finish_roughness = 0.5;
uniform float finish_metal = 0.6;
varying vec3 material_seed;

float grain_hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.11369, 0.13787));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	material_seed = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec2 panel = fract(UV * vec2(3.0, 2.0));
	vec2 margins = min(panel, 1.0 - panel);
	float rim = smoothstep(0.005, 0.061, min(margins.x, margins.y));
	float seed = grain_hash(material_seed * 0.76 + 0.24);
	float striations = sin(UV.y * 530.0 + seed * 17.0) * (1.0 - smoothstep(0.001, 0.009, fwidth(UV.y)));
	float spots = grain_hash(vec3(floor(UV * 122.0), seed));
	float shade = 0.78 + seed * 0.17 + spots * 0.06 + rim * 0.09 + striations * 0.023;
	ALBEDO = finish_color.rgb * shade;
	ROUGHNESS = clamp(finish_roughness + (spots - 0.5) * 0.16, 0.12, 0.96);
	METALLIC = finish_metal;
}
