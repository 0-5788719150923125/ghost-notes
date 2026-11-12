shader_type canvas_item;
// blend_disabled: this shader writes a field, not a picture - all four channels are raw state. Under the default
// blend_mix the output RGB would be multiplied by the coat's own alpha on write, and the never-cleared buffer's alpha
// would survive outside the face.
render_mode blend_disabled;

// The clown's liquid paint field - a persistent, advected simulation the detector only deposits into. Runs in a
// ping-pong SubViewport pair (see MaskEditor._step_paint_sim); mask_split.gdshader samples the result as u_clown_paint
// instead of drawing feature shapes analytically.
//
// Channels: R = eye black (both patches), G = lip red, B = nose red, A = the white coat's face region (screen-space;
// the coat has no fitted oval geometry).
//
// Per step, per texel:
//   DEPOSIT - the current model's feature windows write in at full value immediately (paint arrives fast where the
//             feature is);
//   ADVECT  - existing paint drifts toward its channel's attractor (the feature's current position), so when a re-fit
//             jumps, the orphaned residue flows into the new spot instead of fading in place;
//   OOZE    - a slow noise wander plus slight diffusion keeps the blobs organic, never die-cut;
//   DECAY   - whatever never reaches a feature thins away (~0.5 s).
//
// A bounded one-step-per-frame feedback loop, frame-rate coupled by nature, stepped on playback time deltas so pause
// freezes the liquid and export traces the same currents.

uniform sampler2D u_prev : hint_default_black;
// The live frame plus the face's own color statistics: the deposits are evidence-driven, not stamped shapes. A landmark
// says where to look; the pixels say what the feature's shape is (dark socket, red lip line, lit nose ridge), as the
// white coat is a per-pixel face-tint match rather than a fitted oval.
uniform sampler2D u_frame : hint_default_black;
uniform float u_face_lum = 0.4;    // mean luminance over the detected face
uniform float u_face_red = 0.02;   // mean (r - g) over it - lips are redder than THIS
uniform float u_dt = 0.016;        // playback seconds advanced this step
uniform int u_reset = 0;           // 1 = snap the field to the targets (seek/first frame)
uniform float u_time = 0.0;        // playback clock, for the ooze wander
uniform float u_aspect = 1.7778;
uniform vec2 u_eye_l = vec2(0.42, 0.40);
uniform vec2 u_eye_r = vec2(0.58, 0.40);
uniform vec2 u_mouth = vec2(0.5, 0.62);
uniform vec2 u_nose = vec2(0.5, 0.52);       // its own slow anchor, not re-derived here
uniform vec2 u_face_c = vec2(0.5, 0.45);     // face centroid - the coat channel's home
uniform vec2 u_face_r = vec2(0.14, 0.20);    // face semi-axes (uv units)
// Feature sizes in plain screen units (uv height), not eye-distance units: normalizing by the eye pair would couple
// every feature's size to the pair's jitter.
uniform float u_eye_lr = 0.035;
uniform float u_eye_rr = 0.035;
uniform vec2 u_mouth_r = vec2(0.05, 0.028);  // x in uv-x units, y in uv-y units
uniform float u_scale = 1.0;       // the clown layer's Scale knob (feature sizes)

