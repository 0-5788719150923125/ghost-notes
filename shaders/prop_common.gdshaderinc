// What every modeled thing's surface shares (see src/table/props.gd): noise in the thing's own
// space, relief without tangents, the ORNAMENT - a motif laid out round a part, worked in as
// relief, paint or inlay - and what the PLAY OF LIGHT needs. Included by prop.gdshader,
// prop_glass.gdshader and prop_lens.gdshader.

// Props.ORNAMENTS: 0 none, 1 bands, 2 flutes, 3 dots, 4 stars, 5 moons, 6 zigzag, 7 scales,
// 8 spiral, 9 lattice, 10 hammered, 11 an ornament of its own (own_ornament, written by an agent)
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
// THE SURFACE (Props.TEXTURES): 0 none, 1 grit, 2 pitted, 3 cracked, 4 chipped, 5 fibers, 6 brushed, 7 lumpy, 8 granular,
// 9 pebbled, 10 bricks, 11 tiles, 12 planks, 13 rough, 14 crumbled, 15 a texture of its own (own_texture, written by an agent) - how strong it is (0..1),
// its features' size (centimeters) and its relief at the full (meters); and how unevenly the material is polished (0..1)
uniform int tex = 0;
uniform float tex_depth = 0.0;
uniform float tex_size = 0.2;
uniform float tex_relief = 0.0;
uniform float mottle = 0.0;

varying vec3 opos;          // the thing's own space, in pattern units
varying vec3 cpos;          // ...in centimeters
varying vec3 lpos;          // ...in centimeters from the middle of its own copy (Props.Tris.placed)
varying flat float tag;     // the copy's own number, 0..1
varying vec3 onrm;          // the surface's facing in the thing's own space

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
	onrm = NORMAL;
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

// The nearest of the texture's cells to p: its distance, the next nearest's, and its own number; `to` the way from p to its middle
vec3 near_cell(vec3 p, out vec3 to) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	to = vec3(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 r = g + vec3(hash3(i + g), hash3(i + g + 17.1), hash3(i + g + 33.7)) - f;
				float d = length(r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = hash3(i + g + 51.3);
					to = r;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(d1, d2, id);
}

// THE DRAWING AN ORNAMENT OF ITS OWN MAY USE (Ornaments.HELPERS): distances in a cell's units, negative inside, and what turns them
// into relief.
float sd_circle(vec2 p, float r) {
	return length(p) - r;
}
float sd_box(vec2 p, vec2 half_size) {
	vec2 d = abs(p) - half_size;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}
float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
	return length(pa - ba * h);
}
// the distance to a spiral winding out from the middle, its arms `gap` apart, `turns` round at most (beyond, none)
float sd_spiral(vec2 p, float gap, float turns) {
	float r = length(p);
	float a = atan(p.y, p.x) / 6.2831853;
	float k = floor(r / gap - a);
	float d = 1e3;
	for (int i = 0; i < 2; i++) {
		float arm = (k + float(i) + a) * gap;
		if (arm >= 0.0 && arm <= turns * gap) {
			d = min(d, abs(r - arm));
		}
	}
	return d;
}
vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}
// a line of width w along a distance d, soft at its edge; and a shape's inside
float stroke(float d, float w) {
	return 1.0 - smoothstep(w * 0.55, w, abs(d));
}
float fill(float d) {
	return 1.0 - smoothstep(-0.015, 0.015, d);
}

// AN ORNAMENT OF ITS OWN (orn 11): its relief 0..1 and where paint or inlay goes 0..1, at `p` in its cell (x and y from -0.5 to 0.5,
// a cell as wide round the part as it is tall), `cell` which cell it is (its column round the part and its row up it, whole numbers),
// `uv` where it is round the part and up its band (0..1 each), and `s` the part's own number (0..1). This one draws nothing: a
// material wearing one is a variant of its shader with the agent's body written here (Ornaments.shader_for).
vec2 own_ornament(vec2 p, vec2 cell, vec2 uv, float s) {
	return vec2(0.0); // OWN ORNAMENT
}

