shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float line_thickness : hint_range(1.0, 5.0) = 1.0;
uniform float edge_threshold : hint_range(0.01, 1.0) = 0.06;
uniform float transition : hint_range(0.0, 1.0) = 0.0;
uniform float distortion : hint_range(0.0, 1.0) = 0.0;
uniform float spirit_time = 0.0;

global uniform vec4 portal_screen_rect;
global uniform float portal_fade;

void fragment() {
	vec2 uv = SCREEN_UV;

	vec3 screen_color = texture(screen_texture, uv).rgb;

	// At high distortion, sample offsets wobble for uneasy wavy lines
	float wobble = distortion * distortion * sin(spirit_time * 4.0 + uv.y * 40.0) * 0.0015;
	vec2 ps = SCREEN_PIXEL_SIZE * line_thickness + vec2(wobble);

	// Sobel edge detection on the warped image
	vec3 tl = texture(screen_texture, uv + vec2(-ps.x, -ps.y)).rgb;
	vec3 tc = texture(screen_texture, uv + vec2(0.0, -ps.y)).rgb;
	vec3 tr = texture(screen_texture, uv + vec2(ps.x, -ps.y)).rgb;
	vec3 ml = texture(screen_texture, uv + vec2(-ps.x, 0.0)).rgb;
	vec3 mr = texture(screen_texture, uv + vec2(ps.x, 0.0)).rgb;
	vec3 bl = texture(screen_texture, uv + vec2(-ps.x, ps.y)).rgb;
	vec3 bc = texture(screen_texture, uv + vec2(0.0, ps.y)).rgb;
	vec3 br = texture(screen_texture, uv + vec2(ps.x, ps.y)).rgb;

	vec3 gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
	vec3 gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;
	float edge = length(gx) + length(gy);

	// Phase 1: desaturate (first 60% of transition)
	float desat = clamp(transition / 0.6, 0.0, 1.0);
	float lum = dot(screen_color, vec3(0.299, 0.587, 0.114));
	vec3 fading = mix(screen_color, vec3(lum), desat);

	// Phase 2: fade to white (starts at 30%, done at 100%)
	float whiten = clamp((transition - 0.3) / 0.7, 0.0, 1.0);
	fading = mix(fading, vec3(1.0), whiten);

	// Portal dimming — bright grey inside the doorway
	if (portal_fade > 0.001) {
		float margin = 0.01;
		float in_x = smoothstep(portal_screen_rect.x - margin, portal_screen_rect.x + margin, uv.x)
		           * (1.0 - smoothstep(portal_screen_rect.z - margin, portal_screen_rect.z + margin, uv.x));
		float in_y = smoothstep(portal_screen_rect.y - margin, portal_screen_rect.y + margin, uv.y)
		           * (1.0 - smoothstep(portal_screen_rect.w - margin, portal_screen_rect.w + margin, uv.y));
		fading *= 1.0 - in_x * in_y * portal_fade * 0.15;
	}

	// Lines emerge gradually
	float dynamic_threshold = mix(0.5, edge_threshold, transition);
	float line_val = smoothstep(dynamic_threshold, dynamic_threshold * 2.0, edge);
	line_val *= transition;

	// Apply black lines over the fading scene
	vec3 final_color = fading * (1.0 - line_val);
	COLOR = vec4(final_color, 1.0);
}
