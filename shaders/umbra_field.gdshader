shader_type canvas_item;
// blend_disabled: this writes a field, not a picture - every channel is raw state, and the default blend_mix would
// multiply the color channels by the guard alpha on write and mix in garbage from the never-cleared buffer.
render_mode blend_disabled;

// Umbra's persistent shadow-mass field - the amorphous black body of the ghost that stands beside her and moves her.
// Runs in a ping-pong SubViewport pair (see MaskEditor._step_umbra_sim); mask_split.gdshader samples the result as
// u_umbra_field.
//
// Channels: R = mass density, G = rising essence (the smoke/flame trails), B = the ghost's eyes, A = the guard: where
// the mass is permitted to be drawn at all.
//
// A persistent field, not a drawn shape: the silhouette arrives at 12 Hz on a 96x54 grid, so a shape drawn straight from
// it would step at the sample rate and show its cells. The field only deposits into the thrown silhouette and then
// advects on its own, so the track's discreteness becomes a current rather than a twitch (as in the clown's liquid
// paint). The mass advects with an upward velocity that scales with its own density (buoyancy), so wisps tear off the
// top and rise, thinning as they climb.

uniform sampler2D u_prev : hint_default_black;
// Her silhouette at grid resolution, straight from the pose track (see MaskEditor._pt_upload_mask):
//   R = the person mask - the ghost's body, sampled through the cast transform
//   B = the same mask, dilated - the guard, sampled at plain screen uv
uniform sampler2D u_region : hint_default_black;
uniform float u_dt = 0.016;        // playback seconds advanced this step
uniform int u_reset = 0;           // 1 = snap the field to its targets (seek/first frame)
uniform float u_time = 0.0;
uniform float u_aspect = 1.7778;
// The cast direction, aspect-corrected and unit length: measured once over the whole clip by the pose pre-pass and
// biased upward by the editor. A property of the room, not of the frame.
uniform vec2 u_dir = vec2(1.0, 0.0);
// The cast transform, solved on the CPU (MaskEditor._umb_solve_cast) and handed over already inverted, because a
// fragment asks what content lands here. It is a similarity pinned by two point pairs - her shoulder line to the ghost's
// anchor, her eye line to the ghost's head - so the head is wherever it was placed at any size (a scale about a pivot
// would walk it off the frame).
//
// All four are in aspect-corrected space (x multiplied by u_aspect): each is a distance between two points on a body.
uniform vec2 u_inv0 = vec2(1.0, 0.0);        // inverse basis, column 0
uniform vec2 u_inv1 = vec2(0.0, 1.0);        // ...column 1
uniform vec2 u_anchor = vec2(0.9, 0.6);      // where her shoulder line lands
uniform vec2 u_src = vec2(0.9, 0.6);         // her own shoulder line
uniform vec2 u_eye_src = vec2(0.9, 0.2);     // her own eye line - the bust's center
uniform float u_unit = 0.3;                  // her eye-to-shoulder distance
// The bust: her silhouette thrown whole is a wall of black, so the mass is her head and shoulders - a radial falloff
// about her eye line, in her own units so it rides the transform - and below that the field's own smoke remains.
uniform float u_bust0 = 1.2;
uniform float u_bust1 = 2.6;
uniform float u_loom = 0.45;       // Coverage: how far down the body the bust reaches
uniform float u_rise = 1.0;        // Velocity: how fast the essence climbs
uniform float u_roil = 0.5;        // Contrast: turbulence in the currents
uniform float u_cling = 0.35;      // Cling: persistence in time
uniform float u_wisp = 0.0;        // Wisp: how readily essence detaches and rises
// The ghost's eyes (channel B): her eye landmarks pushed through the same cast transform as the body
// (MaskEditor._umb_cast_from) and carrying the Lead like everything read from the track. Deposited into the field, so
// they ooze and advect with the body.
uniform vec2 u_eye_l = vec2(0.5, 0.4);
uniform vec2 u_eye_r = vec2(0.6, 0.4);
uniform float u_eye_rad = 0.05;
uniform float u_eye_amt = 0.0;     // Gaze: 0 = no eyes at all

float permf(float x) {
	return mod(((x * 34.0) + 1.0) * x, 289.0);
}

float hash21u(vec2 p) {
	p = p - floor(p / 289.0) * 289.0;
	return fract(permf(permf(p.x) + p.y) * 0.145598);
}

