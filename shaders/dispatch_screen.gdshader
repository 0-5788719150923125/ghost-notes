shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// A screen on the dispatch desk (DispatchMedium, DispatchSet): what its 2D face draws, shown as a tube or a panel shows
// it. A CRT's glass bulges (`curve`), its picture has scanlines (`lines`) and a phosphor's soft bloom round what is lit
// (`bloom`), its corners fall off; a black-and-white one is gray (`mono`), a snowy feed has noise (`snow`); a flat panel
// has none of that (`curve` 0, `lines` 0). `power` brings it on and off: going off, a tube's picture snaps flat to a bright
// line, the line pulls in to a dot and the dot fades; a round scope only fades to its dot; a panel dims. Coming on (`rising`)
// is never that backward: a tube's picture warms up whole, dim and soft, sharpening as it brightens; a panel brightens. A
// caller ramps `power` steadily (no flicker), or the collapse strobes. `round` masks a radar's round scope. Emissive, so the
// screen lights the dark - the medium's lights carry the rest.

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
// Whether `power` is coming up: the warm-up, never the collapse.
uniform bool rising = false;
uniform float round_mask : hint_range(0.0, 1.0) = 0.0;
uniform float frame = 0.0;
uniform float flicker : hint_range(0.0, 0.2) = 0.02;

// Going off, by `power` from 1 down: the picture whole, then flattened to a line between COLLAPSE_V and COLLAPSE_H, the line
// pulled in to a dot between COLLAPSE_H and COLLAPSE_DOT, the dot fading below it. LINE_H and DOT_W are the line's height and
// the dot's width (UV).
const float COLLAPSE_V = 0.62;
const float COLLAPSE_H = 0.34;
const float COLLAPSE_DOT = 0.12;
const float LINE_H = 0.006;
const float DOT_W = 0.02;

// Snow's noise: no sin() (a GPU's loses all precision once its argument is large, which a long show's frame count makes it),
// and the frame wrapped so the cell offset stays small.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	// the glass bulges: the picture drawn in from its corners
	vec2 c = uv * 2.0 - 1.0;
	vec2 bent = c * (1.0 + curve * dot(c, c) * 0.5);
	uv = bent * 0.5 + 0.5;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	// going off: a raster tube's picture flattened to a line (slow, then fast: it lands as a snap), then the line pulled in to a dot
	float tube = step(0.001, curve + lines);
	float going = rising ? 0.0 : 1.0;
	float raster = tube * step(round_mask, 0.5) * going;
	float sv = clamp((power - COLLAPSE_V * raster) / max(1.0 - COLLAPSE_V * raster, 0.001), 0.0, 1.0);
	float sh = clamp((power - COLLAPSE_DOT) / (COLLAPSE_H - COLLAPSE_DOT), 0.0, 1.0);
	float h = mix(1.0, max(sv * (2.0 - sv), LINE_H), raster);
	float w = mix(1.0, max(sh * (2.0 - sh), DOT_W), raster * step(power, COLLAPSE_H));
	vec2 q = (uv - 0.5) / vec2(w, h) + 0.5;
	float edge = 0.004;
	float on = (1.0 - smoothstep(0.5 * w, 0.5 * w + edge, abs(uv.x - 0.5)))
		* (1.0 - smoothstep(0.5 * h, 0.5 * h + edge, abs(uv.y - 0.5)));
	// what is flattened is the beam's whole energy on less glass: brighter, and toward the phosphor's own white as it thins
	float flat_share = raster * (1.0 - smoothstep(LINE_H, 0.2, h));
	vec3 col = vec3(0.0);
	// warming up, a tube's beam is out of focus until its picture is nearly whole
	float soft_lod = tube * (1.0 - going) * 4.0 * (1.0 - smoothstep(0.2, 0.9, power));
	if (has_face) {
		col = soft_lod > 0.01 ? textureLod(face, q, soft_lod).rgb : texture(face, q).rgb;
		if (bloom > 0.0) {
			vec3 soft = textureLod(face, q, 3.0).rgb + textureLod(face, q, 5.0).rgb * 0.6;
			col += soft * bloom * 0.35;
		}
	}
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(g), mono);
	if (snow > 0.0) {
		float f = mod(frame, 1024.0);
		float n = hash(floor(uv * vec2(320.0, 240.0)) + vec2(f * 13.1, f * 7.7));
		col = mix(col, vec3(n), snow);
	}
	// scanlines, and a slow roll of brightness down the tube
	float sl = 0.5 + 0.5 * cos(uv.y * line_count * 6.2831853);
	col *= 1.0 - lines * (1.0 - sl) * 0.75 * (1.0 - flat_share);
	col *= 1.0 - flicker * (0.5 + 0.5 * sin(uv.y * 3.0 - frame * 0.21));
	// its corners fall off
	float vig = smoothstep(1.25, 0.55, length(c * vec2(0.9, 1.0)));
	col *= mix(1.0, vig, min(curve * 6.0, 1.0));
	col = mix(col, vec3(0.85), flat_share);
	col *= 1.0 + 1.5 * flat_share;
	// a tube's afterglow: a dot at the middle that fades as the last of the power goes; a panel simply dims
	float fade = mix(smoothstep(0.0, 0.3, power), step(COLLAPSE_DOT, power), raster);
	// a tube warming up: dark at first, then swelling to its whole brightness
	fade = mix(fade, power * power * (3.0 - 2.0 * power), tube * (1.0 - going));
	float d = length((uv - 0.5) * vec2(1.0, 1.4));
	float last = clamp(power / COLLAPSE_DOT, 0.0, 1.0);
	float dot_on = tube * going * step(power, COLLAPSE_DOT) * step(0.001, power) * last * exp(-pow(d / (0.006 + 0.012 * last), 2.0)) * 2.5;
	vec3 hot = mix(tint, vec3(1.0), 0.5) * brightness;
	col = col * tint * brightness * on * inside * fade + hot * dot_on;
	if (round_mask > 0.0) {
		float r = length(UV * 2.0 - 1.0);
		col *= mix(1.0, smoothstep(1.0, 0.97, r), round_mask);
	}
	ALBEDO = dark + col;
}