// A TEXTURE OF ITS OWN (tex 13): its relief 0..1, how much rougher (above 0) or glossier (below) than its material it is there, -1..1,
// and how much of the material's second color shows there, 0..1 - at `p`, where it is in the thing's own space in units of its
// texture's size, `n` the way the surface faces there (the thing's space, unit length) and `s` the part's own number (0..1). This one
// is plain: a material wearing one is a variant of its shader with the agent's body written here (Ornaments.shader_for).
vec3 own_texture(vec3 p, vec3 n, float s) {
	return vec3(0.5, 0.0, 0.0); // OWN TEXTURE
}

// A bumped normal kept facing the eye: tipped past edge-on (a steep pit's wall), it faces away, and the light it is shaded by comes back
// as a white glint however rough the surface - so it is pulled back toward the eye just enough, as a game's bump mapping does
vec3 toward_eye(vec3 n, vec3 v) {
	float nv = dot(n, v);
	return nv < 0.08 ? normalize(n + v * (0.08 - nv)) : n;
}

// How much of a clear coat a polish carries: none on what is dull (below 0.15), all of it from 0.45 on
float glazed(float p) {
	return p * smoothstep(0.15, 0.45, p);
}

// MASONRY AND BOARDS laid on a plane, at q in the texture's size: x 1 on a brick's, a tile's or a board's face and 0 in a joint, y
// that one's own number. Bricks are 1 long and 0.45 tall, each course shifted half a brick; tiles are squares; boards are 1 wide and
// run along x, each ended at a joint of its own 4 to 7 long
vec2 laid(vec2 q, int which) {
	if (which == 10) {
		float row = floor(q.y / 0.45);
		float x = q.x + 0.5 * mod(row, 2.0);
		vec2 f = vec2(fract(x), fract(q.y / 0.45));
		vec2 e = min(f, 1.0 - f) * vec2(1.0, 0.45);
		return vec2(smoothstep(0.022, 0.045, min(e.x, e.y)), hash3(vec3(floor(x), row, 3.0)));
	}
	if (which == 11) {
		vec2 f = fract(q);
		vec2 e = min(f, 1.0 - f);
		return vec2(smoothstep(0.018, 0.036, min(e.x, e.y)), hash3(vec3(floor(q), 5.0)));
	}
	float row = floor(q.y);
	float len = 4.0 + 3.0 * hash3(vec3(row, 7.0, 1.0));
	float x = q.x + hash3(vec3(row, 9.0, 2.0)) * len;
	float fx = fract(x / len) * len;
	float fy = fract(q.y);
	float d = min(min(fy, 1.0 - fy), min(fx, len - fx));
	return vec2(smoothstep(0.012, 0.03, d), hash3(vec3(row, floor(x / len), 11.0)));
}

