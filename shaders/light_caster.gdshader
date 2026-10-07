// A SHADOW OUT OF THE SHOT (src/lights.gd, `shadows`): a part of something that throws its shadow on the
// table and is never seen - a beam, a pillar, a rope, a chandelier's arm, a sheet on a line - drawn into
// nothing but the shadow maps of the lights that cast (the mesh is shadow-only, on Lights.CASTER_LAYER).
// A SHEET RIPPLES as it hangs: its vertices move along its face, more the further they hang from its top
// edge, in waves that run along it - laundry, a flag, a banner. Posed from show time, so a render and a
// scrub see the same ripple. Every other part is still here: it swings or turns whole (Lights.Rig).
shader_type spatial;
render_mode unshaded, cull_disabled;

// how far a sheet's free edge waves (meters; 0 for every part that is not a rippling sheet)
uniform float wave = 0.0;
// its top edge and its height, in its own space (meters): what it hangs from, and how far it falls
uniform float top = 0.5;
uniform float span = 1.0;
uniform float phase = 0.0;
uniform float show_time = 0.0;

void vertex() {
	if (wave > 0.0) {
		float hang = clamp((top - VERTEX.y) / max(span, 0.01), 0.0, 1.0);
		float t = show_time;
		VERTEX.z += wave * hang * (0.65 * sin(VERTEX.x * 6.0 - t * 4.7 + phase)
			+ 0.35 * sin(VERTEX.x * 13.0 + VERTEX.y * 4.0 - t * 7.9 + phase * 1.7));
	}
}

void fragment() {
	ALBEDO = vec3(0.0);
}
