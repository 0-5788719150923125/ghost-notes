shader_type canvas_item;

// Stage filter - the whole show put through a look, in one pass.
//
// This runs on main's stage view: the single TextureRect that presents the SubViewport every scene draws into (see
// [Filters], which owns the registry and hangs this material here). TEXTURE is the finished frame - every scene, every
// layer, the medium's comic page - and nothing above it on a CanvasLayer is touched, so the karaoke line and the panels
// stay readable.
//
// Eight filters, one fragment, in a fixed order, each with its own 0..1 amount and each an exact no-op at 0. The order
// is the one in Filters.REGISTRY:
//
//   0. Gate slip moves where the picture is sampled, so it comes before anything reads it.
//   1. Pointillism re-samples the picture into dots, so everything below grades the dots.
//   2. Bloom is what a lens does, so it goes before the grade.
//   3. Monochrome, then 4. noir: noir grades whatever it is handed, so monochrome above it is black-and-white noir.
//   5. Static is the emulsion's own noise the graded light is exposed onto.
//   6. Dust is dirt on the print - specks, hairs, scratches - so it goes over the image.
//   7. Vignette is the frame, last because it darkens everything including the dust.
//
// Cost: the only filter with real fill cost is pointillism (nine taps for the neighborhood).
// Nothing here reads the audio: a look is a decision about the photograph, and a look that pumped on the beat would be
// a scene effect.

// The frame's size in pixels. The dot lattice and the grain are sized in device pixels, not UV, so a render at another
// resolution is the same picture.
uniform vec2 u_size = vec2(1920.0, 1080.0);

uniform float u_slip : hint_range(0.0, 1.0) = 0.0;
uniform float u_pointillism : hint_range(0.0, 1.0) = 0.0;
uniform float u_bloom : hint_range(0.0, 1.0) = 0.0;
uniform float u_monochrome : hint_range(0.0, 1.0) = 0.0;
uniform float u_noir : hint_range(0.0, 1.0) = 0.0;
uniform float u_static : hint_range(0.0, 1.0) = 0.0;
uniform float u_dust : hint_range(0.0, 1.0) = 0.0;
uniform float u_vignette : hint_range(0.0, 1.0) = 0.0;
// The film frame to show, or negative for the shader's own clock. Not a filter: a still render cannot reach the one
// frame in several that slips, and a gate has to.
uniform int u_frame = -1;

// Rec. 709 luma, not the channel average (which maps a saturated red and green of equal brightness to the same gray).
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

// Grain and the gate both re-roll at a film's rate, so the noise does not shimmer faster on a fast frame.
const float FILM_FPS = 24.0;
// How often the transport misbehaves at the top of the Gate slip dial: a share of film frames.
const float GATE_MAX = 0.22;
// How heavy the grain field's tail is; higher is sparser: the exponent is applied to a signed noise centered on zero.
const float GRAIN_TAIL = 3.4;
// ...and what a surviving grain is worth: the amplitude of the few. Grain modulates the picture (at 2.3 the specks clip
// to pure white and black); a strong grain moves the luminance it sits on by about a fifth.
const float GRAIN_GAIN = 0.30;

float luma(vec3 c) {
	return dot(c, LUMA);
}

// A cheap deterministic hash, the integer-mixing kind (Hoskins), not `fract(sin(dot(...)))`: sin() is smooth, so nearby
// inputs correlate along the dot product's gradient and grain built on it draws a diagonal crosshatch; it also loses
// precision on large inputs.
//
// TEXTURE is only bound inside fragment(), so the two filters that re-sample the picture take the sampler as a
// parameter. That costs one harmless engine line at compile time:
// `Condition "!actions.custom_samplers.has(...)" is true. Continuing.`
float hash1(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 hash2(vec2 p) {
	return vec2(hash1(p), hash1(p + vec2(37.2, 11.7)));
}

// Smooth value noise on an integer lattice, for the grain's mottle (a hash sampled coarsely is visible blocks).
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), f.x),
		mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Gate slip: a band of the picture displaced sideways for one frame, then back. A transport property, not an emulsion
// one: a frame that does not seat squarely in the gate is printed offset until the mechanism pulls it back. The dial
// is how often, and how far. It moves the sampling position, so it runs before anything reads the texture.
vec2 gate_slip(vec2 uv, float amount) {
	float chance = amount * GATE_MAX;
	float t = u_frame >= 0 ? float(u_frame) : floor(TIME * FILM_FPS);
	if (hash1(vec2(t, 3.7)) > chance) {
		return uv;
	}
	// a band, not the whole frame: the film buckles across part of the gate
	float y0 = hash1(vec2(t, 11.3));
	float h = mix(0.05, 0.40, hash1(vec2(t, 19.1)));
	if (uv.y < y0 || uv.y > y0 + h) {
		return uv;
	}
	float shift = (hash1(vec2(t, 23.7)) - 0.5) * mix(3.0, 30.0, amount) / max(u_size.x, 1.0);
	return vec2(clamp(uv.x + shift, 0.0, 1.0), uv.y);
}

