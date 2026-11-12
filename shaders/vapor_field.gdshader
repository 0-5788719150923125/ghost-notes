shader_type canvas_item;
render_mode blend_add;

// Vapor field - the volumetric body of [Layer.Vapor].
//
// Colored vapor: heavy, twisting masses of ink-in-water with torn, wispy fronts and threads of stretched cotton pulling
// off them, lit from inside. Every pixel of one quad evaluates the same density field. It is a field because stacked
// gaussian puffs (`clouds`, `fog_bank`, `fog_volume`, `aurora`) can only be soft: this look is diffuse but hard, with a
// visible boundary, filaments inside the mass, and color that changes across it.
//
// The generator is a ridged multifractal: each octave is creased (1 - |2n-1|, raised to a power) and weighted by the
// octave above it, so detail collects on the creases. It is isotropic (it cannot band like ridged noise squashed across
// a flow field) and its level sets are the torn edge.
//
// Three more parts:
//   Twist - the sample point is domain-warped twice by low-frequency noise that scrolls in time, coarsely (the mass
//   turning over) then finely (the curl inside it); two warps give the folded, re-entrant shapes ink makes in water.
//   Stretch - the multifractal is sampled in a frame aligned to a smooth flow angle and mildly squashed across it,
//   elongating the filaments along the flow (pushed further it turns cotton to corduroy). The direction comes from an
//   angle field because a normalized vector is degenerate where it passes through zero.
//   Light - the plume envelope is analytic, so it is re-evaluated a couple of steps toward the lamp as optical depth,
//   exp(-k * occlusion): the far side of a mass goes dark and its near side glows.
//
// Color is per plume, mixed by contribution, so overlapping masses blend and isolated ones keep their hue; it has depth:
// the fringe takes the scheme's second hue, the core keeps its own, the hottest creases bleach to white.
//
// Time is a uniform (the layer's clock), never TIME: live and the offline bake step the same clock, so a seed
// reproduces its vapor. Same rule as flame.gdshader.

// The plumes: center, amplitude, elliptical radii, color. Each is driven by its own harmonic band on the CPU side (see
// Layer.Vapor).
uniform int u_n = 5;
uniform float u_px[8];
uniform float u_py[8];
uniform float u_amp[8];
uniform float u_rx[8];
uniform float u_ry[8];
uniform vec3 u_col[8];
// Per-plume glow: a beat's answer. It scales that plume's light and touches nothing geometric (see u_burst).
uniform float u_glow[8];

// An integrated phase, not a clock: the layer accumulates it (phase += dt * rate) and the rate is where the music reaches
// the motion. Multiplying an absolute clock by a changing rate would jump the phase by (dt_rate x t).
uniform float u_time = 0.0;
// The medium's own steady travel, integrated by the layer the same way: the vapor streams through the frame at a
// constant rate whatever the music does.
uniform vec2 u_drift = vec2(0.0);
uniform vec2 u_half = vec2(0.9, 0.55);   // quad half-extents in unit fractions
uniform vec2 u_seed = vec2(0.0);         // noise offset       (sampled per instance)
uniform float u_scale = 1.0;             // feature size       (sampled per instance)
uniform float u_swirl = 0.6;             // domain-warp gain: how hard it twists
uniform float u_crease = 2.0;            // ridge sharpness: 1 = billowy, 3 = wiry filament
uniform float u_stretch = 2.0;           // flow-aligned anisotropy (1 = none, 3.5 = drawn out)
uniform float u_hard = 0.6;              // 0 = haze-soft front, 1 = a cut front
uniform float u_thresh = 0.5;            // density the front sits at
uniform float u_haze = 0.16;             // unthresholded bloom around the masses
uniform float u_gain = 1.0;              // brightness         (sampled per instance)
// Beat surge - brightness only: widening the density or pushing the warp gain would move geometry. Light may pulse,
// shape may not.
uniform float u_burst = 0.0;
uniform vec2 u_light = vec2(-0.45, -0.25); // the lamp, in the same unit fractions
uniform float u_shadow = 2.0;            // optical depth per unit of plume mass
uniform vec3 u_rim = vec3(0.35, 0.65, 1.0); // the fringe chroma (the scheme's accent)

// The same mod-289 lattice hash flame.gdshader uses, for the same reason: inputs are bounded before any multiply, so
// precision holds however far the time scroll pushes the coordinates. (Copied, not shared through an include.)
float permf(float x) {
	return mod(((x * 34.0) + 1.0) * x, 289.0);
}