float vnoiseu(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21u(i);
	float b = hash21u(i + vec2(1.0, 0.0));
	float c = hash21u(i + vec2(0.0, 1.0));
	float d = hash21u(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbmu(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += a * vnoiseu(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

// Screen position -> the point of her the ghost is showing there; aspect-corrected in and out.
vec2 to_source(vec2 uva) {
	vec2 d = uva - u_anchor;
	return u_src + u_inv0 * d.x + u_inv1 * d.y;
}

// Sampled with explicit bounds: outside the frame there is no body (letting the sampler clamp would smear the edge row
// into a false silhouette), and the mask fades out over a couple of cells instead of cutting dead (a ghost larger than
// she is would end in a straight line along the picture edge).
float mask_at(vec2 p) {
	vec2 d = min(p, vec2(1.0) - p);          // distance to the nearest edge, per axis
	if (min(d.x, d.y) < -0.02) {
		return 0.0;
	}
	float fade = smoothstep(-0.02, 0.03, min(d.x, d.y));
	return texture(u_region, clamp(p, vec2(0.0), vec2(1.0)).xy).r * fade;
}

// Divergence-free-ish wander: the gradient of a scalar noise, rotated 90 degrees (a plain noise velocity field has
// sources and sinks, where the mass would pool and drain at fixed spots).
vec2 curlu(vec2 p) {
	float e = 0.09;
	float n1 = fbmu(p + vec2(0.0, e));
	float n2 = fbmu(p - vec2(0.0, e));
	float n3 = fbmu(p + vec2(e, 0.0));
	float n4 = fbmu(p - vec2(e, 0.0));
	return vec2(n1 - n2, n4 - n3) / (2.0 * e);
}

void fragment() {
	vec2 uv = UV;
	vec2 asp = vec2(u_aspect, 1.0);
	float dt = clamp(u_dt, 0.0, 0.1);

	// --- The body, and the guard.
	// The mask arrives at grid resolution, so sampling it straight gives the mass a staircase edge. Jittering every
	// lookup by a little slow noise dissolves it; the amplitude just covers a cell (12 px), and the drift is a creep so
	// what remains reads as the mass breathing, not the edge shaking.
	vec2 jit = vec2(fbmu(uv * asp * 9.0 + vec2(3.1, u_time * 0.017)),
		fbmu(uv * asp * 9.0 + vec2(11.7, -u_time * 0.013))) - 0.5;
	jit *= 0.010;
	// Everything about where the ghost is happens in source space: the fragment asks which point of her it is showing,
	// and the whole body moves, turns and grows as one object.
	vec2 srca = to_source((uv + jit) * asp);
	float body = mask_at(vec2(srca.x / u_aspect, srca.y));
	// the bust: radial, in her own units, about her eye line, so it means the same at every Scale
	float rr = length(srca - u_eye_src) / max(u_unit, 1e-4);
	// where the ghost exists (her own outline is not in here)
	float perm = clamp(body * (1.0 - smoothstep(u_bust0, u_bust1, rr)), 0.0, 1.0);
	// Never on her. A single grid-aligned lookup draws her exclusion as a geometric cutout, so the max with a tap at
	// `jit` dissolves that edge like `body`'s; a maximum can only widen the excluded area, so the mass cannot creep onto her.
	float subj = max(texture(u_region, uv).b, texture(u_region, uv + jit).b);
	// The guard gates the picture, not the simulation: gating the deposit would empty every pixel her hand crosses and
	// rebuild it from zero at the rate Cling sets, dragging a hole behind every gesture. The mass keeps growing
	// underneath her and only `allow` is cut (mask_split multiplies everything it draws by this alpha). The band starts
	// at 0.34 so no strip of untouched wall is left between her outline and the mass.
	float allow = clamp(perm * (1.0 - smoothstep(0.34, 0.72, subj)), 0.0, 1.0);

	// The deposit must not be a static plate: relaxing toward a fixed target faster than the currents move anything
	// makes the field its input. So the target itself boils, on a noise that drifts upward.
	float churn = fbmu(uv * asp * 3.4 + vec2(u_time * 0.10, -u_time * 0.42));
	// the churn modulates a solid deposit, it does not gate one: the floor keeps the body continuous
	float tgt = perm * (0.78 + 0.44 * churn);

	// --- ADVECTION (semi-Lagrangian: sample where this parcel came FROM)
	vec4 prev0 = texture(u_prev, uv);
	vec2 cur = curlu(uv * asp * 2.6 + vec2(0.0, -u_time * 0.13));
	// buoyancy: denser mass climbs faster, which separates a body of smoke from a uniformly drifting sheet
	vec2 vel = vec2(0.0, -1.0) * (0.030 + 0.110 * prev0.r) * clamp(u_rise, 0.05, 4.0)
		+ cur * (0.020 + 0.070 * clamp(u_roil, 0.0, 1.0))
		+ (u_dir / asp) * 0.020 * clamp(u_loom, 0.0, 1.0);
	vec4 prev = texture(u_prev, clamp(uv - vel * dt, vec2(0.0), vec2(1.0)));

	// --- MASS: decay what is no longer inside the ghost, rise toward what is. Rate-limited rather than latching to the
	// target, or the shape pulses.
	float cling = clamp(u_cling, 0.0, 1.0);
	float tau_dec = mix(0.22, 1.70, cling);
	// slower than the clown's paint: a body of smoke that snaps to its target has no currents left to see
	float tau_up = mix(0.10, 0.70, cling);
	float m = prev.r * exp(-dt / tau_dec);
	// A hole fills faster than the mass breathes: Cling's rise time suits the churn (a small, constant deficit) but is too
	// slow for a gap (a large deficit), which would lag along the leading edge of fast movements. So the rate follows
	// the size of the deficit.
	float gap = max(0.0, tgt - m);
	float urgency = smoothstep(0.12, 0.50, gap);
	m += gap * (1.0 - exp(-dt / mix(tau_up, 0.035, urgency)));
	m = clamp(m, 0.0, 1.4);

	// --- ESSENCE: fed from the mass, rising faster, dying sooner, and pinched off in patches by a drifting noise so
	// tendrils separate instead of the whole top edge lifting as a sheet.
	vec2 velw = vec2(0.0, -1.0) * (0.105 + 0.26 * prev0.g) * clamp(u_rise, 0.05, 4.0)
		+ cur * (0.035 + 0.090 * clamp(u_roil, 0.0, 1.0));
	float wprev = texture(u_prev, clamp(uv - velw * dt, vec2(0.0), vec2(1.0))).g;
	// Essence leaves from the mass's upper surface, as smoke leaves a fire: `crest` is the vertical gradient (mass here,
	// nothing just above), so the feed concentrates along the top edge.
	float above = texture(u_prev, clamp(uv - vec2(0.0, 0.045), vec2(0.0), vec2(1.0))).r;
	float crest = clamp(m - above, 0.0, 1.0);
	// the threshold sits inside fbm's range (3 octaves sum to a mean near 0.44)
	float pinch = smoothstep(0.30, 0.62, fbmu(uv * asp * 5.2 + vec2(u_time * 0.09, -u_time * 0.62)));
	float feed = clamp(u_wisp, 0.0, 1.0) * (0.30 * m + 2.60 * crest) * pinch * 7.0;
	float w = wprev * exp(-dt / mix(0.18, 0.95, cling));
	w += feed * dt;
	// the essence is likewise free to exist under her: `allow` stops it being drawn there, and cutting it here would give
	// the trails the same refill lag
	w = clamp(w, 0.0, 1.2);

	// --- EYES. Two soft sockets, roughened by the same noise family as the body, and present only where there is mass
	// to cut them out of.
	float er = max(u_eye_rad, 0.004);
	float wob = fbmu(uv * asp * 7.0 + vec2(-u_time * 0.06, u_time * 0.11)) - 0.5;
	float dl = length((uv - u_eye_l) * asp) / er + wob * 0.55;
	float dr = length((uv - u_eye_r) * asp) / er + wob * 0.55;
	float socket = max(1.0 - smoothstep(0.35, 1.0, dl), 1.0 - smoothstep(0.35, 1.0, dr));
	float eyes_tgt = clamp(u_eye_amt, 0.0, 1.0) * socket * smoothstep(0.05, 0.30, m);
	float eprev = texture(u_prev, clamp(uv - vel * dt, vec2(0.0), vec2(1.0))).b;
	// faster than the body: the eyes must track her, not drift with the smoke
	float e = eprev * exp(-dt / 0.16);
	e += max(0.0, eyes_tgt - e) * (1.0 - exp(-dt / 0.07));
	e = clamp(e, 0.0, 1.0);

	if (u_reset == 1) {
		m = tgt;
		w = 0.0;
		e = eyes_tgt;
	}
	COLOR = vec4(m, w, e, allow);
}
