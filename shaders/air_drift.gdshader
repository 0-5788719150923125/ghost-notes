// WHAT DRIFTS IN THE AIR (src/drifts.gd): a petal, a rose petal, a leaf, a seed's tuft, a maple key or a
// feather - one quad of a MultiMesh, cupped, cut to its outline here, lit by every light on
// the table and glowing where a light is behind it. The quad is the plane mesh's (x across, z along,
// -0.5..0.5, its face +y); a piece's size and turn are its transform's, its color the instance's, and
// INSTANCE_CUSTOM is (how cupped it is, a seed of its own). Cut by `discard`, so its shadow is its shape.
shader_type spatial;
render_mode cull_disabled;

// Drifts.LOOKS' shapes: 0 petal, 1 rose petal, 2 leaf, 3 tuft, 4 key, 5 feather
uniform int shape = 0;
// how much light comes through it (BACKLIGHT, a share of its color)
uniform float through = 0.5;

varying vec2 q;
varying float seed;

void vertex() {
	q = VERTEX.xz * 2.0;
	float curl = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y;
	// CUPPED: its sides lift, its tip a little
	VERTEX.y += curl * 0.22 * (q.x * q.x + 0.35 * q.y * q.y) * 0.25;
	NORMAL = normalize(vec3(-curl * 0.22 * q.x, 1.0, -curl * 0.22 * 0.35 * q.y));
}

float hash1(float n) {
	return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453);
}

void fragment() {
	vec2 p = q;
	float ax = abs(p.x);
	float t = (p.y + 1.0) * 0.5;          // 0 at its base, 1 at its tip
	float round_ = sqrt(max(1.0 - p.y * p.y, 0.0));
	bool keep = false;
	vec3 tint = vec3(1.0);
	if (shape == 0) {
		// A PETAL: narrow at its base, notched at its tip, faint veins fanning from the base
		float hw = round_ * mix(0.42, 1.0, sqrt(t));
		keep = ax < hw && p.y < 0.74 + 1.6 * ax;
		tint = vec3(mix(0.9, 1.04, t)) * (1.0 - 0.05 * smoothstep(0.85, 1.0, sin(atan(p.x, p.y + 1.2) * 34.0)));
	} else if (shape == 1) {
		// A ROSE PETAL: broad, its edge a little wavy, deeper at its base
		float hw = round_ * mix(0.55, 1.08, t) + 0.03 * sin(p.y * 9.0 + seed * 30.0);
		keep = ax < min(hw, 1.0);
		tint = vec3(mix(0.62, 1.0, smoothstep(0.0, 0.55, t)));
	} else if (shape == 2) {
		// A LEAF: pointed, its edge toothed, a midrib and veins, its stalk at its base
		float hw = 0.55 * pow(max(1.0 - p.y * p.y, 0.0), 0.75) * (1.0 + 0.07 * sin(p.y * 30.0 + seed * 20.0));
		keep = ax < hw || (ax < 0.035 && p.y < -0.8);
		float vein = smoothstep(0.92, 1.0, sin((p.y - ax * 0.9) * 26.0));
		tint = vec3(1.0 - 0.28 * step(ax, 0.022) - 0.12 * vein);
		// the edge browns and curls first
		tint *= mix(1.0, 0.78, smoothstep(0.7, 1.0, ax / max(hw, 1e-3)));
	} else if (shape == 3) {
		// A SEED'S TUFT: a dark seed in the middle, fine fluff spread round it
		float r = length(p);
		float a = atan(p.y, p.x);
		float rays = abs(fract(a / 6.2831853 * 18.0 + seed) - 0.5);
		float rim = 0.86 + 0.14 * hash1(floor(a / 6.2831853 * 18.0 + seed));
		keep = r < 0.14 || (r < rim && (r < 0.3 || rays < 0.16 + 0.1 * (1.0 - r)));
		tint = r < 0.14 ? vec3(0.55, 0.47, 0.36) : vec3(1.0);
	} else if (shape == 4) {
		// A MAPLE KEY: its seed at the base, its veined wing reaching to one side
		bool nut = length((p - vec2(0.0, -0.72)) * vec2(1.0, 1.35)) < 0.28;
		float s = clamp((p.y + 0.72) / 1.7, 0.0, 1.0);
		float w = sin(3.14159 * pow(s, 0.7)) * 0.95;
		bool wing = p.y > -0.75 && p.y < 0.98 && p.x > -0.22 + 0.1 * s && p.x < -0.22 + w;
		keep = nut || wing;
		tint = nut ? vec3(0.72) : vec3(1.0 - 0.15 * smoothstep(0.9, 1.0, sin((p.x - p.y * 0.4) * 28.0)));
	} else {
		// A FEATHER: its shaft, and a vane ragged where its barbs part
		float hw = 0.9 * round_ * mix(0.7, 1.0, t);
		float jag = fract(p.y * 13.0 + ax * 4.0 + seed * 9.0);
		keep = ax < 0.03 || (ax < hw * (0.8 + 0.2 * jag) && p.y > -0.9);
		tint = ax < 0.03 ? vec3(0.92) : vec3(1.0 - 0.06 * jag);
	}
	if (!keep) {
		discard;
	}
	vec3 c = COLOR.rgb * tint;
	ALBEDO = c;
	ROUGHNESS = 0.7;
	SPECULAR = 0.25;
	BACKLIGHT = c * through;
}