// --- 1. POINTILLISM ----------------------------------------------------------------------
//
// The picture re-laid as overlapping dots of paint. The cell centers are jittered and the dots may overlap (a regular
// lattice of discs reads as a halftone print); each dot takes its color from its own center and its radius from how
// bright that is.
//
// The neighborhood matters: at this dot size the dot covering a pixel is often the one from the next cell, so the 3x3
// cells around the pixel are tested and the nearest covering dot wins (asking only its own cell leaves a hard gap around
// every dot). Nine taps are this filter's entire cost.
//
// The ground between the dots is the containing cell's own color, well dimmed: a dark ground keeps a night scene legible.
vec3 pointillism(sampler2D tex, vec2 uv, vec3 src, float amount) {
	vec2 px = uv * u_size;
	// the dot pitch, in pixels: from a canvas tooth up to a painting you stand back from
	float cell = mix(3.0, 22.0, amount);
	vec2 id = floor(px / cell);
	vec3 col = src;
	float best = 1e9;
	vec3 ground = src;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 nid = id + vec2(float(i), float(j));
			// +-0.35 of a cell: no row of dots lines up, and no dot leaves the cells this loop looks at
			vec2 c = (nid + 0.5 + (hash2(nid) - 0.5) * 0.7) * cell;
			vec3 tap = texture(tex, clamp(c / u_size, vec2(0.0), vec2(1.0))).rgb;
			if (i == 0 && j == 0) {
				ground = tap * 0.22;
			}
			// a bright dab is a fatter dab; the floor keeps the dark half of the picture from dissolving into bare ground
			float r = cell * 0.5 * (0.45 + 0.75 * luma(tap)) * (0.8 + 0.4 * hash1(nid + 5.0));
			float d = length(px - c) - r;
			if (d < best) {
				best = d;
				col = tap;
			}
		}
	}
	// one pixel of softness on the rim
	float cover = 1.0 - smoothstep(-1.0, 1.0, best);
	return mix(src, mix(ground, col, cover), amount);
}

// --- 2. BLOOM ----------------------------------------------------------------------------
//
// Light bleeding out of the bright parts: only what is already above the picture's highlights blooms (a threshold, not
// a blur added to everything).
//
// Eight taps on a ring rather than a separable gaussian: a glow, not a defocus, so no second render target.
vec3 bloom(sampler2D tex, vec2 uv, vec3 src, float amount) {
	float radius = mix(2.0, 14.0, amount) / max(u_size.y, 1.0);
	vec3 sum = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853981634;   // TAU / 8
		// two rings in one loop: the odd taps sit at twice the radius, spreading the falloff without more samples
		float rr = radius * (float(i % 2) + 1.0);
		vec2 off = vec2(cos(a), sin(a)) * rr * vec2(u_size.y / max(u_size.x, 1.0), 1.0);
		vec3 tap = texture(tex, clamp(uv + off, vec2(0.0), vec2(1.0))).rgb;
		sum += max(tap - vec3(0.62), vec3(0.0));
	}
	return src + sum * (amount * 0.55);
}

// --- 3. MONOCHROME ------------------------------------------------------------------------
vec3 monochrome(vec3 src, float amount) {
	return mix(src, vec3(luma(src)), amount);
}

// --- 4. NOIR ------------------------------------------------------------------------------
//
// The hard grade: an S-curve closes the blacks and burns the highlights; a little of the remaining color is pulled out;
// and the shadows go cold against warm highlights (the split-tone).
vec3 noir(vec3 src, float amount) {
	float l = luma(src);
	// smoothstep is the S-curve; its ends move inward with the amount, so the dial is the width of the tonal range kept
	float lo = mix(0.0, 0.34, amount);
	float hi = mix(1.0, 0.66, amount);
	float curved = smoothstep(lo, hi, l);
	// re-apply the original chroma around the new luma so the curve cannot shift a channel's hue
	vec3 graded = src + vec3(curved - l);
	graded = mix(graded, vec3(curved), amount * 0.45);
	vec3 cold = vec3(0.82, 0.90, 1.12);
	vec3 warm = vec3(1.10, 1.02, 0.86);
	graded *= mix(cold, warm, curved);
	return mix(src, clamp(graded, vec3(0.0), vec3(4.0)), amount);
}

