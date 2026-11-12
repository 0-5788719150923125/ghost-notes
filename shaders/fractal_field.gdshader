shader_type canvas_item;

// Fractal field - the escape-time set [scenes/fractal_zoom.gd] flies through.
//
// One quad, one fragment program, the whole frame: every pixel iterates its own orbit.
//
// Perturbation. Iterating `z = z*z + c` directly in float32 stops resolving below a half-height of about 3e-4 (a
// magnification of five thousand from 1.5). Instead one reference orbit is iterated at high precision (CPU, float64 -
// see the scene's _reference) and the shader holds only the difference from it:
//
//     Z(n+1) = Z(n)^2 + C          <- the reference, computed once, uploaded as a texture
//     d(n+1) = 2 Z(n) d(n) + d(n)^2 + dc
//     z(n)   = Z(n) + d(n)
//
// `d` is tiny and float32 measures it relatively, so the pixel offset survives to depths float32 cannot hold absolutely;
// the reference itself is stored as float32, which is fine because an error in Z perturbs `d` by a relative amount.
//
// Rebasing (Zhuoran's) avoids glitch blobs where the true orbit passes near zero: whenever |z| < |d|, restart the
// reference from its beginning with d = z. It also covers running off the end of a reference that escaped. The
// reference must therefore start at Z(0) = 0, which the Mandelbrot's does.
//
// Perturbation is for the quadratic Mandelbrot only: the other families need their own formula (the burning ship's
// absolute values do not linearize, and rebasing a Julia set is invalid because its reference does not start at zero),
// and they do not need the depth. The scene knows which path it is on and clamps its zoom range to match (its ZOOM FLOOR).
//
// The range of looks: six families (mandelbrot, julia, burning ship, tricorn, celtic, buffalo), each a pre- or
// post-transform on the same iteration, times an integer power, six colorings (smooth escape, stripe average, three
// orbit traps, exterior distance), a palette ramp built on the CPU from a [Scheme], and an interior treatment.

// The reference orbit, one texel per iteration, (Zx, Zy) in RG float32. Bound only when
// u_perturb is on; ignored otherwise.
uniform sampler2D u_orbit : filter_nearest, repeat_disable;
// The palette, 256x1, built by the scene from its Scheme. Sampled with fract(), so it cycles.
uniform sampler2D u_ramp : filter_linear_mipmap, repeat_enable;

uniform int u_ref_len = 0;                 // usable texels in u_orbit
uniform bool u_perturb = false;

// 0 mandelbrot, 1 julia, 2 burning ship, 3 tricorn, 4 celtic, 5 buffalo
uniform int u_family = 0;
uniform int u_power = 2;
uniform vec2 u_julia = vec2(-0.8, 0.156);

uniform vec2 u_center = vec2(0.0);         // the direct path's center (perturbation uses the orbit)
uniform float u_scale = 1.5;               // half-HEIGHT of the view, in complex units
uniform float u_rot = 0.0;
uniform vec2 u_half = vec2(0.9, 0.55);     // quad half-extents in unit fractions

uniform int u_iter = 400;
uniform float u_bail = 256.0;              // squared escape radius

// 0 smooth, 1 stripe average, 2 point trap, 3 cross trap, 4 circle trap, 5 distance estimate
uniform int u_color = 0;
uniform vec2 u_trap_p = vec2(0.0);
uniform float u_trap_r = 0.6;
uniform float u_stripe = 5.0;

uniform float u_cycle = 0.06;              // palette turns per iteration
uniform float u_phase = 0.0;
uniform int u_interior = 0;                // 0 flat, 1 tinted by how close the orbit came, 2 trap
uniform vec3 u_in_col = vec3(0.02, 0.02, 0.05);
uniform float u_gain = 1.0;
uniform float u_glow = 0.0;                // beat brightness, added late
uniform float u_vig = 0.25;

vec2 cmul(vec2 a, vec2 b) { return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x); }

