// REDACTED WORDS ON THE DISPATCH DESK'S TERMINAL (src/dispatch/dispatch_screens.gd, `Mosaic`): each rect drawn
// is filled with flat hexagons, each the average color of the terminal's pixels under it, as a video hides a name
// (2026-11-09, the user: "that sort of hexagonal approach, which segments a region into large hexagonal shapes, and
// makes those shapes use single-colors, matching the pixels we just blurred"). The terminal is drawn first, so the
// screen texture holds the words as written; nothing else of them reaches the glass.
//
// THE LATTICE is pointy-top hexagons laid from each rect's left edge, about its middle: a run typed a key at a time
// grows by hexagons, and the ones already there keep their place and their color. A hexagon at a rect's edge is cut by
// it, and averages only what lies inside - the dots before a name never bleed into it.
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
// each rect, in the terminal's pixels: x0, y0, x1, y1 (DispatchScreens.MOSAIC_MOST of them)
uniform vec4 rects[32];
uniform int count = 0;
// a hexagon's circumradius (px)
uniform float cell = 16.5;

// a hexagon's average is read off this many taps on a side, over its bounds
const int TAPS = 12;
const float HALF_W = 0.8660254;

varying vec2 pos;

void vertex() {
	pos = VERTEX;
}

// The center of the hexagon that holds [p] (relative to the lattice's origin): axial coordinates, rounded in cube space.
vec2 hex_center(vec2 p, float s) {
	float q = (0.57735027 * p.x - p.y / 3.0) / s;
	float r = (0.66666667 * p.y) / s;
	vec3 cube = vec3(q, -q - r, r);
	vec3 rc = round(cube);
	vec3 d = abs(rc - cube);
	if (d.x > d.y && d.x > d.z) {
		rc.x = -rc.y - rc.z;
	} else if (d.y > d.z) {
		rc.y = -rc.x - rc.z;
	} else {
		rc.z = -rc.x - rc.y;
	}
	return vec2(s * (1.7320508 * rc.x + HALF_W * rc.z), s * 1.5 * rc.z);
}

// Is [d] (from a hexagon's center) inside it?
bool in_hex(vec2 d, float s) {
	vec2 a = abs(d);
	return a.x <= HALF_W * s && a.y <= s - a.x * 0.57735027;
}

void fragment() {
	// the rect this fragment is in (one past the array: the hexagon alone bounds it)
	vec4 box = vec4(-1e6, -1e6, 1e6, 1e6);
	vec2 origin = vec2(0.0);
	for (int i = 0; i < 32; i++) {
		if (i >= count) {
			break;
		}
		vec4 q = rects[i];
		if (pos.x >= q.x && pos.y >= q.y && pos.x <= q.z && pos.y <= q.w) {
			box = q;
			origin = vec2(q.x + HALF_W * cell, 0.5 * (q.y + q.w));
			break;
		}
	}
	vec2 c = origin + hex_center(pos - origin, cell);
	vec3 sum = vec3(0.0);
	float n = 0.0;
	for (int j = 0; j < TAPS; j++) {
		for (int i = 0; i < TAPS; i++) {
			vec2 d = (vec2(float(i), float(j)) + 0.5) / float(TAPS) * 2.0 - 1.0;
			d *= vec2(HALF_W * cell, cell);
			vec2 p = c + d;
			if (!in_hex(d, cell) || p.x < box.x || p.y < box.y || p.x > box.z || p.y > box.w) {
				continue;
			}
			sum += texture(screen, p * SCREEN_PIXEL_SIZE).rgb;
			n += 1.0;
		}
	}
	COLOR = vec4(n > 0.0 ? sum / n : texture(screen, SCREEN_UV).rgb, 1.0);
}
