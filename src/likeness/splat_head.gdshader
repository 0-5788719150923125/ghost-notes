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
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D splat_data : filter_nearest;
uniform sampler2D frame_data : filter_nearest;
uniform int splat_width = 1024;
uniform int frame_width = 1024;
uniform int per_splat = 4;
// The expression a frame shows: its components (SplatHead.expr_of), and how many the splats were learned with.
uniform int expressions = 0;
uniform float expr[16];
// The trainer's 0.3 square pixels of blur, in the drawn pixels' terms.
uniform float low_pass = 0.3;

varying vec2 d;
varying vec3 conic;
varying vec4 col;
// The canvas's own tint (the node's modulate, the show's fade), which COLOR carries into the vertex.
varying vec4 tint;

vec4 texel(sampler2D t, int w, int j) {
	return texelFetch(t, ivec2(j % w, j / w), 0);
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
	for (int k = 0; k < 16; k++) {
		if (k >= expressions) {
			break;
		}
		place += expr[k] * texel(splat_data, splat_width, base + 4 + 2 * k).xyz;
		logit += expr[k] * texel(splat_data, splat_width, base + 5 + 2 * k).xyz;
	}
	int f = int(a.w + 0.5) * 4;
	vec4 o = texel(frame_data, frame_width, f);
	mat3 ax = mat3(texel(frame_data, frame_width, f + 1).xyz, texel(frame_data, frame_width, f + 2).xyz,
		texel(frame_data, frame_width, f + 3).xyz);
	vec3 mean = o.xyz + o.w * (ax * place);
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
	col = vec4(1.0 / (1.0 + exp(-logit)), b.w);
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