// --- 5. GRAIN ----------------------------------------------------------------------------
//
// Film emulsion. Per-pixel white noise is television static, not film; four things make grain read as film:
//
//   Grain has a size: clumps of developed silver, so the noise is sampled on a lattice a few pixels across, in two
//   octaves so the clumps have structure of their own.
//
//   Grain is sparse: scattered specks with almost nothing between them. Raising the signed noise to a power gives the
//   heavy tail a real grain field has.
//
//   It is unevenly dense: regions grainier than their neighbors, drifting slowly.
//
//   It is in the midtones: none in a black that exposed nothing or a highlight that exposed completely, so a flat
//   noise floor must not fog the blacks.
vec3 static_noise(vec2 uv, vec3 src, float amount) {
	vec2 px = uv * u_size;
	// wrapped so the counter stays small enough for the hash's precision (the noise would repeat and band)
	float t = mod(u_frame >= 0 ? float(u_frame) : floor(TIME * FILM_FPS), 1024.0);
	vec2 drift = vec2(t * 41.0, t * 17.0);

	// size, not on a lattice: smooth value noise gives clumps of one size with nothing to align to (flooring a hash
	// onto cells draws a visible grid)
	float gsz = mix(1.6, 3.2, amount);
	float n = vnoise(px / gsz + drift) * 0.62
		+ vnoise(px / (gsz * 0.45) + drift.yx) * 0.38;

	// sparse: smooth noise clusters around its middle, so signing it and raising it to a power leaves most of the frame
	// near nothing and lets the few grains that land stand clear
	float sn = n * 2.0 - 1.0;
	sn = sign(sn) * pow(abs(sn), GRAIN_TAIL);

	// mottle: whole regions grainier than their neighbors, drifting slowly; anisotropic and in frame units, so it is
	// not circular and does not change scale with the window
	float m = vnoise(uv * vec2(5.0, 3.0) + vec2(t * 0.011, t * -0.008));
	float density = 0.06 + 1.9 * smoothstep(0.34, 0.86, m);

	// ...and the exposure weight, peaking at mid-gray and vanishing at both ends.
	float l = luma(src);
	float weight = 4.0 * l * (1.0 - l);
	return src + vec3(sn * amount * GRAIN_GAIN * density * weight);
}

// --- 6. VIGNETTE -------------------------------------------------------------------------
//
// An oval fitted to the frame: the distance is `length` of the position scaled so the middle of every edge is 1 and the
// corners are sqrt(2). It comes in from all four sides at once, heaviest in the corners, an oval on a widescreen frame
// (a circle from the optical axis darkens the sides long before the top; an inset rounded rectangle looks square).
//
// A vignette is dark, not tinted: the depth saturates early (0.3 is two-thirds dark, 0.5 nearly black) and the dial's
// travel is mostly reach - both ends of the falloff move inward with it, so the top of the range is solid black at every
// edge.
vec3 vignette(vec2 uv, vec3 src, float amount) {
	float r = length((uv - vec2(0.5)) * 2.0);
	float depth = 1.0 - pow(1.0 - amount, 3.0);
	return src * (1.0 - depth * smoothstep(mix(0.85, 0.25, amount), mix(1.25, 0.95, amount), r));
}


// --- 6. DUST ------------------------------------------------------------------------------
//
// Dirt on the print: specks of dust, the odd curled hair, and now and then a scratch running down the frame. All of it
// re-rolls at the film's rate, because the dirt is on the frame going through the gate. Specks are mostly dark (dust on
// the print blocks light) with some light (dust on the negative prints white); a scratch is light and lasts a few
// frames, wandering a little.
// The dial is how often it happens as much as how strongly it shows: each of DUST_MAX slots is present on a frame only
// by chance, at amount^2.5, so 0.05 is a speck every few seconds, the default is a couple a frame, and 1.0 is all of them.
const float DUST_MAX = 14.0;
const int HAIR_STEPS = 8;

// Distance from p to the segment a-b, and how far along it the nearest point is (0..1).
vec2 seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	return vec2(length(p - (a + ab * t)), t);
}

