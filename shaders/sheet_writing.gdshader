shader_type spatial;
// WORDS WRITTEN ON A SHEET (src/table/sheet_writing.gd): `words` holds in R how much ink a point has and in G when in the
// writing it is put down (0 the first, 0.98 the last: line by line, left to right); `written` is how far the unseen pen
// has got, 0 to 1. Lit as the sheet is, laid just over it.
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D words : filter_linear_mipmap, repeat_disable;
uniform vec3 ink : source_color = vec3(0.14, 0.11, 0.086);
uniform float written = 1.0;

void fragment() {
	vec2 w = texture(words, UV).rg;
	// the pen's front: put down by now, a little soft so it moves as a line drawn, never in steps
	float pen = clamp((written - w.y) * 100.0, 0.0, 1.0);
	ALBEDO = ink;
	ROUGHNESS = 0.6;
	SPECULAR = 0.35;
	ALPHA = w.x * pen;
}
