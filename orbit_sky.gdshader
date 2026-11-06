shader_type sky;

float hash3(vec3 cell) {
	cell = fract(cell * vec3(0.1031, 0.11369, 0.13787));
	cell += dot(cell, cell.yzx + 19.19);
	return fract((cell.x + cell.y) * cell.z);
}

float stars(vec3 direction, float scale, float density) {
	vec3 sample_point = direction * scale;
	vec3 cell = floor(sample_point);
	float seed = hash3(cell);
	float core = 1.0 - smoothstep(0.06, 0.42, length(fract(sample_point) - 0.5));
	return step(density, seed) * core * pow(hash3(cell + 37.0), 1.9);
}

void sky() {
	vec3 ray = normalize(EYEDIR);
	float galactic_latitude = dot(ray, normalize(vec3(0.27, 0.92, 0.38)));
	float band = exp(-abs(galactic_latitude) * 9.8);
	float dust = sin(ray.x * 24.0 + cos(ray.z * 11.0) * 3.0) * sin(ray.y * 31.0 + ray.z * 9.0);
	vec3 space = vec3(0.001, 0.002, 0.005) + vec3(0.008, 0.013, 0.024) * band * (0.6 + dust * 0.19);
	space += stars(ray, 340.0, 0.988) * vec3(0.62, 0.68, 0.73);
	space += stars(ray + 0.17, 170.0, 0.994) * vec3(0.84, 0.73, 0.65);
	COLOR = space;
}
