shader_type spatial;

// Driven by player.gd via RenderingServer global shader parameters
global uniform float spirit_distortion;
global uniform float spirit_time;
global uniform float spirit_transition;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float portal_strength : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;
varying vec3 local_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = VERTEX;
}

void fragment() {
	ALBEDO = albedo_color.rgb;

	float dist = spirit_distortion * spirit_transition;
	if (dist > 0.01) {
		// Identical spiral pattern to spiral_surface.gdshader
		float r = length(world_pos.xz);
		float a = atan(world_pos.z, world_pos.x);

		float spiral1 = sin(a * 3.0 + r * 5.0 - spirit_time * 0.4);
		float line1 = 1.0 - smoothstep(0.0, 0.15, abs(spiral1));

		float spiral2 = sin(-a * 2.0 + r * 4.0 + spirit_time * 0.25);
		float line2 = 1.0 - smoothstep(0.0, 0.2, abs(spiral2));

		float vert = sin(world_pos.y * 8.0 + a * 2.0 - spirit_time * 0.35);
		float line3 = 1.0 - smoothstep(0.0, 0.2, abs(vert));

		float pattern = max(line1 * 0.9, max(line2 * 0.5, line3 * 0.4));
		ALBEDO *= 1.0 - pattern * dist;
	}

	// Door frame + doorknob overlay — dark lines the Sobel picks up as edges
	if (portal_strength > 0.01) {
		// Door rectangle in local YZ (mesh is 0.25 x 3 x 1.75)
		// Y: -1.5 (floor) to 0.7 (2.2 m high), Z: -0.5 to 0.5 (1 m wide)
		vec2 door_center = vec2(0.0, -0.4);
		vec2 door_half   = vec2(0.5, 1.1);

		vec2 p = vec2(local_pos.z, local_pos.y) - door_center;
		vec2 d = abs(p) - door_half;

		// Signed distance to rectangle boundary
		float rect_dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);

		// Frame: thin dark line on the outline
		float frame = 1.0 - smoothstep(0.0, 0.05, abs(rect_dist));

		// Suppress bottom edge (it sits right on the floor line)
		frame *= smoothstep(-1.52, -1.4, local_pos.y);

		// Circular doorknob on the right side
		vec2 knob_pos = vec2(0.35, -0.6);
		float knob = 1.0 - smoothstep(0.04, 0.07,
		    length(vec2(local_pos.z, local_pos.y) - knob_pos));

		float door_overlay = max(frame, knob) * portal_strength;
		ALBEDO *= 1.0 - door_overlay * 0.7;
	}
}
