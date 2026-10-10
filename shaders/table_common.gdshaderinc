// What the table's own surfaces share (see src/tables.gd): the top (table_top.gdshader) and every
// layer laid on it (table_textile.gdshader). A surface is drawn in its own FLAT space - UV is
// centimeters from its middle before it is draped over the table's edge, UV2.x how far in from its
// hem - so a pattern keeps its size and a border runs along the hem wherever the cloth hangs.
//
//   THE PATTERN   it is woven in (a layer) or inlaid with (a top): stripes, checks, a plaid,
//                 diamonds, dots, a medallion, soft dyed clouds, ikat - or the episode's painting
//   THE RELIEF    a height field under the surface, in millimeters, never above it (0 is the
//                 surface, where the cards and the things rest): a weave's threads or a wood's
//                 grain, the pattern's figures raised or sunk, quilting, tufting, the painting's
//                 own detail. SEEN by its slope at every pixel (a normal from the field itself, not
//                 the screen's 2x2 derivative of it), by PARALLAX (the hollows lie below the
//                 surface as the eye moves) and by their shade (ambient occlusion). Godot 4 has no
//                 tessellation, and lifting the geometry would lift the cards off it or sink them
//                 into it; the drape over the edge and the top's carved edge are real geometry.
//
// Included first; the shader then defines `float natural(vec2 p, float aa)` (its material's own
// relief, in [-1, 0]) and includes table_relief.gdshaderinc.

#include "res://shaders/noise_common.gdshaderinc"

// Tables.PATTERNS: 0 plain, 1 stripes, 2 checks, 3 plaid, 4 diamonds, 5 dots, 6 medallion,
// 7 clouds, 8 ikat, 9 painting
uniform int pattern = 0;
uniform vec3 colors[6];                 // linear: an array takes no source_color conversion
uniform int ncolors = 1;
uniform float pat_scale = 8.0;          // centimeters
uniform float pat_turn = 0.0;           // radians
uniform float pat_count = 8.0;          // a medallion's symmetry
uniform float pat_seed = 0.0;
uniform vec2 half_size = vec2(60.0, 36.0);   // half the surface's flat extent, cm: the painting spans it
uniform float border = 0.0;             // a band along the hem: its width, cm (0: none)
uniform float border_inset = 0.0;       // ...how far in from the hem, cm
uniform vec3 border_color : source_color = vec3(0.8, 0.65, 0.3);
uniform sampler2D painting : source_color, filter_linear_mipmap, repeat_disable;
uniform float has_painting = 0.0;
uniform vec4 crop = vec4(0.0, 0.0, 1.0, 1.0);   // the part of the painting laid here: offset, size (UV)
// THE PAINTER'S HEIGHT MAP of the painting (Tables.height_fit), when one lined up with it: white
// highest; read at the painting's own UV plus its shift
uniform sampler2D height_map : filter_linear_mipmap, repeat_disable;
uniform float has_height = 0.0;
uniform vec2 height_shift = vec2(0.0);
// Tables.RELIEFS: 0 none, 1 natural (the material's own alone), 2 raised, 3 sunk, 4 quilted,
// 5 tufted, 6 painting
uniform int relief = 1;
uniform float relief_depth = 0.6;       // millimeters, the relief's own
uniform float relief_scale = 6.0;       // centimeters: a quilt's diamond, a tuft's spacing
uniform float relief_invert = 0.0;      // the painting's dark parts stand up instead
uniform float natural_depth = 0.2;      // millimeters, the material's own (threads, grain)

vec2 rot2(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

int wrap(int i) {
	int n = max(ncolors, 1);
	return ((i % n) + n) % n;
}

vec3 pal(int i) {
	return colors[wrap(i)];
}

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float h1(float x) {
	return fract(sin(x * 127.1 + pat_seed * 13.7) * 43758.5453);
}

// THE BAND x falls in, bands [param s] wide, and how far it has turned into the next at a band's
// edge: (the band below the nearest edge, the blend into the one above it). [param aa] is a pixel's
// width there, cm - an edge is that soft, so it never crawls.
vec2 bands(float x, float s, float aa) {
	float f = x / s;
	float b = floor(f + 0.5);
	return vec2(b - 1.0, smoothstep(-aa, aa, (f - b) * s));
}

// A TARTAN'S SETT: the band [param x] falls in - every color in turn, each its own width (drawn from
// the seed), then back again, mirrored, as a sett is woven.
int sett(float x) {
	int n = max(ncolors, 1);
	float total = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i < n) {
			total += pat_scale * (0.35 + 1.3 * h1(float(i)));
		}
	}
	float u = mod(x, 2.0 * total);
	if (u > total) {
		u = 2.0 * total - u;
	}
	float acc = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i < n) {
			acc += pat_scale * (0.35 + 1.3 * h1(float(i)));
			if (u < acc) {
				return i;
			}
		}
	}
	return n - 1;
}

