// What every modeled thing's surface shares (see src/table/props.gd): noise in the thing's own
// space, relief without tangents, the ORNAMENT - a motif laid out round a part, worked in as
// relief, paint or inlay - and what the PLAY OF LIGHT needs. Included by prop.gdshader,
// prop_glass.gdshader and prop_lens.gdshader.

// Props.ORNAMENTS: 0 none, 1 bands, 2 flutes, 3 dots, 4 stars, 5 moons, 6 zigzag, 7 scales,
// 8 spiral, 9 lattice, 10 hammered
uniform int orn = 0;
uniform float orn_count = 8.0;
uniform float orn_depth = 0.5;
uniform vec3 orn_color : source_color = vec3(0.8, 0.62, 0.25);
uniform float orn_paint = 0.0;
uniform vec2 orn_zone = vec2(0.0, 1.0);
uniform vec2 dims = vec2(20.0, 10.0);      // the part's girth and height, centimeters
uniform float grain = 1.0;                 // the material's pattern size, centimeters
uniform float seed = 0.0;
// Props.PLAYS: 0 none, 1 silk, 2 flash, 3 fire, 4 glitter, 5 rainbow, 6 glow
uniform int play = 0;
// a crystal's banding or a stone's veins curve round in rings (agate, malachite)
uniform float rings = 0.0;

varying vec3 opos;          // the thing's own space, in pattern units
varying vec3 cpos;          // ...in centimeters
varying vec3 lpos;          // ...in centimeters from the middle of its own copy (Props.Tris.placed)
varying flat float tag;     // the copy's own number, 0..1

// A BRUSH'S HAIRS (Bristles, a `tuft`): their root and the way they run (the mesh's own space), how long they are (meters,
// 0: not hairs), and how they bend now - where their tips are pulled to (meters) and how far they splay - each vertex as far
// as it is up its hair (UV2's x). TablePaint sets the bend from show time.
uniform vec3 bristle_root = vec3(0.0);
uniform vec3 bristle_axis = vec3(0.0, 1.0, 0.0);
uniform float bristle_len = 0.0;
uniform vec3 bristle_bend = vec3(0.0);
uniform float bristle_splay = 0.0;
// ...LAID ON A LEVEL SURFACE they are pressed down onto (Bristles.laid): the share of each lying along it and the angle its arc turns
// through to meet it - bowed the way bristle_bend points; none (y 0), bent as bristle_bend says. (Bristles.LAID_MOST)
uniform vec2 bristle_lay = vec2(0.0);
const float BRISTLE_LAID_MOST = 0.6;
// (Bristles.CORE_IN, CORE_DOWN, CORE_WET)
const float BRISTLE_CORE_IN = 1.0;
const float BRISTLE_CORE_DOWN = 1.0;
const float BRISTLE_CORE_WET = 0.45;
// how much wider a sponge squeezed in the hand bulges for how much thinner it is (mostly air, it gives little back), and how much
// thicker its ends swell as the foam is pushed out from under the fingers
const float SQUEEZE_BULGE = 0.15;
const float SQUEEZE_EDGE_SWELL = 0.12;
// A SPONGE GIVES where it is pressed: the way it is pressed (the mesh's space) and how far, a share of its depth; its middle
uniform vec4 squash = vec4(0.0);
uniform vec3 squash_at = vec3(0.0);
// ...SQUEEZED IN THE HAND, its broad faces pressed together about its middle (squash_at): the way across them (the mesh's space) and
// how much thinner it is, 0-1 - both sides in, then back out to its own shape, never longer than it is (TablePaint._squeeze_of)
uniform vec4 squeeze = vec4(0.0);
// ...PINCHED by a finger and thumb, not pressed between two palms: how far from its middle the press reaches (the mesh's space; 0, all
// of it alike)
uniform float squeeze_reach = 0.0;
// a surface it is pressed onto (its own space): its normal toward it and how far along that the surface is; how far the deepest
// of it went past it, the band over it that gives and how far it spreads; the deepest of it (TablePaint._flat_on)
uniform vec4 flat_on = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec3 flat_by = vec3(0.0);
uniform vec3 flat_at = vec3(0.0);
// (spread out from the deepest point as from a disc this wide, never from a point)
const float FLAT_CORE = 0.004;
// LAID OVER A POT'S MOUTH TOO NARROW FOR IT AND PUSHED DOWN IN ITS MIDDLE (TablePaint._drape_on; the user, 2026-11-08: "You would expected
// it dabbed flat: resting on both sides of the container, and compressed/pushed from the middle, into the container. It would bend in the
// middle"): the way up (its own space) and how high its face is along it; the mouth's middle (its own space) and how wide it is inside its
// wall (0: not laid over one); how far its face's middle is pushed down, how much further its back is pressed in under the finger, how
// thick it is along the way up, and how wide the finger presses (a share of the mouth). What rests on the rim, outside the mouth, stays.
uniform vec4 drape_on = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 drape_at = vec4(0.0);
uniform vec4 drape_by = vec4(0.0);
// PRESSED ONTO A SKIN, A PAD OR A SPONGE TAKES ITS SHAPE (TablePaint._press_on and press_lands - the same arithmetic): what stands
// over the skin, its heights along the skin's front every cell (meters; far under where nothing is); where its first cell is, how wide a
// cell is (0: not on a skin) and how far its face sags into a hollow; this mesh's space into the front's and back; where its face is
// and the way up from it toward the hand (the front's space); and that way up in this mesh's own space
uniform sampler2D press_z : filter_nearest, repeat_disable;
uniform vec4 press_cells = vec4(0.0);
uniform mat4 press_in = mat4(1.0);
uniform mat4 press_out = mat4(1.0);
uniform vec3 press_tip = vec3(0.0);
uniform vec3 press_up = vec3(0.0, 0.0, 1.0);
uniform vec3 press_up_own = vec3(0.0, 1.0, 0.0);
// (TablePaint.PRESS_SOFT, PRESS_LIFT, PRESS_THIN, PRESS_REACH)
const float PRESS_SOFT = 0.0003;
const float PRESS_LIFT = 0.0002;
const float PRESS_THIN = 0.3;
const float PRESS_REACH = 0.008;
// A SURFACE PAINTED (TablePaint): where each point is on its skin, seen from its front - across and down, 0-1 - and how far
// it faces that front
uniform bool skinned = false;
uniform vec4 skin_u = vec4(0.0);
uniform vec4 skin_v = vec4(0.0);
uniform vec3 skin_side = vec3(0.0, 0.0, 1.0);
varying vec3 skin_at;

