shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, depth_draw_opaque;

// A part's fur as strands (Props `fur`, FurStrands, next/studio.md "Fur (props)"): one strip of ribbons, a ribbon a strand, whose
// vertices are placeholders. Each vertex finds its strand and its joint from VERTEX_ID, and the strand's root, the skin's normal
// there and two numbers of its own in `roots` (two texels a strand), and is laid out in the mesh's own space. The strand rises off
// the skin and leans away from the crown (the top of the part, middle of its width), so the fur parts there and falls away evenly
// on every side. It is drawn down by its weight the further out it is, waves loosely, and gathers by its tip toward its neighbors
// in locks. Each strand has its own length (55-100%) and shade.
//
// Each joint is turned to face the camera, the strand tapering to its tip but never narrower than `min_px` pixels at its depth: a
// hair finer than a pixel stays one whole line that the stage's MSAA smooths, never a run of dots. Opaque: the part's own material
// under it is the dense undercoat, so a gap between strands reads as fur.
//
// Lit along the strand (Kajiya-Kay): its diffuse from the sine to the light, the coat's far side in its own shade, a white highlight
// and a tinted one shifted along it. Darker toward the root; the fine tips glow when lit from behind.
//
// A touch (PropRig.touch: a world point, how deep it presses, a sweep) lays the strands round it flat toward the skin along the
// sweep (or the way they lean), parts them outward round its edge, and gives a sheen where they are pressed.

uniform sampler2D roots : filter_nearest, repeat_disable;
uniform int row = 512;                 // strands a row of `roots` (FurStrands.ROW)
uniform int segments = 10;             // a strand's segments (FurStrands.SEGMENTS)
uniform float fur_len = 0.02;          // meters, as the thing is built
uniform float width = 0.0003;          // a strand's width at its root (m, as built)
uniform float min_px = 1.0;            // the least a strand is wide on screen (pixels)
uniform float curl = 0.3;
uniform float droop = 0.25;
uniform float gather = 0.4;            // how far a strand's tip is drawn toward its lock's root
uniform vec3 root_color : source_color = vec3(0.1);
uniform vec3 tip_color : source_color = vec3(0.5);
// the fingers on it, and where each just was: a world point and how deep it presses (m; 0 for none), and the sweep there (world, m)
// - PropRig.touch_all hands them, at most TOUCH_MOST (Props.TOUCH_MOST)
const int TOUCH_MOST = 24;
uniform vec4 touches[24];
uniform vec3 pushes[24];
uniform int touch_n = 0;
uniform float reach = 0.016;           // how far round a fingertip the fur answers (m)
uniform vec3 crown = vec3(0.0, 1.0, 0.0);  // where it parts: the top of the part, in its mesh's own space (Props sets it)

varying vec3 v_tangent;                // view space, root to tip
varying vec3 v_skin;                   // the skin's normal at the root, view space
varying float v_along;                 // 0 at the root, 1 at the tip
varying flat float v_shade;
varying flat float v_pressed;

// A cell's point, 0..1 each way: an integer hash, the same on every machine.
vec3 cell_point(ivec3 c) {
	uvec3 v = uvec3(c) * 1664525u + 1013904223u;
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	v ^= v >> 16u;
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	return vec3(v) * (1.0 / 4294967295.0);
}

// The root of the lock a strand at `p` belongs to: the nearest of points strewn one a cell of `size`.
vec3 lock_root(vec3 p, float size) {
	vec3 q = p / size;
	ivec3 c = ivec3(floor(q));
	float best = 1e9;
	vec3 g = q;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				ivec3 cc = c + ivec3(x, y, z);
				vec3 f = vec3(cc) + cell_point(cc);
				vec3 d = f - q;
				float dd = dot(d, d);
				if (dd < best) {
					best = dd;
					g = f;
				}
			}
		}
	}
	return g * size;
}

// A slow field over the skin: which way the locks there are combed (tangent to it), varied so the fur lies in waves.
vec3 combed(vec3 at, vec3 n) {
	vec3 q = at * 9.0;
	vec3 f = vec3(sin(q.y * 1.3 + q.z * 0.7), sin(q.z * 1.1 + q.x * 0.9 + 1.7), sin(q.x * 1.2 + q.y * 0.8 + 3.1));
	vec3 t = f - n * dot(f, n);
	float l = length(t);
	return l > 1e-5 ? t / l : vec3(0.0);
}