vec2 painting_uv(vec2 p) {
	return crop.xy + (p / (2.0 * max(half_size, vec2(0.1))) + 0.5) * crop.zw;
}

// A MAP READ WHOSE SLOPE IS SMOOTH. The relief's normal is the slope of what a map holds, and
// a bilinear read has one constant slope in every texel and a jump at its edge: up close (a texel
// wider than a pixel) the light then shows the map's own grid as tiny squares - plainest in a low
// light grazing the cloth (feedback 0016). The cubic B-spline read (four bilinear fetches, one
// per pair of texels' weights) is continuous in its slope. It only matters magnified: from a texel
// to the pixel ([param lod] 1) up, the mips are smooth already and it is the plain read. [param up]
// is how many levels coarser than [param lod] the map is read (the broad part of a height).
vec4 smooth_tex(sampler2D tex, vec2 uv, float lod, float up) {
	float level = lod + up;
	if (lod >= 1.0) {
		return textureLod(tex, uv, level);
	}
	vec2 ts = vec2(textureSize(tex, clamp(int(floor(level)), 0, textureQueryLevels(tex) - 1)));
	vec2 c = uv * ts;
	vec2 i = floor(c - 0.5);
	vec2 f = c - 0.5 - i;
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i + 0.5 - 1.0 + w1 / g0) / ts;
	vec2 h1 = (i + 0.5 + 1.0 + w3 / g1) / ts;
	float kx = g0.x / (g0.x + g1.x);
	float ky = g0.y / (g0.y + g1.y);
	vec4 a = mix(textureLod(tex, vec2(h1.x, h0.y), level), textureLod(tex, vec2(h0.x, h0.y), level), kx);
	vec4 b = mix(textureLod(tex, vec2(h1.x, h1.y), level), textureLod(tex, vec2(h0.x, h1.y), level), kx);
	// the last level up to a plain read: no step where the cubic hands over
	return mix(mix(b, a, ky), textureLod(tex, uv, level), lod);
}

// THE PAINTING'S DEPTH, 0..1: the painter's height map when there is one - its fine relief whole, its
// broad rise and fall at half (a map's slow gradient across a cloth would tilt it) - else the
// painting's own DETAIL, its lightness less its lightness blurred, so a weave's threads or a board's
// grain stand up and the broad light and dark of the picture do not (taken whole, as the old cloth's
// relief was, every pale patch was a hill). 0.5 flat. Read smoothly ([method smooth_tex]).
float painting_detail(vec2 p, float lod) {
	vec2 uv = painting_uv(p);
	if (has_height > 0.5) {
		float fine_h = smooth_tex(height_map, uv + height_shift, lod, 0.0).r;
		float broad_h = smooth_tex(height_map, uv + height_shift, lod, 4.0).r;
		return clamp(fine_h - (broad_h - 0.5) * 0.5, 0.0, 1.0);
	}
	float fine = lum(smooth_tex(painting, uv, lod, 0.0).rgb);
	float broad = lum(smooth_tex(painting, uv, lod, 3.5).rgb);
	return clamp(0.5 + (fine - broad) * 3.0, 0.0, 1.0);
}