// The skin's height under (x, y) of its front (TablePaint._front_z): between its cells, and where a cell meets its rim as high as it
// stands; far under it off the skin
float press_height(vec2 xy) {
	ivec2 n = textureSize(press_z, 0);
	vec2 f = (xy - press_cells.xy) / press_cells.z;
	if (f.x < 0.0 || f.y < 0.0 || f.x > float(n.x - 1) || f.y > float(n.y - 1)) {
		return -1.0;
	}
	ivec2 ij = min(ivec2(f), n - ivec2(2));
	float z00 = texelFetch(press_z, ij, 0).r;
	float z10 = texelFetch(press_z, ij + ivec2(1, 0), 0).r;
	float z01 = texelFetch(press_z, ij + ivec2(0, 1), 0).r;
	float z11 = texelFetch(press_z, ij + ivec2(1, 1), 0).r;
	float hi = max(max(z00, z10), max(z01, z11));
	if (min(min(z00, z10), min(z01, z11)) < -0.5) {
		return hi;
	}
	vec2 a = f - vec2(ij);
	return mix(mix(z00, z10, a.x), mix(z01, z11, a.x), a.y);
}

// How high a bit of it [fs] over the skin is drawn (TablePaint.press_lands): its face, sagged into what hollow is near it, laid on
// whatever it would go into; its back kept its own share of its depth over it
float press_lands(float fs, float zf, float back, float sag) {
	float g = fs - sag * (1.0 - back) * (1.0 - smoothstep(0.0, PRESS_REACH, fs));
	float h = g - PRESS_LIFT < PRESS_SOFT * 20.0 ? PRESS_LIFT + PRESS_SOFT * log(1.0 + exp((g - PRESS_LIFT) / PRESS_SOFT)) : g;
	return max(h, PRESS_THIN * zf * back);
}