// What touch `tc` (swept by `pu`) does to a strand rooted at `root`: how hard it presses it (the most of either hand), which way it
// lays it, and how far round its edge it parts it. `back` turns a world direction into the mesh's space, `origin` is the mesh's.
void pressed(vec3 root, vec3 n, mat3 back, vec3 origin, float s, vec4 tc, vec3 pu, inout float press, inout vec3 lay,
		inout vec3 part) {
	if (tc.w <= 0.0) {
		return;
	}
	vec3 to = root - back * (tc.xyz - origin);
	float r = reach / s;
	float k = exp(-dot(to, to) / (r * r));
	float deep = clamp(tc.w / max(fur_len * s, 1e-4), 0.0, 1.0);
	vec3 pl = back * pu;
	vec3 sweep = pl - n * dot(pl, n);
	float sl = length(sweep);
	vec3 side = to - n * dot(to, n);
	float sd = length(side);
	lay += (sl > 1e-6 ? sweep / sl : vec3(0.0)) * k;
	part += (sd > 1e-6 ? side / sd : vec3(0.0)) * 4.0 * k * (1.0 - k) * deep;
	// a hand a third of the way into the coat lays what is under it flat
	press = max(press, clamp(deep * k * 2.5, 0.0, 1.0));
}

// A step's way as it is drawn: waved round its natural way `d`, then laid flat where it is pressed (along the sweep, or the way it
// leans where the hand only presses) and parted round a touch.
vec3 shaped(vec3 d, vec3 n, vec3 lie, vec3 across, float u, float phase, float waves, float press, vec3 lay, vec3 part) {
	float w = TAU * (waves * u) + phase;
	d = normalize(d + (across * sin(w) + n * cos(w) * 0.35) * curl * 0.7 * smoothstep(0.0, 0.3, u));
	if (press > 0.0) {
		float ll = length(lay);
		vec3 along = ll > 1e-4 ? lay / ll * min(ll * 2.0, 1.0) : vec3(0.0);
		vec3 flat_way = normalize((d - n * dot(d, n)) * 0.4 + lie * 0.2 + along * 1.4 - n * 0.12);
		d = normalize(mix(d, flat_way, press));
	}
	return normalize(d + part * 0.45);
}