vec3 dust(vec2 uv, vec3 src, float amount) {
	vec2 px = uv * u_size;
	float frame = u_frame >= 0 ? float(u_frame) : floor(TIME * FILM_FPS);
	float k = max(u_size.y, 1.0) / 1080.0;       // everything is sized for a 1080-tall frame
	float dark = 0.0;
	float light = 0.0;
	float chance = pow(amount, 2.5);
	for (int i = 0; i < int(DUST_MAX); i++) {
		vec2 s = vec2(frame * 13.1 + float(i) * 7.7, float(i) * 3.3 + 1.7);
		if (hash1(s + vec2(0.0, 29.0)) >= chance) {
			continue;
		}
		vec2 c = vec2(hash1(s), hash1(s + vec2(19.2, 0.0))) * u_size;
		float m = 0.0;
		if (hash1(s + vec2(5.1, 0.0)) < 0.82) {
			// a speck: a small irregular blob, most of them tiny
			vec2 d = px - c;
			float ang = atan(d.y, d.x);
			float rr = mix(1.2, 5.0, pow(hash1(s + vec2(8.3, 0.0)), 2.2)) * k;
			rr *= 1.0 + 0.3 * sin(ang * 3.0 + hash1(s + vec2(2.0, 0.0)) * 6.2832) + 0.15 * sin(ang * 5.0);
			m = 1.0 - smoothstep(rr - 0.7, rr + 0.7, length(d));
		} else if (length(px - c) < float(HAIR_STEPS) * 26.0 * k) {
			// a hair: a jagged random walk, not an arc; each step turns a little either way with a slight curl the whole
			// hair shares, and now and then it kinks hard
			float ang = hash1(s + vec2(4.4, 0.0)) * 6.2832;
			float curl = (hash1(s + vec2(6.6, 0.0)) - 0.5) * 0.7;
			float step_len = mix(7.0, 17.0, hash1(s + vec2(7.7, 0.0))) * k;
			vec2 a = c;
			float best = 1e9;
			float at = 0.0;
			for (int h = 0; h < HAIR_STEPS; h++) {
				float fh = float(h);
				float r = hash1(s + vec2(20.0 + fh, 3.0));
				ang += curl + (r - 0.5) * 0.9;
				if (hash1(s + vec2(40.0 + fh, 5.0)) < 0.3) {
					ang += sign(r - 0.5) * mix(1.0, 2.4, hash1(s + vec2(50.0 + fh, 7.0)));
				}
				vec2 b = a + vec2(cos(ang), sin(ang)) * step_len * mix(0.4, 1.5, hash1(s + vec2(60.0 + fh, 9.0)));
				vec2 st = seg_dist(px, a, b);
				if (st.x < best) {
					best = st.x;
					at = (fh + st.y) / float(HAIR_STEPS);
				}
				a = b;
			}
			float w = mix(0.5, 1.2, hash1(s + vec2(9.9, 0.0))) * k;
			// thinner toward its ends, as a hair is
			w *= 0.35 + 0.65 * sin(3.14159 * at);
			m = 1.0 - smoothstep(w, w + 0.8, best);
		}
		if (hash1(s + vec2(11.0, 0.0)) < 0.78) {
			dark = max(dark, m);
		} else {
			light = max(light, m);
		}
	}
	// SCRATCHES, held for half a second at a time and wandering a pixel or two frame to frame
	float seg = floor(frame / 12.0);
	for (int j = 0; j < 2; j++) {
		vec2 s = vec2(seg * 3.7 + float(j) * 17.0, 41.0);
		if (hash1(s) > chance * 0.7) {
			continue;
		}
		float x = hash1(s + vec2(1.0, 0.0)) * u_size.x + (hash1(vec2(frame, float(j) + 3.0)) - 0.5) * 3.0 * k;
		float w = mix(0.5, 1.3, hash1(s + vec2(2.0, 0.0))) * k;
		float along = vnoise(vec2(float(j) * 7.0 + seg, px.y / (70.0 * k)));
		float m = (1.0 - smoothstep(w, w + 0.8, abs(px.x - x))) * smoothstep(0.35, 0.6, along);
		light = max(light, m * 0.8);
	}
	vec3 c = mix(src, src * 0.2, dark * mix(0.55, 0.95, amount));
	return mix(c, vec3(0.93, 0.91, 0.86), light * mix(0.35, 0.8, amount));
}


void fragment() {
	// the gate slip moves the sampling position, so it happens before anything reads the texture (pointillism and
	// bloom take their own taps); everything below works in `uv` rather than UV for that reason
	vec2 uv = UV;
	if (u_slip > 0.0) {
		uv = gate_slip(uv, u_slip);
	}
	vec4 tex = texture(TEXTURE, uv);
	vec3 c = tex.rgb;
	// each filter is skipped outright at zero rather than multiplied by zero: pointillism and bloom are nine and eight taps
	if (u_pointillism > 0.0) {
		c = pointillism(TEXTURE, uv, c, u_pointillism);
	}
	if (u_bloom > 0.0) {
		c = bloom(TEXTURE, uv, c, u_bloom);
	}
	if (u_monochrome > 0.0) {
		c = monochrome(c, u_monochrome);
	}
	if (u_noir > 0.0) {
		c = noir(c, u_noir);
	}
	if (u_static > 0.0) {
		c = static_noise(uv, c, u_static);
	}
	if (u_dust > 0.0) {
		c = dust(uv, c, u_dust);
	}
	if (u_vignette > 0.0) {
		c = vignette(uv, c, u_vignette);
	}
	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), tex.a);
}