// THE PATTERN at [param p] (cm, the surface's flat space): its color, and how much of the pattern's
// FIGURE is here (a: 0 the ground, 1 a figure) - what a raised or sunk relief raises or sinks.
vec4 pattern_at(vec2 p, float aa, float lod) {
	vec2 q = rot2(p, pat_turn);
	float s = max(pat_scale, 0.2);
	vec3 c = pal(0);
	float fig = 0.0;
	if (pattern == 1) {
		// STRIPES of every color in turn
		vec2 b = bands(q.x, s, aa);
		c = mix(pal(int(b.x)), pal(int(b.x) + 1), b.y);
		fig = mix(float(wrap(int(b.x)) != 0), float(wrap(int(b.x) + 1) != 0), b.y);
	} else if (pattern == 2) {
		// CHECKS - a gingham: two stripes crossing, the first color where they cross
		vec2 bx = bands(q.x, s, aa);
		vec2 bz = bands(q.y, s, aa);
		float sx = mix(mod(bx.x, 2.0), mod(bx.x + 1.0, 2.0), bx.y);
		float sz = mix(mod(bz.x, 2.0), mod(bz.x + 1.0, 2.0), bz.y);
		c = mix(pal(1), pal(0), (sx + sz) * 0.5);
		fig = sx * sz;
	} else if (pattern == 3) {
		// PLAID - a tartan: the sett both ways, warp and weft showing in turn along a twill
		vec3 warp = pal(sett(q.x));
		vec3 weft = pal(sett(q.y));
		float tw = step(0.5, fract((p.x + p.y) / 0.36));
		tw = mix(tw, 0.5, clamp(aa / 0.12, 0.0, 1.0));
		c = mix(warp, weft, tw);
		fig = float(sett(q.x) != 0) * 0.5 + float(sett(q.y) != 0) * 0.5;
	} else if (pattern == 4) {
		// DIAMONDS - a harlequin, each lozenge its color in turn
		vec2 d = vec2(q.x + q.y, q.x - q.y) / (s * 1.41421);
		int k = int(floor(d.x) + floor(d.y));
		vec2 f = abs(fract(d) - 0.5);
		float edge = (0.5 - max(f.x, f.y)) * s * 1.41421;
		c = pal(k);
		fig = float(wrap(k) != 0);
		// a thread of the ground between them
		c = mix(c, mix(pal(k), pal(k + 1), 0.5), 1.0 - smoothstep(0.0, aa * 1.5, edge));
	} else if (pattern == 5) {
		// DOTS on the ground, rows set off by half
		vec2 cell = q / s;
		float row = floor(cell.y);
		vec2 l = fract(vec2(cell.x + 0.5 * mod(row, 2.0), cell.y)) - 0.5;
		float d = length(l) * s - 0.28 * s;
		float t = 1.0 - smoothstep(-aa, aa, d);
		int k = 1 + int(floor(h1(floor(cell.x + 0.5 * mod(row, 2.0)) * 7.0 + row * 3.0) * float(max(ncolors - 1, 1))));
		c = mix(pal(0), pal(ncolors > 1 ? k : 0), t);
		fig = t;
	} else if (pattern == 6) {
		// A MEDALLION - rings of petals, rays and beads round the middle, each ring its own (from the
		// seed), [param pat_count]-fold; past the last ring, the ground
		float R = length(p) / max(min(half_size.x, half_size.y), 1.0);
		float a = atan(p.y, p.x) + pat_turn;
		float n = max(floor(pat_count), 3.0);
		float band = R * 6.0;
		float k = floor(band);
		float f = fract(band);
		float h = h1(k * 3.1 + 1.0);
		float m = 0.0;
		float ring_aa = aa / max(min(half_size.x, half_size.y), 1.0) * 6.0;
		if (h < 0.33) {
			m = 1.0 - smoothstep(-ring_aa, ring_aa, f - (0.5 + 0.38 * cos(n * a + h * 6.2831)));
		} else if (h < 0.66) {
			float ray = abs(fract(n * a / 6.2831853 + h) - 0.5);
			m = 1.0 - smoothstep(0.18, 0.18 + ring_aa * 2.0 + 0.02, ray);
		} else {
			vec2 bead = vec2((fract(n * 2.0 * a / 6.2831853) - 0.5) * 6.2831853 * R * 6.0 / (n * 2.0), f - 0.5);
			m = 1.0 - smoothstep(0.28 - ring_aa, 0.28 + ring_aa, length(bead));
		}
		// a fine rule between rings
		float rule = 1.0 - smoothstep(0.0, ring_aa * 1.5 + 0.03, min(f, 1.0 - f));
		int ki = int(k);
		c = mix(pal(ki), pal(ki + 1), m);
		c = mix(c, pal(ki + 2), rule * 0.8);
		fig = max(m, rule);
		if (k >= 6.0) {
			c = pal(0);
			fig = 0.0;
		}
	} else if (pattern == 7) {
		// CLOUDS - soft blots of each color melting into the next: batik, tie-dye, marbling
		float v = fbm(vec3(q / s, pat_seed * 3.7)) * float(max(ncolors, 1)) * 1.3;
		float k = floor(v);
		float t = smoothstep(0.35, 0.65, fract(v));
		c = mix(pal(int(k)), pal(int(k) + 1), t);
		fig = mix(float(wrap(int(k)) != 0), float(wrap(int(k) + 1) != 0), t);
	} else if (pattern == 8) {
		// IKAT - stripes along the warp whose edges are feathered and stepped, as resist-dyed
		// threads land a little off where they were tied
		float x = q.x + (h1(floor(q.y / 0.5)) - 0.5) * s * 0.3 + sin(q.y / s * 1.7 + pat_seed) * s * 0.35;
		vec2 b = bands(x, s, aa + s * 0.04);
		c = mix(pal(int(b.x)), pal(int(b.x) + 1), b.y);
		fig = mix(float(wrap(int(b.x)) != 0), float(wrap(int(b.x) + 1) != 0), b.y);
	} else if (pattern == 9) {
		// THE PAINTING
		if (has_painting > 0.5) {
			c = textureLod(painting, painting_uv(p), lod).rgb;
			fig = painting_detail(p, lod);
		}
	}
	// past what a pixel can hold, the pattern's own mean - never a moire
	if (pattern >= 1 && pattern <= 8) {
		vec3 mean = vec3(0.0);
		for (int i = 0; i < 6; i++) {
			if (i < max(ncolors, 1)) {
				mean += colors[i];
			}
		}
		mean /= float(max(ncolors, 1));
		c = mix(c, mean, smoothstep(0.2, 0.6, aa / s));
	}
	return vec4(c, fig);
}

