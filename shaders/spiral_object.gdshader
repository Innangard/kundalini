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
	// Capture world position before twist (for fragment spiral pattern)
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float dist = spirit_distortion * spirit_transition;

	// Geometry twist around object's local Y axis
	// Kicks in after distortion passes 0.3 — surface spirals come first,
	// then the object starts physically warping
	float twist_strength = clamp((dist - 0.3) / 0.7, 0.0, 1.0);
	if (twist_strength > 0.001) {
		// Twist angle depends on height + radial distance for true spiral
		float local_r = length(VERTEX.xz);
		float twist_angle = (VERTEX.y * 2.5 + local_r * 1.5) * twist_strength * 2.0
		                  + spirit_time * twist_strength * 0.4;

		float c = cos(twist_angle);
		float s = sin(twist_angle);
		vec3 twisted;
		twisted.x = VERTEX.x * c - VERTEX.z * s;
		twisted.y = VERTEX.y;
		twisted.z = VERTEX.x * s + VERTEX.z * c;

		VERTEX = mix(VERTEX, twisted, twist_strength);

		// Rotate normal to match the twist
		vec3 tn;
		tn.x = NORMAL.x * c - NORMAL.z * s;
		tn.y = NORMAL.y;
		tn.z = NORMAL.x * s + NORMAL.z * c;
		NORMAL = normalize(mix(NORMAL, tn, twist_strength));
	}
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	EMISSION = emission * emission_energy;

	float dist = spirit_distortion * spirit_transition;
	if (dist > 0.01) {
		float r = length(world_pos.xz);
		float a = atan(world_pos.z, world_pos.x);

		// Same spiral pattern as surface shader
		float spiral1 = sin(a * 3.0 + r * 5.0 - spirit_time * 0.4);
		float line1 = 1.0 - smoothstep(0.0, 0.15, abs(spiral1));

		float spiral2 = sin(-a * 2.0 + r * 4.0 + spirit_time * 0.25);
		float line2 = 1.0 - smoothstep(0.0, 0.2, abs(spiral2));

		float vert = sin(world_pos.y * 8.0 + a * 2.0 - spirit_time * 0.35);
		float line3 = 1.0 - smoothstep(0.0, 0.2, abs(vert));

		float pattern = max(line1 * 0.9, max(line2 * 0.5, line3 * 0.4));

		ALBEDO *= 1.0 - pattern * dist;
	}
}