void vertex() {
	cpos = VERTEX * 100.0;
	opos = cpos / max(grain, 0.05) + vec3(seed * 17.31, seed * 3.7, seed * 9.13);
	lpos = (VERTEX - CUSTOM0.xyz) * 100.0;
	tag = CUSTOM0.w;
	if (skinned) {
		vec4 q = vec4(VERTEX, 1.0);
		skin_at = vec3(dot(skin_u, q), dot(skin_v, q), dot(NORMAL, skin_side));
	} else {
		skin_at = vec3(0.0);
	}
	if (bristle_len > 0.0) {
		float s = clamp(UV2.x, 0.0, 1.0);
		vec3 off = VERTEX - bristle_root;
		vec3 radial = off - bristle_axis * dot(off, bristle_axis);
		// ...THE CORE (Bristles.core_at, UV's x past 1) stands for the hairs inside: pressed, they are pushed back into the bundle as
		// the outer ones splay, so it draws in and down under them - never a lump of their paint left over the splayed tips
		float out_by = bristle_splay * s * 1.2;
		if (UV.x > 1.5) {
			float down = BRISTLE_CORE_DOWN * bristle_splay;
			VERTEX -= bristle_axis * dot(off, bristle_axis) * down;
			s *= 1.0 - down;
			out_by = -BRISTLE_CORE_IN * bristle_splay * s;
		}
		// BENT ASIDE AS AN ARC OF A CIRCLE, AS LONG AS IT WAS (Bristles.bent_at, the same arithmetic): never along itself, its tip
		// at most ASIDE_MOST of its length aside - and splayed out from the middle
		vec3 aside = bristle_bend - bristle_axis * dot(bristle_bend, bristle_axis);
		float side = length(aside);
		float hl = max(bristle_len, 1e-4);
		if (bristle_lay.y > 1e-4 && side > 1e-7) {
			// ...OR LAID ON A SURFACE (Bristles.laid_at, the same arithmetic): an arc over what does not lie on it, then straight on
			float th = bristle_lay.y;
			float arc = 1.0 - clamp(bristle_lay.x, 0.0, BRISTLE_LAID_MOST);
			float rr = hl * arc / th;
			float u = min(s, arc) / arc;
			float past = max(s - arc, 0.0) * hl;
			VERTEX += bristle_axis * (rr * sin(th * u) + past * cos(th) - hl * s) + (aside / side) * (rr * (1.0 - cos(th * u)) + past * sin(th));
		} else {
			float q = min(side / hl, 0.7);
			float th = 2.0 * q;
			for (int i = 0; i < 4; i++) {
				float f = (1.0 - cos(th)) / max(th, 1e-4) - q;
				float df = (th * sin(th) - (1.0 - cos(th))) / max(th * th, 1e-8);
				th -= f / max(df, 1e-4);
			}
			th = max(th, 0.0);
			if (th > 1e-4) {
				float rr = hl / th;
				VERTEX += bristle_axis * (rr * sin(th * s) - hl * s) + (aside / side) * rr * (1.0 - cos(th * s));
			}
		}
		VERTEX += radial * out_by;
	}
	if (squash.w > 0.0) {
		vec3 d = normalize(squash.xyz);
		float into = max(dot(VERTEX - squash_at, d), 0.0);
		vec3 across = (VERTEX - squash_at) - d * dot(VERTEX - squash_at, d);
		VERTEX += -d * into * squash.w + across * squash.w * 0.3 * into / max(length(VERTEX - squash_at), 1e-4);
	}
	if (squeeze.w > 0.0) {
		vec3 d = normalize(squeeze.xyz);
		vec3 rel = VERTEX - squash_at;
		float along = dot(rel, d);
		vec3 lateral = rel - d * along;
		// PINCHED IN ITS MIDDLE (the user, 2026-11-08: "the entire sponge is compressed uniformly ... like praying. Instead, the sponge
		// should compress from the middle - while the edges still try to expand, because we're only pressing in the center with our
		// fingers and thumb"): thinnest under the fingers, falling off away from them, the ends their own thickness and a little more
		float pinch = squeeze_reach > 0.0 ? exp(-dot(lateral, lateral) / (2.0 * squeeze_reach * squeeze_reach)) : 1.0;
		float thick = 1.0 - squeeze.w * pinch + squeeze.w * SQUEEZE_EDGE_SWELL * (1.0 - pinch);
		VERTEX = squash_at + d * along * thick + lateral * (1.0 + squeeze.w * SQUEEZE_BULGE * pinch);
	}
	// PRESSED ONTO A SKIN (TablePaint._press_on): each bit drawn as high over the skin as press_lands says, along the skin's depth so
	// it lands where it says
	if (press_cells.z > 0.0) {
		vec3 pq = (press_in * vec4(VERTEX, 1.0)).xyz;
		float zs = press_height(pq.xy);
		if (zs > -0.5) {
			float fs = pq.z - zs;
			float zf = max(dot(pq - press_tip, press_up), 0.0);
			float back = smoothstep(-0.2, 0.2, dot(normalize(NORMAL), normalize(press_up_own)));
			float h = press_lands(fs, zf, back, press_cells.w);
			if (abs(h - fs) > 1e-6) {
				VERTEX = (press_out * vec4(pq.xy, zs + h, 1.0)).xyz;
			}
		}
	}
	// LAID OVER A POT'S MOUTH, BENT DOWN INTO IT: most in the middle, nothing at the wall - its back pressed in further under the finger -
	// and its faces turned as it bends
	if (drape_at.w > 0.0) {
		vec3 dn = normalize(drape_on.xyz);
		vec3 rel = VERTEX - drape_at.xyz;
		vec3 lat = rel - dn * dot(rel, dn);
		float dl = length(lat);
		float d = dl / drape_at.w;
		if (d < 1.0) {
			float sag = (1.0 - d * d) * (1.0 - d * d);
			float up = clamp((dot(VERTEX, dn) - drape_on.w) / max(drape_by.z, 1e-5), 0.0, 1.0);
			float fw = max(drape_by.w, 0.05);
			float finger = exp(-d * d / (2.0 * fw * fw));
			VERTEX -= dn * (drape_by.x * sag + drape_by.y * finger * up);
			float slope = (drape_by.x * -4.0 * d * (1.0 - d * d) + drape_by.y * up * finger * -d / (fw * fw)) / drape_at.w;
			if (dl > 1e-6) {
				NORMAL = normalize(NORMAL + dot(NORMAL, dn) * slope * lat / dl);
			}
		}
	}
	// PRESSED ONTO A SURFACE (a sponge into its paint, TablePaint._flat_lift - the same numbers): what would go under it is drawn ON
	// it, the band over it squeezed hardest nearest it, and spread out from the deepest of it as far as it gave
	if (flat_by.x > 0.0) {
		vec3 fn = normalize(flat_on.xyz);
		float fs = dot(VERTEX, fn) - flat_on.w;
		float band = max(flat_by.y, 1e-5);
		if (fs < band) {
			float fu = clamp((fs + flat_by.x) / (band + flat_by.x), 0.0, 1.0);
			float lifted = band * pow(fu, (band + flat_by.x) / band) - fs;
			vec3 rel = VERTEX - flat_at;
			vec3 out_way = rel - fn * dot(rel, fn);
			VERTEX += fn * lifted + out_way * lifted * flat_by.z / max(length(out_way), FLAT_CORE);
		}
	}
}