// THE SURFACE at q (the thing's space in its texture's size) facing n, a pixel `px` of those units across: its relief 0..1, how much
// rougher it is there (-1..1) and how much of `color2` shows there (0..1). Every texture but masonry is noise in three dimensions, so
// nothing on it tiles or seams; masonry is laid on the plane each face is nearest to, blended where a face turns. A line is never
// drawn thinner than a pixel, and detail finer than a few pixels is left out (it would only alias)
vec3 texture_at(vec3 q, vec3 n, float px) {
	if (tex == 1) {
		// GRIT
		return vec3(vnoise(q * 1.7) * 0.55 + vnoise(q * 4.1 + vec3(5.0)) * 0.45, 0.0, 0.0);
	}
	if (tex == 2) {
		// PITTED: some cells sunk into pits, duller, a little of color2 in them
		vec3 c = cellsid(q);
		float pit = (1.0 - smoothstep(0.08, 0.38, c.x)) * step(0.45, c.z);
		return vec3(1.0 - pit + (vnoise(q * 3.0) - 0.5) * 0.15, pit * 0.15, pit * 0.25);
	}
	if (tex == 3) {
		// CRACKED: plates, each domed a little, color2 in the cracks between
		vec3 c = cellsid(q);
		float crack = (1.0 - smoothstep(0.0, max(0.07, px * 1.5), c.y - c.x)) * min(1.0, 0.07 / max(px * 1.5, 0.07) * 1.6);
		return vec3((1.0 - c.x * 0.35) * (1.0 - crack), crack * 0.2, crack * 0.6);
	}
	if (tex == 4) {
		// CHIPPED: each cell a shell-shaped hollow struck from the stone, rising to a sharp ridge where it meets the next, faintly
		// rippled in arcs round the point at its edge where it was struck
		vec3 to;
		vec3 c = near_cell(q, to);
		vec3 struck = normalize(vec3(hash3(vec3(c.z * 13.0)), hash3(vec3(c.z * 29.0)), hash3(vec3(c.z * 47.0))) - 0.5 + vec3(1e-4));
		float arc = length(to + struck * 0.7);
		float ripple = sin(arc * 17.0 + c.z * 6.0) * 0.03 * (1.0 - smoothstep(0.3, 0.9, c.x)) * (1.0 - smoothstep(0.05, 0.12, px));
		return vec3(clamp(c.x * c.x * 1.3 + ripple, 0.0, 1.0), 0.0, 0.0);
	}
	if (tex == 5) {
		// FIBERS, running up the part
		return vec3(fbm(q * vec3(2.2, 0.1, 2.2)) * 0.7 + vnoise(q * vec3(6.0, 0.3, 6.0)) * 0.3, 0.0, 0.0);
	}
	if (tex == 6) {
		// BRUSHED: fine scratches running up the part
		return vec3(vnoise(q * vec3(9.0, 0.08, 9.0)) * 0.7 + vnoise(q * vec3(23.0, 0.2, 23.0)) * 0.3, 0.0, 0.0);
	}
	if (tex == 7) {
		// LUMPY
		return vec3(fbm(q * 0.6), 0.0, 0.0);
	}
	if (tex == 8) {
		// GRANULAR: packed grains, each a flat facet tipped its own way and polished its own, a share of them color2
		vec3 to;
		vec3 c = near_cell(q, to);
		vec3 tip = vec3(hash3(vec3(c.z * 31.0)), hash3(vec3(c.z * 57.0)), hash3(vec3(c.z * 91.0))) - 0.5;
		float h = 0.55 + dot(-to, tip) * 1.1 - (1.0 - smoothstep(0.0, max(0.08, px * 1.5), c.y - c.x)) * 0.35;
		return vec3(clamp(h, 0.0, 1.0), (c.z - 0.5) * 0.2, step(0.84, fract(c.z * 13.7)) * 0.85);
	}
	if (tex == 9) {
		// PEBBLED
		vec3 c = cellsid(q);
		return vec3(clamp(1.0 - c.x * c.x * 1.4, 0.0, 1.0), 0.0, 0.0);
	}
	if (tex >= 10 && tex <= 12) {
		// BRICKS, TILES, PLANKS: a little grit on each face, each its own a little; the joints sunk, rougher, and color2 in a
		// brick's or a tile's
		vec3 w = pow(abs(n), vec3(4.0));
		w /= max(w.x + w.y + w.z, 1e-5);
		vec2 a = laid(q.zy, tex);
		vec2 b = laid(q.xz, tex);
		vec2 c = laid(q.xy, tex);
		float face = a.x * w.x + b.x * w.y + c.x * w.z;
		float id = a.y * w.x + b.y * w.y + c.y * w.z;
		float h = face * (0.82 + 0.12 * id + vnoise(q * 9.0) * 0.12);
		return vec3(h, (1.0 - face) * 0.12 + (id - 0.5) * 0.1, tex == 12 ? 0.0 : 1.0 - face);
	}
	if (tex == 13 || tex == 14) {
		// ROUGH: noise at its size and at every smaller size down to grit, each half as far apart and a little fainter, as a rough
		// surface is rough at every scale; CRUMBLED: the same of sharp creases and ridges, as broken coal, shale or crumpled paper. An
		// octave finer than a few pixels is left out, so it never sparkles
		float h = 0.0;
		float total = 0.0;
		float amp = 1.0;
		vec3 at = q;
		float step_px = px;
		for (int i = 0; i < 6; i++) {
			float w = amp * (1.0 - smoothstep(0.25, 0.6, step_px));
			float nz = vnoise(at);
			if (tex == 14) {
				nz = 1.0 - abs(nz * 2.0 - 1.0);
				nz *= nz;
			}
			h += nz * w;
			total += w;
			at = at * 2.07 + vec3(1.7, 4.3, 2.9);
			amp *= 0.58;
			step_px *= 2.07;
		}
		h = total > 1e-4 ? h / total : 0.5;
		return vec3(smoothstep(0.12, 0.88, h), 0.0, 0.0);
	}
	if (tex == 15) {
		vec3 own = own_texture(q, n, fract(seed * 0.6180339));
		return vec3(clamp(own.x, 0.0, 1.0), clamp(own.y, -1.0, 1.0), clamp(own.z, 0.0, 1.0));
	}
	return vec3(0.5, 0.0, 0.0);
}