float hash21(vec2 p) {
	p = p - floor(p / 289.0) * 289.0;
	return fract(permf(permf(p.x) + p.y) * 0.145598);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Three octaves for the warps: they are steered, not looked at, and detail there costs a lot while showing as nothing.
float fbm3(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p;
		a *= 0.5;
	}
	return v;
}

// The body: a ridged multifractal. `sharp` creases each octave and the running weight `w` admits the next octave only
// where this one is already high, so fine detail lives on the filaments and the space between them stays smooth.
// Returns roughly 0..1.
float ridged(vec2 p, float sharp) {
	float sum = 0.0;
	float amp = 0.55;
	float w = 1.0;
	for (int i = 0; i < 5; i++) {
		float n = 1.0 - abs(2.0 * vnoise(p) - 1.0);
		n = pow(n, sharp);
		sum += n * amp * w;
		w = clamp(n * 1.6, 0.0, 1.0);
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p;   // determinant 4: an octave per step
		amp *= 0.5;
	}
	return sum;
}

// The plume envelope: a sum of elliptical gaussians. Analytic and cheap, so it can be tapped again along the light ray.
float env(vec2 p) {
	float m = 0.0;
	for (int i = 0; i < u_n; i++) {
		vec2 d = vec2((p.x - u_px[i]) / u_rx[i], (p.y - u_py[i]) / u_ry[i]);
		m += u_amp[i] * exp(-dot(d, d));
	}
	return min(m, 1.35);
}

// The same envelope, also returning the color the plumes mix to here, weighted by contribution.
float env_col(vec2 p, out vec3 chroma, out float glow) {
	float m = 0.0;
	vec3 acc = vec3(0.0);
	float gl = 0.0;
	for (int i = 0; i < u_n; i++) {
		vec2 d = vec2((p.x - u_px[i]) / u_rx[i], (p.y - u_py[i]) / u_ry[i]);
		float g = u_amp[i] * exp(-dot(d, d));
		m += g;
		acc += u_col[i] * g;
		gl += u_glow[i] * g;
	}
	chroma = acc / max(m, 1e-4);
	glow = gl / max(m, 1e-4);
	// capped, like the fire bed's env: overlapping plumes sum past 3 and everything downstream of density would
	// saturate into one white shape; the cap keeps an overlap reading as a denser mass
	return min(m, 1.35);
}