// z^p for a small integer p, by repeated multiplication (p is a uniform, so every pixel takes the same trip).
vec2 cpowi(vec2 z, int p) {
	vec2 r = z;
	for (int i = 1; i < p; i++) {
		r = cmul(r, z);
	}
	return r;
}

// The family, as a transform BEFORE the power (the burning ship folds the plane into its
// positive quadrant, the tricorn conjugates) ...
vec2 fam_pre(vec2 z) {
	if (u_family == 2 || u_family == 5) { return vec2(abs(z.x), abs(z.y)); }
	if (u_family == 3) { return vec2(z.x, -z.y); }
	return z;
}

// ... and one AFTER it (the celtic and the buffalo fold the result's real part).
vec2 fam_post(vec2 z) {
	if (u_family == 4 || u_family == 5) { return vec2(abs(z.x), z.y); }
	return z;
}

// Every orbit trap this file offers, as one distance: a trap colors a pixel by how close its orbit came to a shape
// rather than by how long it took to leave.
float trap_of(vec2 z) {
	if (u_color == 2) { return length(z - u_trap_p); }
	if (u_color == 3) { return min(abs(z.x - u_trap_p.x), abs(z.y - u_trap_p.y)); }
	if (u_color == 4) { return abs(length(z - u_trap_p) - u_trap_r); }
	return 1e20;
}