#include "res://shaders/noise_common.gdshaderinc"

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// a direction of each copy's own, in the thing's space
vec3 own_dir(float salt) {
	return normalize(vec3(hash3(vec3(tag * 31.7 + salt)), hash3(vec3(tag * 57.3 + salt)), hash3(vec3(tag * 83.9 + salt))) - 0.5 + vec3(1e-4));
}

// a silky stone's fibers, lying mostly flat
vec3 fibers() {
	vec3 f = own_dir(0.0);
	return normalize(vec3(f.x, f.y * 0.3, f.z) + vec3(1e-4));
}

// THE BANDING's phase: up the part in straight bands, or round in rings about the middle of its own
// copy (a little off it), warped by [param warp] - or, in a silky stone, along its fibers, so its
// bands lie across them
float banding(float warp) {
	if (play == 1) {
		return dot(lpos, fibers()) / max(grain, 0.05) * 2.6 + warp * 0.8;
	}
	if (rings > 0.5) {
		// the rings wander as the hollow they grew in did: the space they lie in is bent by a few
		// centimeters, and they ripple a little - a bend as fine as the bands blotched them
		vec3 off = own_dir(5.0) * grain * 1.5;
		vec3 w = vec3(fbm(lpos * 0.22 + vec3(tag * 7.0)), fbm(lpos * 0.22 + vec3(5.2, tag * 7.0, 1.3)),
			fbm(lpos * 0.22 + vec3(9.1, 2.8, tag * 7.0))) - 0.5;
		return length((lpos + w * 4.0 - off) * vec3(1.0, 1.35, 1.0)) / max(grain, 0.05) * 2.6 + fbm(lpos * 1.1 + vec3(3.3)) * 1.2;
	}
	return opos.y * 2.6 + warp * 5.0;
}

// A THIN FILM's color - an oily rainbow, its hue set by how thick the film is there and the angle it
// is seen at. Over a colored body the hues keep near its own (paua's blues and greens, not a
// tie-dye of every color); over black, white or gray they run the whole rainbow; paler over a pale
// body
vec3 film(vec3 n, vec3 v, vec3 body) {
	vec3 own = rgb2hsv(body);
	float thick = fbm(opos * 0.8 + vec3(5.0)) * 1.7 + (1.0 - clamp(dot(n, v), 0.0, 1.0)) * 0.75;
	float spread = mix(1.0, 0.4, smoothstep(0.15, 0.4, own.y));
	float h = fract(own.x + (fract(thick) - 0.5) * spread);
	float sat = mix(0.85, 0.35, clamp(dot(body, vec3(0.299, 0.587, 0.114)), 0.0, 1.0));
	return hsv2rgb(vec3(h, sat, 1.0));
}

