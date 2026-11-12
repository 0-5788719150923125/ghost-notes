shader_type spatial;
render_mode cull_disabled;

// A map on a game's table (TableGame, next/tabletop.md): a painting, or plain paper until it is painted, under a grid the code draws so a square is exact. No grid for a game measured with a tape.

uniform sampler2D painting : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool painted = false;
uniform vec2 squares = vec2(20.0, 14.0);
uniform bool grid = true;
uniform vec3 paper : source_color = vec3(0.78, 0.72, 0.58);

void fragment() {
	vec3 c = painted ? texture(painting, UV).rgb : paper;
	if (grid) {
		vec2 cell = UV * squares;
		vec2 d = abs(fract(cell - 0.5) - 0.5);
		vec2 w = fwidth(cell) * 1.1;
		vec2 line = 1.0 - smoothstep(vec2(0.018), vec2(0.018) + w, d);
		c = mix(c, c * 0.42, max(line.x, line.y) * 0.65);
	}
	ALBEDO = c;
	ROUGHNESS = 0.82;
	SPECULAR = 0.2;
}