void fragment() {
	vec4 fade = COLOR;  // white quad texture x modulate: the scene's fade rides in here

	vec2 p = (UV - 0.5) * 2.0 * u_half;   // unit fractions, y down, (0,0) at center
	float tt = u_time;      // already a phase (see the uniform)

	// --- TWIST: two domain warps, both scrolling ---
	vec2 q = p * (1.5 * u_scale) + u_seed;
	vec2 w1 = vec2(fbm3(q * 0.75 + vec2(0.0, -tt * 0.06)),
			fbm3(q * 0.75 + vec2(tt * 0.05, 0.0) + 37.1)) - 0.5;
	vec2 pw = p + w1 * u_swirl;
	vec2 w2 = vec2(fbm3(pw * (3.0 * u_scale) + vec2(tt * 0.10, 0.0) + 11.3),
			fbm3(pw * (3.0 * u_scale) - vec2(0.0, tt * 0.12) + 71.9)) - 0.5;
	// the fine warp is weighted generously: it also stops the plume ellipses showing (a gaussian envelope times a locally
	// smooth multifractal has circular level sets, which render as onion rings)
	vec2 pw2 = pw + w2 * u_swirl * 0.55;

	// --- STRETCH: the flow frame, from a smooth angle field ---
	float ang = 6.28318 * fbm3(pw * (1.1 * u_scale) + u_seed * 0.11 + 5.3);
	vec2 dir = vec2(cos(ang), sin(ang));
	vec2 per = vec2(-dir.y, dir.x);
	// the medium travels, its envelope does not: the drift is added for the noise sampling only, so the filaments stream
	// through masses that stay where the composition put them
	vec2 pd = pw2 + u_drift;
	vec2 pf = vec2(dot(pd, dir), dot(pd, per) * u_stretch);

	// --- the mass, its color, and how deep inside it we are ---
	vec3 chroma;
	float plume_glow;
	float m = env_col(pw2, chroma, plume_glow);
	float nb = ridged(pf * (2.7 * u_scale) + u_seed * 0.37, u_crease);
	float d = m * (0.16 + 1.55 * nb);
	// u_hard is three things: the width of the front, how fast the interior brightens past it, and how much diffuse haze
	// surrounds the mass (a narrow smoothstep alone is invisible against the haze)
	float hardk = clamp(u_hard, 0.0, 1.0);
	float soft = mix(0.34, 0.030, hardk);
	float body = smoothstep(u_thresh - soft, u_thresh + soft, d);
	// thickness: how far past the front, normalized. Brightness and color ride it, which gives a mass an interior.
	// The divisor is generous so thickness does not saturate over the whole core (a flat pale plateau); the interior
	// stays a gradient all the way in.
	float thick = clamp((d - u_thresh) / 1.10, 0.0, 1.0);

	// --- LIGHT ---
	vec2 lv = u_light - p;
	vec2 ldir = normalize(lv + vec2(1e-5, 0.0));
	float occ = env(pw2 + ldir * 0.10) * 0.62 + env(pw2 + ldir * 0.24) * 0.38;
	float lit = exp(-u_shadow * occ);
	float lamp = 1.0 / (1.0 + 1.9 * dot(lv, lv));         // the lamp's own falloff
	float shade = 0.26 + 1.05 * lit * (0.45 + 0.80 * lamp);
	// a filament lying crossways to the lamp catches it; `nb` is high on the creases, so this rides the threads
	float sheen = pow(1.0 - abs(dot(dir, ldir)), 4.0) * smoothstep(0.45, 0.95, nb) * lit;

	// --- COLOR: chromatic DEPTH ---
	// the fringe of a mass is not a dimmer version of its middle: a thin edge takes the scheme's second hue and the core
	// keeps its own, and the hottest creases bleach toward white
	vec3 edge = mix(chroma, u_rim, 0.60);
	vec3 col = mix(edge, chroma, smoothstep(0.0, 0.55, thick));
	float hot = smoothstep(0.68, 1.15, thick * (0.5 + 0.9 * shade));
	col = mix(col, mix(chroma, vec3(1.0), 0.45), hot);
	col += u_rim * sheen * 0.55;

	// The emission: the lit body, brightening with thickness and creased by the field that cuts its edge, plus an
	// unthresholded haze so the masses sit in their own glow (it carries most of the diffuse color and keeps a hard
	// front from reading as a decal).
	float glow = body * (0.26 + 0.80 * pow(thick, mix(1.15, 0.50, hardk))) * (0.55 + 0.85 * nb);
	// The front glint: a band of extra light at the boundary, only for a hard mass (backscatter makes the leading edge
	// of lit vapor brighter than its interior). Kept modest: stronger, it draws every wobble of the level set as a line.
	float band = exp(-pow((d - u_thresh) / mix(0.30, 0.075, hardk), 2.0));
	glow += 0.42 * hardk * band * (0.30 + 0.70 * lit) * smoothstep(0.05, 0.45, m);
	vec3 emit = col * glow * shade
		+ chroma * (u_haze * m * (0.35 + 0.75 * nb) * (0.40 + 0.60 * lit) * mix(2.1, 1.15, hardk));
	// the music's whole claim on the picture is brightness: a beat lifts the plume it landed on (plume_glow) and the
	// transient lifts the frame a little (u_burst); neither moves anything
	emit *= u_gain * (1.0 + 0.30 * u_burst) * (1.0 + 0.55 * plume_glow);
	// A soft shoulder, on luminance: additive light over a color bed has no ceiling. Compressing per channel washes the
	// core toward gray (the channel nearest the ceiling is compressed hardest); one luminance-derived factor keeps hue
	// and saturation and only lowers the level.
	float lum = dot(emit, vec3(0.299, 0.587, 0.114));
	emit *= 1.0 / (1.0 + 0.55 * lum);
	// ... and a small saturation push after it: compression plus additive overlap still walks the brightest masses toward
	// cream
	float lum2 = dot(emit, vec3(0.299, 0.587, 0.114));
	emit = mix(vec3(lum2), emit, 1.28);

	// Alpha 1 with blend_add (src.rgb * src.a + dst): the emission adds as computed and the
	// scene's fade - which rides in COLOR.a - scales it linearly.
	COLOR = vec4(emit, 1.0) * fade;
}
