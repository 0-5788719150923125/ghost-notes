// A BIRD'S SHADOW (src/lights.gd): a bird's silhouette, its wings spread or beating, drawn into nothing
// but the sun's shadow map (the mesh is shadow-only, on Lights.SCREEN_LAYER) - a quad lying level, as
// a bird flies, so the shade it throws on the level table has its true shape. Lights.Rig poses the quad
// from show time; here the wings are drawn at their beat and the shape is smeared a little along the
// way it flies, as a shutter would (a binary caster cannot blur: the smear is a short streak). A
// material of its own per bird (plain uniforms: Godot's dummy renderer, which the gates run on, cannot
// keep instance uniforms).
// Coordinates are the quad's own, meters: x across the wings, y the way it flies.
shader_type spatial;
render_mode unshaded, cull_disabled;

// wingtip to wingtip, meters
uniform float span = 1.0;
// 0 wings spread level, 1 at the bottom of a beat (seen from above, nearly folded away)
uniform float beat = 0.0;
// Lights.BIRDS' `shape`: 0 long narrow wings (a gull, a pigeon), 1 broad and fingered (a crow, a hawk,
// a heron), 2 swept back (a swallow, a swift), 3 a bat's
uniform float shape = 0.0;
// meters flown over the shutter
uniform float smear = 0.0;

varying vec2 plane;

void vertex() {
	plane = VERTEX.xy;
}

bool wing(vec2 p, int kind) {
	float half_span = span * 0.5 * (0.32 + 0.68 * cos(beat * 1.35));
	float x = abs(p.x);
	if (x > half_span) {
		return false;
	}
	float s = x / half_span;
	float lead = 0.0;
	float chord = 0.0;
	if (kind == 0) {
		lead = span * (0.05 - 0.07 * s * s);
		chord = span * 0.16 * (1.0 - 0.55 * s) * sqrt(max(1.0 - pow(s, 6.0), 0.0));
	} else if (kind == 1) {
		lead = span * (0.06 - 0.03 * s);
		chord = span * 0.24 * (1.0 - 0.25 * s) * sqrt(max(1.0 - pow(s, 8.0), 0.0));
		// the primaries spread at the tip like fingers
		if (s > 0.78 && fract((p.y - lead) / (span * 0.035)) < 0.35) {
			return false;
		}
	} else if (kind == 2) {
		lead = span * (0.06 - 0.32 * s);
		chord = span * 0.13 * (1.0 - 0.85 * s);
	} else {
		lead = span * (0.05 - 0.04 * s);
		chord = span * 0.26 * (1.0 - 0.3 * s) * (0.75 + 0.25 * abs(sin(s * 9.42)));
	}
	return p.y <= lead && p.y >= lead - chord;
}

bool bird(vec2 p) {
	int kind = int(shape + 0.5);
	// the body, the head forward of it
	vec2 b = p / (span * vec2(0.05, 0.19));
	if (dot(b, b) < 1.0) {
		return true;
	}
	vec2 h = (p - vec2(0.0, span * 0.19)) / (span * vec2(0.035, 0.05));
	if (kind != 3 && dot(h, h) < 1.0) {
		return true;
	}
	// the tail: a fan behind it, forked for a swallow
	float back = -p.y - span * 0.14;
	if (kind != 3 && back > 0.0 && back < span * 0.12) {
		float w = span * (0.03 + 0.25 * back / span);
		if (kind == 2) {
			return abs(abs(p.x) - back * 0.45) < span * 0.012;
		}
		if (abs(p.x) < w) {
			return true;
		}
	}
	return wing(p, kind);
}

void fragment() {
	bool hit = false;
	for (int k = 0; k < 4; k++) {
		hit = hit || bird(plane + vec2(0.0, smear * float(k) / 3.0));
	}
	if (!hit) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