// Plausibility caps on the fitted widths, in height units (the space this shader works in - see `p = UV * asp` below),
// never raw uv: a cap of 0.145 of the frame's width is 0.258 frame-heights on a landscape clip and 0.082 on a portrait
// one. These are the raw-uv bounds converted at 16:9, so every frame shape gets the same physical cap.
const float FACE_CAP_XLO = 0.0889;    // raw uv 0.05
const float FACE_CAP_XHI = 0.2578;    // raw uv 0.145
const float MOUTH_CAP_XLO = 0.0267;   // raw uv 0.015
const float MOUTH_CAP_XHI = 0.0978;   // raw uv 0.055
// How fast the eye paint runs downward, in aspect-space units per second, against an attractor pull of 2.4 per unit of
// offset - so it settles a little under the socket rather than streaming off the chin.
const float EYE_DRIP = 0.10;
// How hard the coat channel is pulled toward the face center, against 2.4 for the features (nearly still; see the
// advection call).
const float COAT_PULL = 0.35;
// The three clown-specific knobs, each a view onto an existing per-layer
// field (fx_smooth / fx_lag / fx_stick - see MaskSession's doc):
uniform float u_bleed = 0.0;       // Bleed  - how far the paint spreads/softens
uniform float u_settle = 0.35;     // Settle - how sticky the paint is in time
uniform float u_hollow = 0.0;      // Hollow - keep the paint AROUND a feature
// Evidence: how much of a drawn feature is the picture and how much is the stamped window it is drawn inside. Every
// feature is a window (an ellipse for the eye patches and nose, a wide shallow one for the lips) multiplied by what the
// frame shows there. Raising this lowers the floors of that multiply toward nothing, so the windows become bounds on
// where paint may go and the picture decides where it lands. 0 is the plain stamped look.
uniform float u_evidence = 0.0;
// The feature stencil - the landmark contours, rasterized (see MaskEditor's _update_stencil). R = the two eyes, G = the
// lips, B = the nose, A = the face oval, each a real outline rather than an ellipse, so the deposit windows are shapes
// the face has. Absent (all zero), the branch falls back to the analytic ellipses (no landmark track).
uniform sampler2D u_stencil : hint_default_black;
uniform float u_has_stencil = 0.0;
// How far the eye black runs down the cheek, past the eye itself: a deliberate, sized tongue of paint below each eye,
// distinct from the small always-on downward drift in the advection.
uniform float u_drip = 0.0;
// The run's weight and its bow: width scales the source width the stencil walk measured (a fraction of this eye);
// curve scales the outboard bias, from falling nearly straight to sweeping out across the cheekbone.
// Smudge: how far the eye paint is rubbed past its own contour, and how softly it ends (see the edge treatment in the
// deposit). Its zero is a soft edge, not the polygon.
uniform float u_eye_smudge = 0.45;
uniform float u_drip_w = 0.35;
uniform float u_drip_curve = 0.45;
// How far the coat's outer edge fades into the picture, in frame UV. The coat's silhouette is a rasterized polygon whose
// alpha steps from 1 to 0 across about one pixel, which reads as a sticker; the feather is made by averaging the alpha
// over a disc of this radius.
uniform float u_coat_feather = 0.012;

float permf(float x) {
	return mod(((x * 34.0) + 1.0) * x, 289.0);
}

float hash21p(vec2 p) {
	p = p - floor(p / 289.0) * 289.0;
	return fract(permf(permf(p.x) + p.y) * 0.145598);
}