// a small mirror's facing, its own for each [param id]: a nudge to the surface's normal, in the
// thing's space, up to [param most] long
vec3 tipped(float id, float most) {
	return (vec3(hash3(vec3(id * 31.0)), hash3(vec3(id * 57.0)), hash3(vec3(id * 91.0))) - 0.5) * 2.0 * most;
}

// a five-pointed star's distance (negative inside)
float star5(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

// RELIEF FROM A HEIGHT, in meters, without tangents: the surface's own screen derivatives. Called
// on every pixel, never inside a branch some pixels skip - a derivative there is undefined - and
// the surface kept as it is where it is seen edge-on: a pore there normalized a zero vector, and
// the NaN it made reached the reflection probe and blacked out every thing that reflects it
vec3 bump(vec3 n, vec3 pos, float h) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhx = dFdx(h);
	float dhy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 g = sign(det) * (dhx * r1 + dhy * r2);
	vec3 b = abs(det) * n - g;
	return dot(b, b) > 1e-30 ? normalize(b) : n;
}

// THE ORNAMENT: x its relief 0..1, y where it is (paint and inlay go there). A motif is laid out
// in cells as wide around the part as they are tall, so a star is a star on a tall vase and on a
// squat bowl alike.
vec2 ornament(vec2 uv, vec2 uv2) {
	if (orn == 0) {
		return vec2(0.0);
	}
	if (orn == 10) {
		vec2 c = cells(cpos * (0.9 + orn_count * 0.08) + vec3(seed));
		float dimple = 1.0 - c.x * c.x;
		return vec2(dimple, 0.0);
	}
	float z0 = min(orn_zone.x, orn_zone.y);
	float z1 = max(orn_zone.x, orn_zone.y);
	float y = uv2.x;
	float inzone = smoothstep(z0 - 0.004, z0 + 0.004, y) * (1.0 - smoothstep(z1 - 0.004, z1 + 0.004, y));
	if (inzone <= 0.0) {
		return vec2(0.0);
	}
	float v = (y - z0) / max(z1 - z0, 0.001);
	float u = uv.x;
	float n = max(orn_count, 1.0);
	float zh = max(dims.y * (z1 - z0), 0.1);
	float cw = max(dims.x / n, 0.05);
	float rows = max(1.0, floor(zh / cw + 0.5));
	vec2 cell = vec2(u * n, v * rows);
	vec2 p = vec2(fract(cell.x) - 0.5, (fract(cell.y) - 0.5) * (zh / rows) / cw);
	float h = 0.0;
	if (orn == 1) {
		float t = fract(v * n);
		h = 1.0 - smoothstep(0.06, 0.14, abs(t - 0.5));
	} else if (orn == 2) {
		h = 0.5 + 0.5 * cos(6.2831853 * u * n);
	} else if (orn == 3) {
		h = 1.0 - smoothstep(0.16, 0.21, length(p));
	} else if (orn == 4) {
		h = 1.0 - smoothstep(-0.01, 0.02, star5(vec2(p.x, -p.y), 0.32, 0.42));
	} else if (orn == 5) {
		float d = max(length(p) - 0.28, -(length(p - vec2(0.11, 0.07)) - 0.24));
		h = 1.0 - smoothstep(-0.01, 0.02, d);
	} else if (orn == 6) {
		float line = 0.5 + 0.36 * (abs(fract(u * n) - 0.5) * 4.0 - 1.0);
		float w = clamp(0.35 / zh, 0.03, 0.2);
		h = 1.0 - smoothstep(w, w * 1.8, abs(v - line));
	} else if (orn == 7) {
		vec2 q = vec2(fract(cell.x + 0.5 * mod(floor(cell.y), 2.0)) - 0.5, p.y);
		float d = length(q - vec2(0.0, 0.42 * (zh / rows) / cw));
		h = smoothstep(0.38, 0.47, d) * (1.0 - smoothstep(0.5, 0.56, d)) + (1.0 - smoothstep(0.0, 0.5, d)) * 0.25;
	} else if (orn == 8) {
		h = 1.0 - smoothstep(0.08, 0.16, abs(fract(cell.x + cell.y) - 0.5));
	} else if (orn == 9) {
		float a = abs(fract(cell.x + cell.y) - 0.5);
		float b = abs(fract(cell.x - cell.y) - 0.5);
		h = 1.0 - smoothstep(0.05, 0.11, min(a, b));
	}
	return vec2(h, h) * inzone;
}

