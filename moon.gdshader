shader_type spatial;
render_mode unshaded, fog_disabled;

varying vec3 lunar_normal;
varying vec3 lunar_point;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(cell), hash(cell + vec3(1,0,0)), f.x),
		mix(hash(cell + vec3(0,1,0)), hash(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(cell + vec3(0,0,1)), hash(cell + vec3(1,0,1)), f.x),
		mix(hash(cell + vec3(0,1,1)), hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	lunar_point = normalize(VERTEX);
	lunar_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = normalize(lunar_point);
	float maria = smoothstep(0.37, 0.65, noise(p * 5.0));
	float terrain = 0.46 + 0.30 * maria + 0.07 * noise(p * 65.0);
	for (int i = 0; i < 36; i++) {
		float seed = float(i);
		vec3 center = normalize(vec3(hash(vec3(seed,1,2)), hash(vec3(3,seed,4)), hash(vec3(5,6,seed))) * 2.0 - 1.0);
		float radius = mix(0.025, 0.12, hash(vec3(seed,7,8)));
		float distance_to_crater = length(p - center) / radius;
		terrain -= (1.0 - smoothstep(0.65, 0.9, distance_to_crater)) * 0.12;
		terrain += exp(-pow((distance_to_crater - 0.95) * 9.0, 2.0)) * 0.14;
	}
	float daylight = smoothstep(-0.08, 0.95, dot(normalize(lunar_normal), normalize(vec3(-0.52, 0.58, 0.62))));
	ALBEDO = vec3(0.83, 0.82, 0.79) * terrain * (0.025 + 1.05 * daylight);
}