float vnoisep(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21p(i);
	float b = hash21p(i + vec2(1.0, 0.0));
	float c = hash21p(i + vec2(0.0, 1.0));
	float d = hash21p(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Distance from a point to a segment. The eye-drip marches a centerline in steps and shades a lobe around it; measuring
// to the step's end point leaves a gap wherever a step is longer than the lobe is wide (a chain of beads).
float seg_dist(vec2 q, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float h = clamp(dot(q - a, ab) / max(dot(ab, ab), 1e-9), 0.0, 1.0);
	return length(q - a - ab * h);
}

// Soft ellipse: 1 well inside, feathered to 0 at the rim.
float ell(vec2 p, vec2 c, vec2 r) {
	return 1.0 - smoothstep(0.72, 1.0, length((p - c) / max(r, vec2(1e-4))));
}

// A look-here window: generous and very soft, so it bounds the search without drawing its own edge.
float win(vec2 p, vec2 c, vec2 r) {
	return 1.0 - smoothstep(0.35, 1.0, length((p - c) / max(r, vec2(1e-4))));
}

// One channel's advected sample: paint drifts toward `attract` and wanders under the shared ooze field. Each channel
// advects toward its own attractor, which is where the independence of the features lives.
float advected(int ch, vec2 p, vec2 attract, vec2 asp, float dt, vec2 bias, float pull) {
	vec2 wob = vec2(vnoisep(p * 5.0 + vec2(u_time * 0.5, 3.7)),
		vnoisep(p * 5.0 + vec2(19.1, -u_time * 0.4))) - 0.5;
	vec2 v = (attract - p) * pull + wob * 0.35 + bias;
	vec2 src = clamp((p - v * dt) / asp, vec2(0.0), vec2(1.0));
	vec4 s = texture(u_prev, src);
	return ch == 0 ? s.r : (ch == 1 ? s.g : (ch == 2 ? s.b : s.a));
}

void fragment() {
	vec2 asp = vec2(u_aspect, 1.0);
	vec2 p = UV * asp;
	vec2 el = u_eye_l * asp;
	vec2 er = u_eye_r * asp;
	vec2 mo = u_mouth * asp;
	vec2 nc = u_nose * asp;
	vec2 fc = u_face_c * asp;
	// Evidence, read from the frame at this texel, relative to the face's own statistics, never absolutes (the only thing
	// that survives a monochrome or heavily graded clip).
	// Dilated evidence: the max over a small ring, not the single texel. Raw per-pixel evidence traces a feature's
	// outline but never covers it; a max-filter grows each region from its strongest pixels, so coverage comes from the
	// anatomy's real extent and the contour stays organic.
	float dark = 0.0;
	float bright = 0.0;
	float redness = -1.0;
	float bright0 = 0.0;   // the CENTER tap only - see the hollow gate below
	float dark0 = 0.0;     // ...and its darkness, which is what Evidence shapes
	float red0 = 0.0;
	for (int k = 0; k < 9; k++) {
		vec2 off = vec2(0.0);
		if (k > 0) {
			float a = float(k - 1) * 0.7853981634;
			off = vec2(cos(a), sin(a)) * 0.016;
		}
		vec3 c3 = texture(u_frame, clamp(UV + off / vec2(u_aspect, 1.0),
			vec2(0.0), vec2(1.0))).rgb;
		float l3 = dot(c3, vec3(0.299, 0.587, 0.114));
		dark = max(dark, clamp((u_face_lum - l3) / max(u_face_lum, 0.08), 0.0, 1.0));
		float b3 = clamp((l3 - u_face_lum) / max(u_face_lum, 0.08), 0.0, 1.0);
		bright = max(bright, b3);
		if (k == 0) {
			bright0 = b3;
			dark0 = clamp((u_face_lum - l3) / max(u_face_lum, 0.08), 0.0, 1.0);
			red0 = c3.r - c3.g;
		}
		redness = max(redness, c3.r - c3.g);
	}
	float fred = redness;
	// EYES: the black covers what is actually dark inside the look-window - socket, lashes, lid crease, brow - so it wraps
	// the eye's own shape instead of capping a disc over it. Windows are per-eye and generous.
	// The anatomy's own spacing bounds every feature, so Scale cannot merge them: each radius is capped against the
	// distance to its neighbors (which the detector knows) at fractions that keep a real gap between windows. Scale
	// still grows everything, approaching the packing limit of the face.
	float sep = max(distance(el, er), 1e-4);          // between the eyes
	vec2 emid = (el + er) * 0.5;
	float d_en = max(distance(emid, nc), 1e-4);       // eye line down to the nose
	float d_nm = max(distance(nc, mo), 1e-4);         // nose down to the mouth
	float spread = 1.0 + 0.7 * u_bleed;
	float rl = clamp(u_eye_lr, 0.012, 0.08) * u_scale * 1.75 * spread;
	float rr = clamp(u_eye_rr, 0.012, 0.08) * u_scale * 1.75 * spread;
	// 0.42 of the separation leaves the two eye windows clear of each other (touching would need 0.5 each), and 0.72 of
	// the eye-to-nose distance keeps them off the nose.
	rl = min(rl, min(sep * 0.42, d_en * 0.72));
	rr = min(rr, min(sep * 0.42, d_en * 0.72));
	float eye_ev = smoothstep(0.04, 0.26, dark);
	float wl = win(p, el, vec2(rl, rl * 1.15));
	float wr = win(p, er, vec2(rr, rr * 1.15));
	float drip_t = 0.0;
	// the rubbed edge, shared by every feature (see the treatment inside the branch); held out here because the lips and
	// the nose are shaded further down
	float smudge_lip = 0.0;
	float smudge_nose = 0.0;
	float smudge_thr = 0.5;
	float smudge_band = 0.28;
	if (u_has_stencil > 0.5) {
		// The eye patch's edge is rubbed, not cut. The patch is a rasterized polygon whose edge steps from 1 to 0 across
		// about one texel; paint that has been rubbed thins away over a band and reaches further out in some places than
		// others, and this draws both:
		//
		//   The band   the polygon's alpha is averaged over a disc, turning the step into a ramp as wide as the disc
		//              (as the coat's feather does).
		//   The reach  the level that ramp is cut at is modulated by noise in the face's own frame, so the paint
		//              pushes out past the contour in some places and pulls in at others, and the pattern rides the
		//              head rather than the screen (the rule clown_anchor_check exists for).
		//
		// Both scale with Smudge; its floor is a soft edge, not the polygon.
		// Both edges are the same edge: the patch's outer contour and the opening's rim are two boundaries of one
		// rasterized polygon pair, so one control rubs both. The opening lives in the coat's alpha (the second,
		// subtractive stencil pass cut it there), so the two channels are sampled from the same taps.
		float smd = clamp(u_eye_smudge, 0.0, 1.0);
		// capped well under the opening's own size: an eye is about 0.034 tall in these units, and a disc much past a
		// third of that averages the ring's paint across the hole and closes it
		float sm_r = min(0.004 + 0.014 * smd, 0.016);
		vec4 c_e = texture(u_stencil, UV);
		float acc_e = c_e.r;
		// the lips and the nose come off the same taps (one texture fetch): one control rubs the whole make-up
		float acc_g = c_e.g;
		float acc_b = c_e.b;
		float wsum_e = 1.0;
		for (int ei = 0; ei < 8; ei++) {
			float ea = float(ei) * 0.7853981634 + 0.3926990817;
			vec2 dir_e = vec2(cos(ea) / max(u_aspect, 1e-4), sin(ea));
			vec4 t_mid = texture(u_stencil, clamp(UV + dir_e * sm_r * 0.5,
				vec2(0.0), vec2(1.0)));
			vec4 t_out = texture(u_stencil, clamp(UV + dir_e * sm_r,
				vec2(0.0), vec2(1.0)));
			acc_e += 0.75 * t_mid.r + 0.45 * t_out.r;
			acc_g += 0.75 * t_mid.g + 0.45 * t_out.g;
			acc_b += 0.75 * t_mid.b + 0.45 * t_out.b;
			wsum_e += 1.2;
		}
		float soft_e = clamp(acc_e / wsum_e, 0.0, 1.0);
		smudge_lip = clamp(acc_g / wsum_e, 0.0, 1.0);
		smudge_nose = clamp(acc_b / wsum_e, 0.0, 1.0);
		// the ragged reach, in the face's own frame so it rides the head (the rule clown_anchor_check exists for)
		vec2 fdir_e = (er - el) / max(distance(er, el), 1e-4);
		vec2 frel_e = (p - fc) / max(distance(er, el), 1e-4);
		vec2 fco_e = vec2(dot(frel_e, fdir_e), dot(frel_e, vec2(-fdir_e.y, fdir_e.x)));
		float rag_e = vnoisep(fco_e * (7.0 + 5.0 * smd) + vec2(3.1, 8.4));
		// The ramp is centered on the contour: solving thr + band/2 = 0.5 keeps the average boundary where the polygon is at
		// every setting (a fixed lower edge would shrink the patch as it softens); the raggedness then pushes it out in
		// some places and in at others.
		float band_e = 0.28 + 0.35 * smd;
		float thr_e = 0.5 - band_e * 0.5 - (rag_e - 0.5) * 0.40 * smd;
		smudge_band = band_e;
		smudge_thr = thr_e;
		wl = smoothstep(thr_e, thr_e + band_e, soft_e);
		// Soft pressure against the bridge of the nose: at a generous Eye size the two patches grow far enough to meet over
		// it. Holding the hulls back cannot fix that (sixteen vertices cannot describe a soft boundary; a growth cap, a
		// flatten or a squeeze each draws a straight edge down the inner side of the socket), so a fade with a sample per
		// texel does it.
		//
		// The fade is full by 0.11 of the eye separation and zero by 0.02, so it lives in the bridge itself and finishes
		// before it reaches any part of the eye (the hole at a wound-up Hollow reaches 0.13 from the midline). Measured in
		// eye separations so it holds at any distance, and along the eye line so it holds at any tilt.
		vec2 evb = er - el;
		float sepb = max(length(evb), 1e-4);
		float alongb = abs(dot(p - (el + er) * 0.5, evb / sepb));
		wl *= smoothstep(sepb * 0.02, sepb * 0.11, alongb);
		// No second gate on the coat's alpha: it is zero in the openings and everywhere off the face, so multiplying by it
		// cuts a straight edge down each socket. The eyeball is kept clear by the ring's own geometry; Smudge only must
		// not blur wider than the opening (see sm_r's cap).
		wr = 0.0;   // both eyes live in the one channel now
		// The run is a tear of liner leaving the lash line, measured off the paint that is actually there - the rasterized
		// eye patch in the stencil, which knows the eye's real outline, how far Eye size grew it and how far Hollow
		// opened it:
		//
		//   Where it leaves  walk down-and-outward from the eye center until the patch ends: the lash line's lower-outer
		//                    corner on this face. The head of the run is set slightly inside the patch, so the two are
		//                    one shape with no seam.
		//   How wide         walk outward along the eye line until the patch ends; Drip width scales that source width.
		//   How far          eye to chin, scaled by Drip.
		//   What shape       width tapers; the path is biased outboard by an amount that grows with distance, so it curves
		//                    onto the cheek; Drip curve scales that bias; the picture's own structure still deflects it.
		//
		// If the walk finds no patch (eyes lost to a turn, a hand, a blink with Hollow wide open) there is no run: that is
		// the gate. (Sampling the eye center is no test: it is a hole in a ring.)
		//
		// It is not evidence-gated: the eye window is multiplied by how dark the picture is, and a cheek is not dark.
		if (u_drip > 0.001) {
			vec2 eyev_d = er - el;
			vec2 ex_d = eyev_d / max(length(eyev_d), 1e-4);   // across the face, l -> r
			// The furthest a run could sensibly go: eye to chin, measured on the face.
			float chin_d = max((u_face_c.y + u_face_r.y) - u_eye_l.y, 0.02);
			// the gradient taps' spacing: `grad` below is a luminance difference across this, not a derivative, so the
			// deflection's threshold is calibrated to it (a real cheekbone moves luminance about 0.02 across a step this size)
			vec2 gstep_d = vec2(0.0072 / max(u_aspect, 1e-4), 0.0072);
			for (int e = 0; e < 2; e++) {
				vec2 eye_c = e == 0 ? el : er;
				float eye_w = e == 0 ? rl : rr;      // the look-window: a SEARCH bound only
				float sgn = e == 0 ? -1.0 : 1.0;     // outward, along the eye line
				float reach = u_drip * chin_d;
				// coarse rejection before the walks, on the most generous box the run could occupy (without it every texel does
				// both walks); `rl`/`rr` are clamped at 0.08 height units and a close-up face measures 0.128, so the box
				// takes the larger of the two
				float ew_b = max(eye_w, e == 0 ? u_eye_lr : u_eye_rr) * 5.0;
				if (p.y < eye_c.y - ew_b || p.y > eye_c.y + ew_b + reach
						|| abs(dot(p - eye_c, ex_d)) > ew_b + reach) { continue; }
				// WALK DOWN-AND-OUT to the patch's lower-outer corner...
				float low = 0.0;
				for (int k = 1; k <= 24; k++) {
					float dd = float(k) * eye_w * 0.16;
					vec2 q = eye_c + ex_d * (sgn * dd * 0.45) + vec2(0.0, dd);
					if (texture(u_stencil, clamp(q / asp, vec2(0.0), vec2(1.0))).r > 0.40) {
						low = dd;
					}
				}
				if (low < 1e-5) { continue; }        // no eye paint here, so no run
				// ...and OUTWARD to its outer edge, which is what sets the width.
				float halfw = 0.0;
				for (int k = 1; k <= 14; k++) {
					float dd = float(k) * eye_w * 0.28;
					vec2 q = eye_c + ex_d * (sgn * dd);
					if (texture(u_stencil, clamp(q / asp, vec2(0.0), vec2(1.0))).r > 0.40) {
						halfw = dd;
					}
				}
				if (halfw < 1e-5) { halfw = low; }
				// The run leaves at the lash line's own width: what has to read is the join - paint leaves a socket along the
				// whole edge it is draining and only then gathers into a run (a sixth of the width reads as a thread stuck
				// underneath). `u_drip_w` is a direct fraction of the measured half-width; at the top of its slider the run
				// leaves wider than the socket's half-width.
				float w0 = halfw * clamp(u_drip_w, 0.05, 1.6);
				// the head sits inside the patch so the run and the eye shadow read as one shape; capped at half the way back to
				// the eye center, since w0 is a socket-sized number and burying the head by all of it would start the run
				// above the eye
				vec2 srcp = eye_c + ex_d * (sgn * low * 0.45)
					+ vec2(0.0, low - min(w0 * 0.9, low * 0.5));
				float seg = reach / 18.0;
				vec2 cp = srcp;
				float run = 0.0;
				for (int d = 0; d < 18; d++) {
					float t = (float(d) + 0.5) / 18.0;
					vec2 gp = clamp(cp / asp, vec2(0.0), vec2(1.0));
					float l_c = dot(texture(u_frame, gp).rgb, vec3(0.299, 0.587, 0.114));
					float l_x = dot(texture(u_frame, clamp(gp + vec2(gstep_d.x, 0.0),
						vec2(0.0), vec2(1.0))).rgb, vec3(0.299, 0.587, 0.114));
					float l_y = dot(texture(u_frame, clamp(gp + vec2(0.0, gstep_d.y),
						vec2(0.0), vec2(1.0))).rgb, vec3(0.299, 0.587, 0.114));
					vec2 grad = vec2(l_x - l_c, l_y - l_c);
					vec2 tang = vec2(-grad.y, grad.x);
					if (tang.y < 0.0) { tang = -tang; }   // a run only ever goes downhill
					float gs = smoothstep(0.002, 0.020, length(grad));
					vec2 dir = normalize(vec2(0.0, 1.0)
						+ ex_d * (sgn * clamp(u_drip_curve, 0.0, 2.0) * t)
						+ normalize(tang + vec2(0.0, 1e-3)) * (0.22 * gs));
					vec2 pcp = cp;
					// step by vertical descent, not arc length: Drip promises "this far down the face", and dividing the step by
					// the direction's vertical component keeps that whatever Drip curve is set to (floored so a sideways step
					// cannot run away)
					cp += dir * (seg / max(dir.y, 0.35));
					// the taper, plus a ragged term so it is not a drawn wedge; both are functions of position along the run
					float ragg = vnoisep(vec2(t * 9.0 + float(e) * 31.0, 2.7));
					// full width at the top, then a fast thin: a smoothstep holds the source width long enough for the join to
					// read, then collapses over the first half. The floor is not a hairline (at 6% Drip curve went dead:
					// clown_controls_check), so the tail stays a visible line.
					float w = w0 * (0.14 + 0.86 * (1.0 - smoothstep(0.05, 0.55, t)))
						* (0.80 + 0.40 * ragg);
					// a dark thread inside a soft smudge, not a flat bar: pigment in liquid has a wet core and a halo where it has
					// spread; two profiles off the same centerline give that for one distance calculation
					float dd = seg_dist(p, pcp, cp);
					float core = 1.0 - smoothstep(w * 0.10, w * 0.45, dd);
					float halo = 1.0 - smoothstep(w * 0.30, w * 1.30, dd);
					float lobe = max(core, halo * 0.45);
					// thinning in width reads as a run drying out; the value also eases off over the last third so the tail
					// fades into the cheek
					run = max(run, lobe * smoothstep(1.0, 0.78, t) * mix(1.0, 0.70, t));
				}
				// The eyeball stays clear: the head of the run reaches back up into the ring's opening, the one place the eye
				// paint does not go. Above the drain line the run is admitted only where the stencil says there is eye paint
				// (`wl`, already sampled for the socket); below it, it is free.
				//
				// Masking against the stencil is exact: rebuilding the hole from (0.9 + Hollow * 0.6) x the measured radius
				// assumes a disc, but the radius is the eye's semi-major extent and an eye is about 0.4 as tall as wide, so
				// a disc that clears the eyeball also eats the head of the run.
				float above_src = smoothstep(srcp.y + 0.004, srcp.y - 0.004, p.y);
				drip_t = max(drip_t, run * max(1.0 - above_src, wl));
			}
		}
	}
	// Hollow's radial hole, gated on brightness: a visible eyeball is the bright thing inside a dark socket, so the hole
	// opens on an open eye and mostly closes on a blink. The gate reads this pixel's own brightness, never the dilated
	// max (a closed eyelid sits next to bright cheek, and a dilated read would erase the eye paint on every blink).
	float hole_gate = smoothstep(0.05, 0.30, bright0);
	float dnl = length((p - el) / max(vec2(rl, rl * 1.15), vec2(1e-4)));
	float dnr = length((p - er) / max(vec2(rr, rr * 1.15), vec2(1e-4)));
	float hole_e = smoothstep(0.55, 0.0, min(dnl, dnr)) * hole_gate;
	// Evidence shapes the paint rather than flooring it: how much of the picture's own light and shade shows through.
	// Low is a flat fill of the measured outline; high paints only where the frame is genuinely dark or red, so the
	// eye's crease and the lip line come through as texture.
	// It shapes the center tap, not the dilated one: `dark`, `bright` and `redness` are each a max over a ring of nine
	// taps (a dilation, so the paint covers a feature without pinholes) and a dilated max saturates at 1.0 across the
	// window. The center tap still varies pixel to pixel, so Evidence blends from the dilated term (a flat fill) toward
	// the center tap's own value.
	float ev_mix = clamp(u_evidence, 0.0, 1.0);
	// The socket's paint is evidence-shaped; the run below it is not (see the drip above). Hollow's radial hole is scaled
	// back when the stencil is present: the eyeball is cut out of the ring geometrically there, and applying both would
	// open the hole twice.
	float hole_k = u_has_stencil > 0.5 ? 0.35 : 1.0;
	// The floor stays on the flat end: without it a feature vanishes wherever the evidence is weak (clown_scale_check:
	// the nose fell to 0.14 at low Scale). Evidence blends between two live behaviors, a reliable fill at 0 and the
	// picture's own texture at 1.
	float eye_tex = smoothstep(0.02, 0.42, dark0);
	// The flat end is flat once there is a measured outline: a floor under the evidence (0.22 + 0.78 * eye_ev) lets the
	// bright skin outside an eye fall to 0.22, which mask_split's eyeM16 ramp (smoothstep(0.12, 0.50, r)) turns into 26%
	// black, so the white coat comes through the middle of the paint and splits it.
	//
	// With the stencil the window is the feature (a measured contour grown by Eye size), so filling it is the point and
	// Evidence lets the picture back through. Without one, `wl` is a generous analytic ellipse and a flat fill of that
	// draws circles over the face, so the fallback keeps the evidence-shaped behavior.
	float eye_flat = u_has_stencil > 0.5 ? 1.0 : (0.22 + 0.78 * eye_ev);
	float tblack = max(wl, wr) * mix(eye_flat, eye_tex * eye_tex, ev_mix)
		* (1.0 - u_hollow * hole_e * hole_k);
	// full value: the run already carries its own falloff (see the deposit), and the socket and the paint leaving it are
	// one shape, so they are one value
	tblack = max(tblack, drip_t);
	// LIPS: redder than the face's own mean, or the dark line of the mouth itself - whichever is stronger. The
	// look-window is wide and shallow (a mouth's proportions), the evidence draws the lips.
	// Capped in height units, like the coat's radii below.
	vec2 lr = vec2(clamp(u_mouth_r.x * u_aspect, MOUTH_CAP_XLO, MOUTH_CAP_XHI) * 1.9,
		clamp(u_mouth_r.y, 0.010, 0.032) * 1.7) * u_scale * spread;
	// the lips' height is what runs into the nose; their width is bounded only against the eye separation, to stop a
	// mouth wider than the face
	lr = vec2(min(lr.x, sep * 1.05), min(lr.y, d_nm * 0.5));
	float lip_ev = max(smoothstep(0.005, 0.075, fred - u_face_red),
		smoothstep(0.07, 0.38, dark) * 0.9);
	// same hollow rule for the lips: teeth are the bright thing inside an open mouth, so the center clears when it opens
	float hole_m = smoothstep(0.45, 0.0, length((p - mo) / max(lr, vec2(1e-4)))) * hole_gate;
	float lipw = win(p, mo, lr);
	if (u_has_stencil > 0.5) {
		// the measured lips, already widened and swept by Smile width / Smile curve before rasterizing
		lipw = smoothstep(smudge_thr, smudge_thr + smudge_band, smudge_lip);
	}
	float lip_tex = max(smoothstep(0.0, 0.10, red0 - u_face_red),
		smoothstep(0.04, 0.45, dark0) * 0.85);
	float lip_flat = 0.18 + 0.82 * lip_ev;
	float tlip = lipw * mix(lip_flat, lip_tex * lip_tex, ev_mix) * (1.0 - u_hollow * hole_m);
	// NOSE: the one feature with no reliable 2D signature - a nose is a 3D protrusion, so its evidence is the lit ridge
	// plus the shadow under the tip. Window-led with a higher floor, brightness-shaped so the ball hugs the actual nose.
	float nr = clamp(rl * 0.55 + rr * 0.55, 0.018, 0.075) * u_scale;
	// the nose has a neighbor on both sides, so it takes the tightest bound of the three: half the way down to the lips,
	// and clear of the eye windows above it
	nr = min(nr, min(d_nm * 0.48, d_en * 0.55));
	// brightness leads; the shadow under the nose is a weak, late-thresholded assist only (leaning on it bridges the ball
	// into the lips)
	float nose_ev = max(smoothstep(0.0, 0.22, bright), smoothstep(0.22, 0.55, dark) * 0.45);
	float nosew = win(p, nc, vec2(nr, nr * 0.95));
	if (u_has_stencil > 0.5) {
		nosew = smoothstep(smudge_thr, smudge_thr + smudge_band, smudge_nose);
	}
	float nose_tex = max(smoothstep(0.0, 0.30, bright0), smoothstep(0.25, 0.6, dark0) * 0.5);
	float nose_flat = 0.42 + 0.58 * nose_ev;
	float tnose = nosew * mix(nose_flat, nose_tex * nose_tex, ev_mix);
	// The coat's radii are capped at a face-plausible size: on footage where the key hue washes the whole room, the
	// fitted spread is the room's and an uncapped coat paints the wallpaper.
	// The cap is applied in height units, after the aspect conversion, never in raw uv (0.145 of the width is 0.258
	// frame-heights on 16:9 and 0.082 on a 9:16 clip). FACE_CAP_* are the raw bounds converted at 16:9 (x1.7778).
	vec2 fr = vec2(clamp(u_face_r.x * u_aspect, FACE_CAP_XLO, FACE_CAP_XHI),
		clamp(u_face_r.y, 0.07, 0.205))
		// Scale's authority over the coat: 0.4 + 0.6x gives the slider real travel (the radii sit on their caps on a
		// generous fit, so a narrow span reads as a control that does nothing)
		* 1.05 * (0.4 + 0.6 * u_scale);
	float tface = 1.0 - smoothstep(0.72, 1.05, length((p - fc) / fr));
	if (u_has_stencil > 0.5) {
		// The jawline itself, so the coat stops at the face, feathered by averaging the silhouette over a small disc: two
		// rings plus the center (smooth rather than banded, few enough to be free). Round in pixels (u_texel_c carries the
		// aspect), so the feather is the same width top and side.
		float acc_f = texture(u_stencil, UV).a;
		float wsum_f = 1.0;
		for (int fi = 0; fi < 8; fi++) {
			float fa = float(fi) * 0.7853981634 + 0.3926990817;
			vec2 fd = vec2(cos(fa) / max(u_aspect, 1e-4), sin(fa)) * u_coat_feather;
			acc_f += 0.75 * texture(u_stencil, clamp(UV + fd * 0.5, vec2(0.0), vec2(1.0))).a;
			acc_f += 0.45 * texture(u_stencil, clamp(UV + fd, vec2(0.0), vec2(1.0))).a;
			wsum_f += 1.2;
		}
		tface = clamp(acc_f / wsum_f, 0.0, 1.0);
	}
	vec4 tgt = vec4(tblack, tlip, tnose, tface);
	if (u_reset == 1) {
		COLOR = tgt;
	} else {
		// Carry: advection toward each channel's own attractor (the eye channel flows to whichever eye is nearer, the coat
		// to the face center), folded with a touch of blur so edges soften in transit.
		vec2 eatt = distance(p, el) < distance(p, er) ? el : er;
		// The eye paint runs downward: a small constant downward term in the eye channel's drift settles equilibrium just
		// below the socket and pulls strays back down (an isotropic pull would let overshoot smear across the brow).
		// The coat barely drifts, the features do. Advection samples backward along the flow, so a channel pulled toward the
		// face center reads at its outer boundary from just outside itself, where there is no paint; the deposit refills
		// that from zero each step and a permanent unpainted band remains (3.7% of frame width at the default Settle,
		// 13% at the top). The features need the drift (orphaned paint flows to a re-fit); the coat is a fill and the
		// deposit already follows the face, so its pull (COAT_PULL) is small enough that its boundary is fed, not drained.
		vec4 adv = vec4(
			advected(0, p, eatt, asp, u_dt, vec2(0.0, EYE_DRIP), 2.4),
			advected(1, p, mo, asp, u_dt, vec2(0.0), 2.4),
			advected(2, p, nc, asp, u_dt, vec2(0.0), 2.4),
			advected(3, p, fc, asp, u_dt, vec2(0.0), COAT_PULL));
		vec2 px = 1.0 / vec2(textureSize(u_prev, 0));
		vec4 blur = (texture(u_prev, UV + vec2(px.x, 0.0))
			+ texture(u_prev, UV - vec2(px.x, 0.0))
			+ texture(u_prev, UV + vec2(0.0, px.y))
			+ texture(u_prev, UV - vec2(0.0, px.y))) * 0.25;
		vec4 carried = mix(adv, blur, mix(0.10, 0.45, u_bleed));
		// Settle sets both time constants: how long orphaned paint lingers and how fast new paint rises. The deposit is
		// rate-limited, not instant (slamming to full value on an evidence spike makes the shapes pulse); rising over
		// ~0.1-0.4 s low-passes the evidence's noise without visibly lagging the face.
		float tau_dec = mix(0.25, 1.6, clamp(u_settle, 0.0, 1.0));
		float tau_up = mix(0.06, 0.40, clamp(u_settle, 0.0, 1.0));
		vec4 f = carried * exp(-u_dt / tau_dec);
		vec4 rise = max(vec4(0.0), tgt - f) * (1.0 - exp(-u_dt / tau_up));
		vec4 out4 = max(f + rise, vec4(0.0));
		// The coat never falls below its own deposit: any transport at a boundary with nothing beyond it drains that
		// boundary (the wander pushes outward, the blur averages in the zeros outside), and the refill rate Settle sets
		// leaves a rim that widens with Settle. The features are paint and must be erodable (Hollow opens them, evidence
		// shapes them); the coat is a mask - where the face is - so the alpha channel is the deposit exactly, floor and
		// ceiling (a ceiling also keeps advection from refilling the eye openings: just outside a hole the coat is
		// solid). Bleed keeps its whole effect on the features (see `spread`, which widens every feature radius).
		out4.a = tgt.a;
		COLOR = out4;
	}
}