// THE SURFACE laid on a material: its color [param albedo] as the texture changes it (a share of [param second], its second color,
// where the texture says), and [param rough], [param coat], [param relief] (meters), [param spec] and [param occl] (what of the room's
// light reaches it, 1 all) changed with it. The relief fades into roughness where its features come under a few pixels, as a normal
// map's mipmaps do; its hollows are rougher and darker, and reflect nothing - a cavity occludes its own specular as a game's cavity map
// does, or a pit's steep wall, seen at a glancing angle, would catch the light white however rough it is. The mottle is soft patches
// `grain` across, some duller and some glossier. Called on every pixel, never in a branch (its derivatives)
vec3 surface(vec3 albedo, vec3 second, inout float rough, inout float coat, inout float relief, inout float spec, inout float occl) {
	float px = max(length(dFdx(cpos)), length(dFdy(cpos))) / max(tex_size, 0.01);
	vec3 tx = texture_at(cpos / max(tex_size, 0.01) + vec3(seed * 7.1, seed * 3.3, seed * 5.9), normalize(onrm + vec3(1e-6)), px);
	float sharp = 1.0 - smoothstep(0.3, 0.8, px);
	float on = tex > 0 ? tex_depth : 0.0;
	float seen = on * sharp;
	float lost = on - seen;
	relief += tex > 0 ? tx.x * tex_relief * sharp : 0.0;
	rough = clamp(rough + (tx.y + (0.5 - tx.x) * 0.2) * on + lost * 0.25, 0.03, 1.0);
	vec3 a = mix(albedo, second, tex > 0 ? tx.z : 0.0);
	a *= 1.0 - (seen * (1.0 - tx.x) + lost * 0.5) * 0.3;
	float hollow = seen * (1.0 - smoothstep(0.0, 0.6, tx.x)) + lost * 0.35;
	spec *= 1.0 - hollow;
	coat *= 1.0 - hollow;
	occl *= 1.0 - hollow * 0.6;
	float mt = fbm(opos * 0.45 + vec3(41.0));
	rough = clamp(rough + (mt - 0.5) * 2.0 * mottle * 0.4, 0.03, 1.0);
	coat *= 1.0 - mottle * mt;
	return a;
}

// How much of ornament [param o] glass etches (frosts): a motif's place (stars, dots, a lattice); never an ornament that is only the
// glass's shape - flutes and hammering stay clear glass that bends and catches the light, as real fluted glass does
float etched(vec2 o) {
	return (orn == 2 || orn == 10) ? 0.0 : o.y;
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
	if (orn == 11) {
		return clamp(own_ornament(p, floor(cell), vec2(u, v), fract(seed * 0.6180339)), 0.0, 1.0) * inzone;
	}
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

