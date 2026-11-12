shader_type spatial;
// Words written on a sheet (src/table/sheet_writing.gd): `words` holds in R how much ink a point has and in G when in the
// writing it is put down (0 the first, 0.98 the last: line by line, left to right); `written` is how far the unseen pen
// has got, 0 to 1. Lit as the sheet is, laid just over it.
render_mode blend_mix, depth_draw_never, cull_disabled;

// anisotropic: a sheet lies flat on the table, seen at a slant (Graphics' Texture filtering)
uniform sampler2D words : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 ink : source_color = vec3(0.14, 0.11, 0.086);
uniform float written = 1.0;
// how sharp the pen's front is in `written`: a page of N writes N times as sharp, each write its own share (SheetWriting.page)
uniform float sharp = 100.0;

void fragment() {
	vec2 w = texture(words, UV).rg;
	// the pen's front: put down by now, a little soft so it moves as a line drawn, never in steps
	float pen = clamp((written - w.y) * sharp, 0.0, 1.0);
	ALBEDO = ink;
	ROUGHNESS = 0.6;
	SPECULAR = 0.35;
	ALPHA = w.x * pen;
}
