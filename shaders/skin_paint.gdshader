// ONE ELEMENT OF A PAINTED SURFACE (src/table/table_paint.gd): drawn in its skin's canvas where its tool has been - each point
// shown from the moment its program first covers it (its reveal map, `when_map`, 0-1 of its strokes' span), softened as it is
// blended, thinned as a powder's excess is swept off. One pass draws its color, the other (`finish_pass`) what its finish is:
// rough, metallic, glittering. A pure function of `now`, the show's time.
shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D cover : filter_linear_mipmap, repeat_disable;
// when its tool first reached each point (0-1 of its strokes' span), and how much of a full load the tool had on it then
uniform sampler2D when_map : filter_linear, repeat_disable;
uniform float now = 0.0;
// when its strokes lay it, when it is blended, when its excess is swept off (show time, seconds)
uniform vec2 span = vec2(1e9, 1e9);
uniform vec2 blend_span = vec2(1e9, 1e9);
uniform vec2 sweep_span = vec2(1e9, 1e9);
// how soft its edge is before and after it is blended (mip levels of its cover)
uniform vec2 lods = vec2(0.0, 0.0);
uniform vec4 paint : source_color = vec4(1.0);
uniform vec4 finish = vec4(0.6, 0.0, 0.0, 1.0);
uniform bool finish_pass = false;
uniform float opacity = 1.0;
// LAID BY PRESSES (1: a sponge's stipple, 2: a puff's pats; 0: drawn): each press leaves a thin, uneven film that the presses after it
// fill, its edge the foam's - never a drawn circle, never a grain the size of the picture's own pixels (feedback 0016: a stipple cut
// from noise at the canvas's pixel looked "like a pixel grid, when you would really expect it to be more like a fine dust")
uniform int pressed = 0;
// what a sweep leaves of it (a powder's excess)
uniform float swept = 1.0;
// how much of its color it lays (0: a mist, its finish alone), and - a mist - how long it takes to dry and what is left once dry
uniform float color_alpha = 1.0;
uniform float dries = 0.0;
uniform float dried = 1.0;
// its picture's size in millimeters, for the size of a sponge's pores
uniform vec2 mm = vec2(100.0);
// how long a point takes to come in as the tool passes (seconds)
const float EDGE = 0.18;
// A PRESS: how far its edge wanders from where the tool reached (millimeters), the film the first press leaves (a stipple's cream, a
// pat's powder) and how uneven it is, and how wide its unevenness runs (millimeters - wider than two of the canvas's pixels)
const float RAGGED = 1.6;
const vec2 FIRST = vec2(0.5, 0.32);
const float UNEVEN = 0.55;
const float GRAIN = 1.3;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// soft unevenness with no grid in it: value noise, each octave turned and shifted from the last
float fbm(vec2 p) {
	float sum = 0.0;
	float w = 0.5;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		sum += w * vnoise(p);
		p = turn * p * 2.03 + vec2(3.1, 1.7);
		w *= 0.5;
	}
	return sum / 0.9375;
}

void fragment() {
	vec2 q = UV * mm;
	vec2 at = UV;
	if (pressed > 0) {
		// ...its edge wanders, as a foam's or a puff's does
		vec2 wander = vec2(fbm(q * 0.35 + vec2(11.0, 3.0)), fbm(q * 0.35 + vec2(23.0, 17.0))) - 0.5;
		at += wander * 2.0 * RAGGED / max(mm, vec2(1.0));
	}
	// NEVER BEFORE THE TOOL GETS THERE: a point shows as its tool reaches it (feedback 0017: faded in over the time the tool took to
	// cross a millimeter of it, every border between two presses still to come showed for tens of seconds before them - "a faint
	// outline of EVERY place the sponge will place foundation ... before we actually place it")
	vec2 wl = texture(when_map, at).rg;
	float u = wl.r;
	float load = clamp(wl.g, 0.0, 1.0);
	float when = mix(span.x, span.y, u);
	float shown = smoothstep(when - EDGE, when + EDGE * 0.25, now);
	float b = smoothstep(blend_span.x, blend_span.y, now);
	float c = textureLod(cover, UV, mix(lods.x, lods.y, b)).a;
	float a = c * shown * opacity;
	if (pressed > 0) {
		// BUILT UP, NEVER CUT: the first press a thin uneven film - fainter as the tool runs dry, until it is loaded again - whole by
		// the strokes' end, the presses after it filling it
		float built = smoothstep(0.0, 1.0, clamp((now - when) / max(span.y - when, 0.6), 0.0, 1.0));
		float first = pressed == 1 ? FIRST.x : FIRST.y;
		float film = clamp(first + (fbm(q / GRAIN) - 0.5) * UNEVEN * 2.0 * first, 0.04, 1.0) * load;
		a *= mix(film, 1.0, built);
	} else {
		// ...a fill swept on, thinner where its brush ran dry
		a *= load;
	}
	a *= mix(1.0, swept, smoothstep(sweep_span.x, sweep_span.y, now));
	if (dries > 0.0) {
		a *= mix(1.0, dried, smoothstep(span.y, span.y + dries, now));
	}
	COLOR = finish_pass ? vec4(finish.rgb, a) : vec4(paint.rgb, a * color_alpha);
}
