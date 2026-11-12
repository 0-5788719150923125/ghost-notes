shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// A screen on the dispatch desk (DispatchMedium, DispatchSet): what its 2D face draws, shown as a tube or a panel shows
// it. A CRT's glass bulges (`curve`), its picture has scanlines (`lines`) and a phosphor's soft bloom round what is lit
// (`bloom`), its corners fall off; a black-and-white one is gray (`mono`), a snowy feed has noise (`snow`); a flat panel
// has none of that (`curve` 0, `lines` 0). `power` brings it on and off (a tube's line to a dot as it goes off); `round`
// masks a radar's round scope. Emissive, so the screen lights the dark - the medium's lights carry the rest.

uniform sampler2D face : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_face = true;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 dark : source_color = vec3(0.015, 0.02, 0.018);
uniform float brightness = 1.6;
uniform float curve : hint_range(0.0, 0.3) = 0.12;
uniform float lines : hint_range(0.0, 1.0) = 0.35;
uniform float line_count = 280.0;
uniform float bloom : hint_range(0.0, 2.0) = 0.6;
uniform float mono : hint_range(0.0, 1.0) = 0.0;
uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform float power : hint_range(0.0, 1.0) = 1.0;
uniform float round_mask : hint_range(0.0, 1.0) = 0.0;
uniform float frame = 0.0;
uniform float flicker : hint_range(0.0, 0.2) = 0.02;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	// the glass bulges: the picture drawn in from its corners
	vec2 c = uv * 2.0 - 1.0;
	vec2 bent = c * (1.0 + curve * dot(c, c) * 0.5);
	uv = bent * 0.5 + 0.5;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	// going off: the picture squeezed to a line, then to a dot
	float squeeze_y = clamp(power * 2.0, 0.0, 1.0);
	float squeeze_x = clamp(power * 4.0 - 0.0, 0.02, 1.0);
	vec2 q = (uv - 0.5) / vec2(max(squeeze_x, 0.02), max(squeeze_y, 0.004)) + 0.5;
	float on = step(0.0, q.x) * step(q.x, 1.0) * step(0.0, q.y) * step(q.y, 1.0);
	vec3 col = vec3(0.0);
	if (has_face) {
		col = texture(face, q).rgb;
		if (bloom > 0.0) {
			vec3 soft = textureLod(face, q, 3.0).rgb + textureLod(face, q, 5.0).rgb * 0.6;
			col += soft * bloom * 0.35;
		}
	}
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(g), mono);
	if (snow > 0.0) {
		float n = hash(floor(uv * vec2(320.0, 240.0)) + vec2(frame * 13.1, frame * 7.7));
		col = mix(col, vec3(n), snow);
	}
	// scanlines, and a slow roll of brightness down the tube
	float sl = 0.5 + 0.5 * cos(uv.y * line_count * 6.2831853);
	col *= 1.0 - lines * (1.0 - sl) * 0.75;
	col *= 1.0 - flicker * (0.5 + 0.5 * sin(uv.y * 3.0 - frame * 0.21));
	// its corners fall off
	float vig = smoothstep(1.25, 0.55, length(c * vec2(0.9, 1.0)));
	col *= mix(1.0, vig, min(curve * 6.0, 1.0));
	float dot_on = smoothstep(0.08, 0.0, length((uv - 0.5) * vec2(1.0, 1.4))) * step(power, 0.02) * step(0.001, power);
	col = col * tint * brightness * on * inside * smoothstep(0.0, 0.05, power) + vec3(dot_on);
	if (round_mask > 0.0) {
		float r = length(UV * 2.0 - 1.0);
		col *= mix(1.0, smoothstep(1.0, 0.97, r), round_mask);
	}
	ALBEDO = dark + col;
}
