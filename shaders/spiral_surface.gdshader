shader_type spatial;

// Driven by player.gd via RenderingServer global shader parameters
global uniform float spirit_distortion;
global uniform float spirit_time;
global uniform float spirit_transition;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	EMISSION = emission * emission_energy;

	float dist = spirit_distortion * spirit_transition;
	if (dist > 0.01) {
		// Polar coordinates from world center
		float r = length(world_pos.xz);
		float a = atan(world_pos.z, world_pos.x);

		// Primary Archimedean spiral arms (3 arms, rotating slowly)
		float spiral1 = sin(a * 3.0 + r * 5.0 - spirit_time * 0.4);
		float line1 = 1.0 - smoothstep(0.0, 0.15, abs(spiral1));

		// Counter-rotating secondary spiral (2 arms, opposite direction)
		float spiral2 = sin(-a * 2.0 + r * 4.0 + spirit_time * 0.25);
		float line2 = 1.0 - smoothstep(0.0, 0.2, abs(spiral2));

		// Vertical dimension ripple tied to angle (creates helical patterns on walls)
		float vert = sin(world_pos.y * 8.0 + a * 2.0 - spirit_time * 0.35);
		float line3 = 1.0 - smoothstep(0.0, 0.2, abs(vert));

		// Combine: primary spirals strongest, secondary and vertical add depth
		float pattern = max(line1 * 0.9, max(line2 * 0.5, line3 * 0.4));

		// Paint dark lines — the Sobel post-process picks these up as edges
		ALBEDO *= 1.0 - pattern * dist;
	}
}
