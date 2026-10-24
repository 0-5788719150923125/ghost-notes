// splat_head.gdshader - one Gaussian splat of an actor's head per instance ([SplatHead]).
//
// The splat's own numbers (`splat_data`, `per_splat` texels each: place and binding, log-scale and cover, turn,
// colour's logit, then for each of the expression's components the shift of its place and of its colour's
// logit, mixed by `expr`) and its binding frame's (`frame_data`, four texels each: origin and unit, then the frame's three
// axes) place it as the trainer did (hosts/avatar/train.py, `Splats.world`): its centre the frame's origin plus
// the unit times its place turned into the frame; its axes the frame's turned by its own; its sizes the unit
// times exp(log-scale). Seen straight on (the camera is far and fixed), its footprint is the top-left 2x2 of
// its covariance plus `low_pass`, and it is drawn as hosts/avatar/raster.py composites it: cover times the
// Gaussian's falloff, at most 0.99, nothing under 1/255 - the instances drawn back to front, blended over.
//
// THE BODY BENDS (hosts/avatar/train.py's `second_of`): a splat on a bone may take a SECOND INFLUENCE (the colour
// texel's fourth number: 0 for none, else (frame + 2) + 0.98 w) - a share w of another bone's move, or of none (frame
// -1: the still itself) - so the seat stays while the chest leans, and a joint bends rather than tears. Each bone's
// move (`moves`: six numbers a bone, a 2D transform's x, y and origin columns) is what took it from the still.
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D splat_data : filter_nearest;
uniform sampler2D frame_data : filter_nearest;
uniform int splat_width = 1024;
uniform int frame_width = 1024;
uniform int per_splat = 4;
// The expression a frame shows: its components (SplatHead.expr_of), and how many the splats were learned with.
// Only a splat on a triangle of the face takes them, and less the farther it stands from its triangle (from
// `shift_near` to `shift_far` of its triangle's units, as train.py's Splats.shift_weight).
uniform int expressions = 0;
uniform float expr[16];
uniform int triangles = 0;
uniform float shift_near = 1.0;
uniform float shift_far = 2.0;
// The trainer's 0.3 square pixels of blur, in the drawn pixels' terms.
uniform float low_pass = 0.3;
// Each bone's move from the still (SplatHead.pose_bones): six numbers a bone, at most 16 bones.
uniform float moves[96];

varying vec2 d;
varying vec3 conic;
varying vec4 col;
// The canvas's own tint (the node's modulate, the show's fade), which COLOR carries into the vertex.
varying vec4 tint;

vec4 texel(sampler2D t, int w, int j) {
	return texelFetch(t, ivec2(j % w, j / w), 0);
}

// Point p moved by bone k's move...
vec2 moved(int k, vec2 p) {
	int o = k * 6;
	return vec2(moves[o] * p.x + moves[o + 2] * p.y + moves[o + 4], moves[o + 1] * p.x + moves[o + 3] * p.y + moves[o + 5]);
}

// ...and taken back to where it stood in the still.
vec2 unmoved(int k, vec2 p) {
	int o = k * 6;
	vec2 q = p - vec2(moves[o + 4], moves[o + 5]);
	float det = moves[o] * moves[o + 3] - moves[o + 2] * moves[o + 1];
	if (abs(det) < 1e-9) {
		return p;
	}
	return vec2(moves[o + 3] * q.x - moves[o + 2] * q.y, -moves[o + 1] * q.x + moves[o] * q.y) / det;
}

mat3 rot_of(vec4 q) {
	float w = q.x, x = q.y, y = q.z, z = q.w;
	return mat3(
		vec3(1.0 - 2.0 * (y * y + z * z), 2.0 * (x * y + w * z), 2.0 * (x * z - w * y)),
		vec3(2.0 * (x * y - w * z), 1.0 - 2.0 * (x * x + z * z), 2.0 * (y * z + w * x)),
		vec3(2.0 * (x * z + w * y), 2.0 * (y * z - w * x), 1.0 - 2.0 * (x * x + y * y)));
}

void vertex() {
	int base = INSTANCE_ID * per_splat;
	vec4 a = texel(splat_data, splat_width, base);
	vec4 b = texel(splat_data, splat_width, base + 1);
	vec4 c = texel(splat_data, splat_width, base + 2);
	vec4 e = texel(splat_data, splat_width, base + 3);
	vec3 place = a.xyz;
	vec3 logit = e.rgb;
	int bound = int(a.w + 0.5);
	float shifted = bound < triangles ? 1.0 - smoothstep(shift_near, shift_far, length(a.xyz)) : 0.0;
	// a splat that takes no shift (the body's, the head's, one far from its triangle) reads none of them
	for (int k = 0; k < 16 && shifted > 0.0; k++) {
		if (k >= expressions) {
			break;
		}
		place += shifted * expr[k] * texel(splat_data, splat_width, base + 4 + 2 * k).xyz;
		logit += shifted * expr[k] * texel(splat_data, splat_width, base + 5 + 2 * k).xyz;
	}
	int f = bound * 4;
	vec4 o = texel(frame_data, frame_width, f);
	vec4 x_axis = texel(frame_data, frame_width, f + 1);
	mat3 ax = mat3(x_axis.xyz, texel(frame_data, frame_width, f + 2).xyz, texel(frame_data, frame_width, f + 3).xyz);
	vec3 mean = o.xyz + o.w * (ax * place);
	// a body splat's second influence: where it rested in the still, moved by the other bone (or not at all)
	if (e.a > 0.5 && bound > triangles) {
		int second = int(floor(e.a)) - 2;
		float w = fract(e.a) / 0.98;
		vec2 rest = unmoved(bound - triangles - 1, mean.xy);
		vec2 other = second < 0 ? rest : moved(second - triangles - 1, rest);
		mean.xy = mix(mean.xy, other, w);
	}
	mat3 r = ax * rot_of(normalize(c));
	vec3 s = o.w * exp(b.xyz);
	mat3 m = mat3(r[0] * s.x, r[1] * s.y, r[2] * s.z);
	mat3 cov = m * transpose(m);
	float sa = cov[0][0] + low_pass;
	float sb = cov[0][1];
	float sc = cov[1][1] + low_pass;
	float det = max(sa * sc - sb * sb, 1e-12);
	float mid = 0.5 * (sa + sc);
	float disc = sqrt(max(mid * mid - det, 0.0));
	float l1 = mid + disc;
	float l2 = max(mid - disc, 1e-6);
	vec2 v1 = abs(sb) > 1e-9 ? normalize(vec2(sb, l1 - sa)) : (sa >= sc ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
	vec2 v2 = vec2(-v1.y, v1.x);
	vec2 off = VERTEX.x * 3.0 * sqrt(l1) * v1 + VERTEX.y * 3.0 * sqrt(l2) * v2;
	VERTEX = mean.xy + off;
	d = off;
	conic = vec3(sc, -sb, sa) / det;
	// a bone not seen: its splats clear (the frame's flag, its first axis's w)
	col = vec4(1.0 / (1.0 + exp(-logit)), b.w * x_axis.w);
	tint = COLOR;
}

void fragment() {
	float power = -0.5 * (conic.x * d.x * d.x + 2.0 * conic.y * d.x * d.y + conic.z * d.y * d.y);
	float alpha = min(0.99, col.a * exp(power));
	if (power > 0.0 || alpha < 1.0 / 255.0) {
		discard;
	}
	COLOR = vec4(col.rgb * tint.rgb, alpha * tint.a);
}
