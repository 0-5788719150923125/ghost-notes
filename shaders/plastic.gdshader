// A molded part's plastic (src/table/assembly_meshes.gd): one color per instance, the color in the plastic itself. Glossy, a clear
// highlight over its color, a little light through its edges; each piece a hair different in its gloss and its shade, as parts of
// different ages in one tub are (INSTANCE_CUSTOM.r: how worn it is, 0-1).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

varying vec3 tint;
varying float worn;

void vertex() {
	tint = COLOR.rgb;
	worn = INSTANCE_CUSTOM.r;
}

void fragment() {
	ALBEDO = tint * (0.96 + 0.08 * worn);
	ROUGHNESS = mix(0.2, 0.42, worn);
	SPECULAR = 0.5;
	METALLIC = 0.0;
	CLEARCOAT = 0.35;
	CLEARCOAT_ROUGHNESS = mix(0.1, 0.3, worn);
	BACKLIGHT = tint * 0.18;
}
