// WHAT THE SUN FALLS THROUGH (src/lights.gd): a wall with a window, blinds or a pierced screen in it,
// or leaves, fronds, branches, slats, an awning or a parasol overhead - drawn into nothing but the
// sun's shadow map (the mesh is shadow-only, on Lights.SCREEN_LAYER): where a fragment is kept the
// sun is held back, where one is discarded it gets through. Posed from show time - leaves stir, an
// awning's edge ripples - so a render and a scrub see the same light. Its coordinates are the quad's
// own, meters, from where the sun's ray through the screen's `at` crosses it.
//
// EVERY PATTERN HERE IS Lights._pattern() TOO, line for line: the set dresser is told how much of the
// table the sun reaches from the CPU's reckoning, and this is what is drawn.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/light_noise.gdshaderinc"

// Lights.SCREENS' codes: 0 window, 1 blinds, 2 lattice, 3 leaves, 4 fronds, 5 branches, 6 slats,
// 7 awning, 8 parasol
uniform int kind = 0;
uniform vec2 opening = vec2(1.1, 1.4);   // a wall's opening, meters
uniform vec2 panes = vec2(2.0, 3.0);
uniform float bars = 0.04;               // the frame's and the bars' width, meters
uniform float spacing = 0.06;            // blinds and slats apart, meters
uniform float open = 0.5;                // the share of that a gap
uniform float turn = 0.0;                // radians
uniform int lattice = 0;                 // Lights.LATTICES, in order
uniform float cell = 0.1;
uniform float thr = 0.5;                 // leaves, fronds, branches: shade above this
uniform float size = 0.12;
uniform float sway = 0.3;
uniform float edge = 0.0;                // an awning's edge, along its own y
uniform float scallop = 0.0;             // ...a scallop's width (0: a straight edge)
uniform float radius = 1.1;              // a parasol's
uniform float ribs = 8.0;
uniform uint salt = 0u;
uniform float show_time = 0.0;
// a soft screen's copy: its shade grown (or, below 0, shrunk) by this - meters for an edge or a bar,
// noise levels for a canopy, the share of a gap for blinds and slats (Lights.grow_of)
uniform float grow = 0.0;
// how hard the wind gusts now, 0-1: what stirs, stirs harder
uniform float gust = 0.0;

varying vec2 plane;

void vertex() {
	plane = VERTEX.xy;
}

// [param p] in a frame turned [param a] radians
vec2 turned(vec2 p, float a) {
	return vec2(cos(a) * p.x + sin(a) * p.y, -sin(a) * p.x + cos(a) * p.y);
}

// how far a canopy has moved at [param q], [param t]: all of it swings slowly, each part flutters
vec2 stir(vec2 q, float t) {
	vec2 swing = vec2(sin(0.53 * t + 1.3) + 0.5 * sin(1.37 * t + 0.4), sin(0.41 * t + 0.2) + 0.5 * sin(1.13 * t + 2.1));
	vec2 flutter = vec2(lnoise(q / size * 1.7 + vec2(t * 0.9, 0.0), salt + 7u),
		lnoise(q / size * 1.7 + vec2(0.0, t * 0.8), salt + 11u)) - 0.5;
	return sway * size * (0.22 * swing + 0.45 * flutter) * (1.0 + 1.5 * gust);
}

bool lattice_bar(vec2 q) {
	if (lattice == 1) {
		q = turned(q, 0.78539816);
	}
	if (lattice <= 1) {
		vec2 m = q - cell * floor(q / cell);
		vec2 d = min(m, vec2(cell) - m);
		return min(d.x, d.y) < bars * 0.5 + grow;
	}
	if (lattice == 2) {
		vec2 s = vec2(1.0, 1.7320508) * cell;
		vec2 a = q - s * floor(q / s + 0.5);
		vec2 b = (q - s * 0.5) - s * floor((q - s * 0.5) / s + 0.5);
		vec2 g = abs(dot(a, a) < dot(b, b) ? a : b);
		return max(g.x, dot(g, vec2(0.5, 0.8660254))) > cell * 0.5 - bars * 0.5 - grow;
	}
	vec2 m = q - cell * (floor(q / cell) + 0.5);
	if (lattice == 3) {
		return length(m) > cell * 0.5 - bars * 0.5 - grow;
	}
	float sq = max(abs(m.x), abs(m.y));
	float di = (abs(m.x) + abs(m.y)) * 0.70710678;
	return min(sq, di) > (cell * 0.5 - bars) * 0.82 - grow;
}

bool shaded(vec2 q, float t) {
	float gusting = 1.0 + 1.5 * gust;
	if (kind <= 2) {
		if (abs(q.x) > opening.x * 0.5 || abs(q.y) > opening.y * 0.5) {
			return true;
		}
		if (min(opening.x * 0.5 - abs(q.x), opening.y * 0.5 - abs(q.y)) < bars * 0.5 + grow) {
			return true;
		}
		if (kind == 0) {
			vec2 r = q + opening * 0.5;
			vec2 c = opening / max(panes, vec2(1.0));
			vec2 m = r - c * floor(r / c);
			vec2 d = min(m, c - m);
			return min(d.x, d.y) < bars * 0.5 + grow;
		}
		if (kind == 1) {
			vec2 r = turned(q, turn);
			float y = r.y + sway * gusting * spacing * 0.15 * sin(0.9 * t + r.x * 2.0);
			return fract(y / spacing) >= open - grow;
		}
		return lattice_bar(q);
	}
	if (kind == 3) {
		return lfbm((q + stir(q, t)) / size, salt) > thr - grow;
	}
	if (kind == 4) {
		vec2 p = q + stir(q, t);
		float best = 0.0;
		for (int k = 0; k < 3; k++) {
			vec2 r = turned(p, float(k) * 1.0471976 + 0.4);
			best = max(best, lfbm(vec2(r.x / (size * 3.0), r.y / (size * 0.6)), salt + uint(k) * 77u));
		}
		return best > thr - grow;
	}
	if (kind == 5) {
		return 1.0 - abs(2.0 * lfbm((q + stir(q, t) * 0.4) / size, salt) - 1.0) > thr - grow;
	}
	if (kind == 6) {
		return fract(turned(q, turn).y / spacing) >= open - grow;
	}
	if (kind == 7) {
		float e = edge + sway * gusting * 0.012 * sin(2.3 * t + q.x * 4.0) - grow;
		if (scallop > 0.0) {
			float u = (q.x - scallop * floor(q.x / scallop)) / scallop * 2.0 - 1.0;
			e -= scallop * 0.35 * sqrt(max(1.0 - u * u, 0.0));
		}
		return q.y > e;
	}
	float a = atan(q.y, q.x);
	float sector = 6.2831853 / ribs;
	float local = a - sector * (floor(a / sector) + 0.5);
	float r = radius * cos(sector * 0.5) / cos(local);
	r -= radius * 0.04 * cos(local / (sector * 0.5) * 1.5707963);
	r += sway * gusting * 0.01 * sin(1.7 * t + a * 3.0);
	return length(q) < r + grow;
}

void fragment() {
	if (!shaded(plane, show_time)) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
