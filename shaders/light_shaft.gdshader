// A shaft of light through haze ([LightShafts]), worked out for each pixel from where the line of sight passes the shaft's axis: as
// bright as the haze it crosses inside the shaft is deep - most through the middle, soft at the edges, whose blur (the penumbra, the
// sun's own width) grows the further below the gap it came through - and only as deep as the haze before whatever stands inside it, so
// a floor or a mug cuts it where it stands. Fading in below the gap and on past where it lands. Faint streaks run down it, dust drifts
// in it, it is brighter looking toward its light than away (haze throws light forward), and it may shimmer.
//
// Where what is seen stands inside the shaft, it is lit: what the screen shows there made `lands` times brighter, as squarely as the
// surface faces the light, its edge the shaft's own - so a dark thing stays darker than a pale one. Drawn, not lit: no glint, no
// bounce, no shadow behind what it falls on. The mesh is only a column round the shaft, wide enough for its blur. Drawn added; never
// worked out in the volumetric fog, whose grid blurs a narrow shaft.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0);
// how bright it is through its middle, and how many times brighter it makes what it lands on
uniform float strength = 0.3;
uniform float lands = 4.0;
// what it lands on is taken as at least this bright, so a patch shows on the darkest thing
uniform float lands_least = 0.01;
// show time (s): the dust drifting in it, and its shimmer
uniform float t = 0.0;
// how far (m) it runs from the gap to where it lands, and on past that, fading: the mesh runs +(reach + sink)/2 (the gap) to
// -(reach + sink)/2
uniform float reach = 3.0;
uniform float sink = 0.75;
// how much its edge blurs a meter below the gap (radians: the sun's width), and its own softness at the gap (a share of its radius)
uniform float penumbra = 0.0093;
uniform float soft = 0.2;
// how much it shimmers, 0 to 1
uniform float flicker = 0.0;
// how strongly faint streaks run down it, and how much the haze in it thickens and thins along it
uniform float streaks = 0.35;
uniform float clouds = 0.3;
// how much the haze throws light forward (a Henyey-Greenstein g)
uniform float forward = 0.3;
// the longest a line of sight along it lights it, over one across it
uniform float along_most = 3.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

// each shaft's own: its radius at the gap (m), its share of the brightness, and its phase
instance uniform float radius = 0.02;
instance uniform float glow = 1.0;
instance uniform float phase = 0.0;

// the shaft's axis in view space: its middle, and the way to the gap
varying vec3 axis_at;
varying vec3 axis_way;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float waver(float time, float p) {
	return clamp(0.5 + 0.3 * sin(time * 1.3 + p) + 0.2 * sin(time * 2.9 + p * 1.7), 0.0, 1.0);
}

// how lit a point [near] (m) off the axis is, [below] (m) under the gap: whole inside, nothing past its blurred edge, a little dimmer
// the more its edge has blurred ([method LightShafts.lit], line for line)
float lit(float near, float below) {
	float edge = radius * soft + penumbra * max(below, 0.0);
	float outer = radius + 0.5 * edge;
	float inner = max(radius - 0.5 * edge, 0.0);
	return smoothstep(outer, inner, near) * sqrt(radius / outer);
}

void vertex() {
	axis_at = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	axis_way = normalize((MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void fragment() {
	// where the line of sight (from the eye, view space's origin) passes nearest the axis: how far along each, and how near
	vec3 ray = normalize(VERTEX);
	vec3 a = normalize(axis_way);
	vec3 w = -axis_at;
	float b = dot(ray, a);
	float sin_t = sqrt(max(1.0 - b * b, 1e-6));
	float rd = dot(ray, w);
	float ae = dot(a, w);
	float s = (b * ae - rd) / (sin_t * sin_t);
	float u = (ae - b * rd) / (sin_t * sin_t);
	vec3 off = w + s * ray - u * a;
	float near = length(off);
	float below = (reach + sink) * 0.5 - u;
	float along = below / reach;
	float outer = radius + 0.5 * (radius * soft + penumbra * max(below, 0.0));
	// the depth of haze crossed: a chord of the column, longer for a line of sight along it
	float chord = sqrt(max(1.0 - (near / outer) * (near / outer), 0.0));
	float deep = min(1.0 / sin_t, along_most);
	// only the haze in front of what stands inside it lights
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	float half_in = sqrt(max(outer * outer - near * near, 0.0)) / sin_t;
	float enter = max(s - half_in, 0.0);
	float meets = clamp((length(behind.xyz) - enter) / max(s + half_in - enter, 1e-4), 0.0, 1.0);
	float ends = smoothstep(0.0, 0.18, along) * (1.0 - smoothstep(1.0, 1.0 + sink / reach, along));
	// streaks down its length across it as seen, barely changing along it; dust drifting down it; the haze thick and thin along it
	float across = dot(off, normalize(cross(ray, a))) / outer;
	float streak = mix(1.0, 0.45 + 1.1 * noise(vec2(across * 2.6 + phase * 3.0, along * 0.35)), streaks);
	float drift = along * reach * 2.3 - t * 0.08;
	float dust = 0.82 + 0.18 * noise(vec2(across * 2.5 + 17.0, drift));
	float cloud = mix(1.0, 0.55 + 0.9 * noise(vec2(phase * 5.0, along * reach * 0.9 - t * 0.04)), clouds);
	// haze throws light forward: brighter looking toward the light (up its axis), dimmer looking away, as at its side seen across
	float c = dot(a, ray);
	float g2 = forward * forward;
	float scatter = min(pow(1.0 + g2, 1.5) / pow(max(1.0 + g2 - 2.0 * forward * c, 1e-4), 1.5), 3.0);
	float shimmer = 1.0 - flicker * waver(t, phase);
	vec3 haze = color * strength * glow * lit(near, below) * chord * deep * meets * ends * streak * dust * cloud * scatter;
	// what is seen there, where it stands inside the shaft: lit as squarely as it faces the light
	vec3 pa = behind.xyz - axis_at;
	float pu = dot(pa, a);
	float p_below = (reach + sink) * 0.5 - pu;
	float p_ends = smoothstep(0.0, 0.05, p_below / reach) * (1.0 - smoothstep(1.0, 1.0 + sink / reach, p_below / reach));
	vec3 n = cross(dFdx(behind.xyz), dFdy(behind.xyz));
	n = normalize(dot(n, behind.xyz) > 0.0 ? -n : n);
	float facing = max(dot(n, a), 0.0);
	vec3 seen = texture(screen_tex, SCREEN_UV).rgb + vec3(lands_least);
	vec3 landed = seen * color * lands * strength * glow * lit(length(pa - pu * a), p_below) * facing * p_ends;
	ALBEDO = (haze + landed) * shimmer;
}