// THE BORDER: how much of the band along the hem is here, and its color over [param c]
float border_at(float hem, float aa) {
	if (border <= 0.0) {
		return 0.0;
	}
	return smoothstep(border_inset - aa, border_inset + aa, hem) * (1.0 - smoothstep(border_inset + border - aa, border_inset + border + aa, hem));
}

// THE RELIEF the agent asked for, in [-1, 0] (0 the surface): the pattern's figures raised or sunk,
// stitched quilting, buttoned tufts, the painting's own detail
float shaped(vec2 p, float aa, float lod, float hem) {
	if (relief == 2 || relief == 3) {
		// the figures with sloped walls, a millimeter or so wide, never a cliff a pixel wide
		vec4 pt = pattern_at(p, max(aa, 0.08), lod);
		float fig = max(pt.a, border_at(hem, max(aa, 0.08)));
		return relief == 2 ? fig - 1.0 : -fig;
	} else if (relief == 4) {
		// QUILTED: stitched along a diamond lattice, puffed between the stitches
		vec2 d = rot2(p, pat_turn + 0.785398) / max(relief_scale, 0.5);
		vec2 f = abs(fract(d) - 0.5);
		// a pillow's section: rising all the way from the stitch to the middle, so the whole of each
		// diamond is shaded by the light (a flat-topped puff showed only thin seams)
		float s = clamp((0.5 - max(f.x, f.y)) / 0.5, 0.0, 1.0);
		return sin(1.5707963 * s) - 1.0;
	} else if (relief == 5) {
		// TUFTED: a button pulled down into a dimple at every crossing, the cloth puffed round it
		vec2 l = fract(rot2(p, pat_turn) / max(relief_scale, 0.5) + 0.5) - 0.5;
		float d = length(l);
		return -exp(-(d * d) / 0.018) - 0.15 * (1.0 - smoothstep(0.0, 0.08, min(abs(l.x), abs(l.y))));
	} else if (relief == 6) {
		if (has_painting < 0.5) {
			return 0.0;
		}
		float hd = painting_detail(p, lod);
		return relief_invert > 0.5 ? -hd : hd - 1.0;
	}
	return 0.0;
}