void fragment() {
	vec4 fade = COLOR;                  // white quad x the scene's modulate: the Director's fade

	// Pixel -> complex plane. Dividing by u_half.y makes u_scale mean half the frame's height at any aspect or resolution.
	vec2 q = (UV - 0.5) * 2.0 * u_half;
	float cr = cos(u_rot);
	float sr = sin(u_rot);
	vec2 d = vec2(q.x * cr - q.y * sr, q.x * sr + q.y * cr) * (u_scale / max(1e-6, u_half.y));

	float it = 0.0;                     // smooth iteration count at escape
	bool escaped = false;
	float trap = 1e20;
	float stripe = 0.0;
	float stripe_prev = 0.0;
	float stripe_n = 0.0;
	// Both cost time inside the loop (an atan a step for the stripe, a length a step for the trap) and most colorings
	// read neither; the tests are on uniforms, so every pixel takes the same branch and the cost is skipped.
	bool want_stripe = (u_color == 1);
	bool want_trap = (u_color >= 2 && u_color <= 4) || (u_interior != 0);
	float dist = 0.0;                   // exterior distance estimate
	vec2 z = vec2(0.0);

	if (u_perturb) {
		// --- PERTURBED: quadratic Mandelbrot, arbitrarily deep. See the header.
		vec2 dz = d;
		int n = 0;
		for (int i = 0; i < u_iter; i++) {
			vec2 Z = texelFetch(u_orbit, ivec2(min(n, u_ref_len - 1), 0), 0).xy;
			dz = 2.0 * cmul(Z, dz) + cmul(dz, dz) + d;
			n++;
			vec2 Zn = texelFetch(u_orbit, ivec2(min(n, u_ref_len - 1), 0), 0).xy;
			z = Zn + dz;
			float zz = dot(z, z);
			if (want_trap) { trap = min(trap, trap_of(z)); }
			if (want_stripe) {
				stripe_prev = stripe_n < 1.0 ? 0.0 : stripe / stripe_n;
				stripe += 0.5 + 0.5 * sin(u_stripe * atan(z.y, z.x));
				stripe_n += 1.0;
			}
			if (zz > u_bail) {
				it = float(i) + 1.0 - log2(0.5 * log(zz));
				escaped = true;
				break;
			}
			// Rebase: the running z is a better delta than dz whenever it is smaller, and the
			// reference has to restart before it runs off its own end.
			if (zz < dot(dz, dz) || n >= u_ref_len - 1) {
				dz = z;
				n = 0;
			}
		}
	} else {
		// --- DIRECT: every family, every power, at the depth float32 can hold.
		vec2 c = (u_family == 1) ? u_julia : (u_center + d);
		z = (u_family == 1) ? (u_center + d) : vec2(0.0);
		vec2 dv = vec2(1.0, 0.0);       // d z / d(parameter), for the distance estimate
		for (int i = 0; i < u_iter; i++) {
			if (u_color == 5) {
				// (z^p)' = p z^(p-1); the +1 is dc/dc and is absent for a Julia set, whose
				// parameter is the starting point rather than the constant.
				vec2 dp = cmul(cpowi(z, u_power - 1) * float(u_power), dv);
				dv = (u_family == 1) ? dp : dp + vec2(1.0, 0.0);
			}
			z = fam_post(cpowi(fam_pre(z), u_power)) + c;
			float zz = dot(z, z);
			if (want_trap) { trap = min(trap, trap_of(z)); }
			if (want_stripe) {
				stripe_prev = stripe_n < 1.0 ? 0.0 : stripe / stripe_n;
				stripe += 0.5 + 0.5 * sin(u_stripe * atan(z.y, z.x));
				stripe_n += 1.0;
			}
			if (zz > u_bail) {
				it = float(i) + 1.0 - log(0.5 * log(zz)) / log(float(u_power));
				escaped = true;
				// Koebe's estimate: how far this point is from the set, in plane units.
				dist = sqrt(zz) * log(zz) * 0.5 / max(1e-12, length(dv));
				break;
			}
		}
	}

	// The palette coordinate is computed for every pixel before anything branches on whether it escaped: it feeds a
	// screen-space derivative, which is undefined inside per-pixel control flow.
	float t = u_phase;
	if (u_color == 1) {
		// Stripe average: the running mean of a sinusoid of the orbit's angle; it draws the flow around the set and
		// finds structure inside what the smooth count renders flat. Interpolated between the mean before and after
		// the last step by the fractional escape, which removes the band boundary.
		float avg = stripe / max(1.0, stripe_n);
		float d = fract(it);
		t += u_cycle * (0.35 * it + 22.0 * mix(stripe_prev, avg, d));
	} else if (u_color == 5) {
		// Distance: how far the pixel is from the set in units of its own pixel size; near-set pixels go bright, so
		// the boundary draws as a filament.
		t += u_cycle * 40.0 * clamp(log(1.0 + dist / max(1e-12, u_scale * 0.004)) * 0.32, 0.0, 1.0);
	} else if (u_color >= 2) {
		t += 1.4 * exp(-2.2 * min(trap, 8.0));
	} else {
		t += u_cycle * it;
	}

	// Antialiasing: near the boundary the palette repeats several times across one pixel, so point-sampling returns
	// noise. The ramp is one dimensional, so the average of the colors a pixel spans is a lower mip of it and `fwidth`
	// says how many texels that is: one texture read, no extra iterations, the same answer as a 16x supersample.
	float lod = log2(max(1.0, fwidth(t) * 256.0));

	vec3 col;
	if (!escaped) {
		// The interior: flat reads as a hole, right on a wide view; deep in, the frame can be mostly interior and
		// how close the orbit came to the trap is the only structure there is (modes 1 and 2).
		col = u_in_col;
		if (u_interior == 1) {
			col = u_in_col * (0.35 + 1.6 * exp(-3.0 * min(trap, 4.0)));
		} else if (u_interior == 2) {
			col = textureLod(u_ramp,
				vec2(fract(u_phase + 0.5 * exp(-2.0 * min(trap, 6.0))), 0.5), lod).rgb * 0.55;
		}
	} else {
		col = textureLod(u_ramp, vec2(fract(t), 0.5), lod).rgb;
		if (u_color == 5) {
			col *= clamp(1.35 - log(1.0 + dist / max(1e-12, u_scale * 0.004)) * 0.30, 0.0, 1.4);
		}
	}

	col *= u_gain;
	col += col * u_glow;
	// A gentle vignette, because a full-bleed field with a hard frame edge reads as a texture
	// swatch; darkening the corners makes it read as a window onto something larger.
	float r = length(q / max(u_half, vec2(1e-4)));
	col *= 1.0 - u_vig * smoothstep(0.55, 1.45, r);
	COLOR = vec4(col, fade.a);
}