void vertex() {
	int per = 2 * segments + 4;
	int sid = VERTEX_ID / per;
	int k = clamp(VERTEX_ID - sid * per - 1, 0, 2 * segments + 1);
	int joint = k / 2;
	float side = float(k - joint * 2) * 2.0 - 1.0;
	ivec2 at = ivec2((sid % row) * 2, sid / row);
	vec4 a = texelFetch(roots, at, 0);
	vec4 b = texelFetch(roots, at + ivec2(1, 0), 0);
	vec3 root = a.xyz;
	vec3 n = normalize(b.xyz);
	mat3 rot = mat3(MODEL_MATRIX);
	float s = max(length(rot[0]), 1e-6);
	mat3 back = transpose(rot) / (s * s);
	vec3 down = normalize(back * vec3(0.0, -1.0, 0.0));
	// which way it lies: away from the crown, as the locks there are combed, and down the skin
	vec3 away = root - crown;
	vec3 parted = away - n * dot(away, n);
	float pl = length(parted);
	parted = pl > 1e-6 ? parted / pl : vec3(0.0);
	vec3 lie = parted + combed(root, n) * 0.3 + (down - n * dot(down, n)) * 0.8;
	lie -= n * dot(lie, n);
	float ll = length(lie);
	lie = ll > 1e-5 ? lie / ll : normalize(cross(n, abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 across = cross(n, lie);
	float press = 0.0;
	vec3 lay = vec3(0.0);
	vec3 part = vec3(0.0);
	for (int i = 0; i < min(touch_n, TOUCH_MOST); i++) {
		pressed(root, n, back, MODEL_MATRIX[3].xyz, s, touches[i], pushes[i], press, lay, part);
	}
	// its lock: the tip drawn toward the lock's root, the lock waving as one
	vec3 g = lock_root(root, max(fur_len * 0.3, 1e-4));
	vec3 to_lock = (g - root) - n * dot(g - root, n);
	float phase = TAU * (fract(dot(g, vec3(1731.0, 2113.0, 1597.0))) + 0.12 * b.w);
	float waves = 0.6 + 0.45 * fract(dot(g, vec3(911.0, 1301.0, 1777.0)));
	float lock_shade = 0.88 + 0.24 * fract(dot(g, vec3(1213.0, 1567.0, 1949.0)));
	// walked out from the root to this joint: leaning off the skin (less where it already hangs), drawn down by its weight
	float len = fur_len * (0.55 + 0.45 * a.w);
	float seg_len = len / float(segments);
	float lean = (0.15 + 0.35 * droop) * (1.0 - max(dot(n, down), 0.0));
	vec3 dir = normalize(n * cos(lean) + lie * sin(lean));
	vec3 p = root;
	vec3 last = shaped(dir, n, lie, across, 0.0, phase, waves, press, lay, part);
	vec3 next = last;
	for (int i = 0; i < segments; i++) {
		float u = (float(i) + 0.5) / float(segments);
		next = shaped(dir, n, lie, across, u, phase, waves, press, lay, part);
		if (i >= joint) {
			break;
		}
		p += next * seg_len;
		last = next;
		dir = normalize(dir + (down * 1.3 + lie * 0.6) * droop / float(segments));
	}
	float u = float(joint) / float(segments);
	vec3 t = joint == 0 ? next : (joint == segments ? last : normalize(last + next));
	p += to_lock * gather * u * u;
	t = normalize(t * len + to_lock * gather * 2.0 * u);
	// and under a hand, pressed down toward the skin
	p -= n * dot(p - root, n) * 0.6 * press;
	// turned to the camera, tapering, at least `min_px` pixels wide where it stands
	vec3 pv = (MODELVIEW_MATRIX * vec4(p, 1.0)).xyz;
	vec3 tv = normalize(mat3(MODELVIEW_MATRIX) * t);
	vec3 eye = PROJECTION_MATRIX[3][3] > 0.5 ? vec3(0.0, 0.0, 1.0) : normalize(-pv);
	vec3 bv = cross(tv, eye);
	float bl = length(bv);
	bv = bl > 1e-5 ? bv / bl : normalize(cross(tv, vec3(0.0, 1.0, 0.0)) + vec3(1e-5, 0.0, 0.0));
	float wc = PROJECTION_MATRIX[2][3] * pv.z + PROJECTION_MATRIX[3][3];
	float px = 2.0 * abs(wc) / min(PROJECTION_MATRIX[0][0] * VIEWPORT_SIZE.x, PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float half_w = 0.5 * max(width * s * mix(1.0, 0.12, u), min_px * px);
	VERTEX = pv + bv * side * half_w;
	NORMAL = normalize(mat3(MODELVIEW_MATRIX) * n);
	v_skin = NORMAL;
	v_tangent = tv;
	v_along = u;
	v_shade = (0.86 + 0.28 * b.w) * lock_shade;
	v_pressed = press;
}

void fragment() {
	// the skin's normal, whichever side of the ribbon is seen
	NORMAL = normalize(v_skin);
	vec3 col = mix(root_color, tip_color, smoothstep(0.0, 1.0, v_along)) * v_shade;
	// pressed flat, it catches a sheen
	col = mix(col, tip_color * 1.1, v_pressed * 0.2);
	ALBEDO = col * mix(0.3, 1.0, smoothstep(0.0, 0.85, v_along));
	ROUGHNESS = mix(0.85, 0.6, v_pressed);
	SPECULAR = 0.25;
}

void light() {
	vec3 t = normalize(v_tangent);
	float tl = dot(t, LIGHT);
	float facing = dot(NORMAL, LIGHT);
	// along the strand, the coat's far side in its own shade (the engine multiplies by ALBEDO after)
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (sqrt(max(1.0 - tl * tl, 0.0)) * clamp((facing + 0.3) / 1.3, 0.0, 1.0) / PI);
	// a white highlight shifted toward the tip, a tinted one toward the root
	vec3 h = normalize(LIGHT + VIEW);
	float h1 = dot(normalize(t - NORMAL * 0.08), h);
	float h2 = dot(normalize(t + NORMAL * 0.12), h);
	float s1 = pow(sqrt(max(1.0 - h1 * h1, 0.0)), 90.0);
	float s2 = pow(sqrt(max(1.0 - h2 * h2, 0.0)), 24.0);
	float lit = smoothstep(-0.15, 0.35, facing) * smoothstep(0.0, 0.6, v_along);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * lit * (vec3(s1 * (0.1 + 0.12 * v_pressed)) + s2 * 0.05 * tip_color);
	// the fine tips glowing when lit from behind
	float behind = pow(clamp(dot(-LIGHT, VIEW), 0.0, 1.0), 4.0) * v_along;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (behind * 0.35 / PI);
}
