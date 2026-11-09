// ONE ELEMENT OF A PAINTED SURFACE (src/table/table_paint.gd): drawn in its skin's canvas where its tool has been - each point
// shown from the moment its program first covers it (its reveal map, `when_map`, 0-1 of its strokes' span), softened as it is
// blended, thinned as a powder's excess is swept off. One pass draws its color, the other (`finish_pass`) what its finish is:
// rough, metallic, glittering. A pure function of `now`, the show's time.
// ITS OWN PAINT, NEVER THE PAINTING'S PIXELS: the face painted first (`face_ref.png`) is what its design was copied from, not what it
// lays. Laying the painting's own pixel wherever it was near an element's paint showed the whole design through the first base -
// "streaky tears under the eyes ... patterns on the forehead ... we are just revealing the underlying PNG through transparency
// manipulation" (feedback 0049, 2026-11-07): the painting says where and what, the tool lays the paint.
shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D cover : filter_linear_mipmap, repeat_disable;
// LAID WHERE ITS BRUSH TOUCHED, NOT WHERE ITS SHAPE IS (feedback 0042: "It's not clear why the grey paint only affects inside of the
// diamond, but doesn't touch the black lines or the outside of the eye... when the brush is touching the mask the entire time"): what
// its hairs touched, a smooth edge (Skins.foot_map) - drawn in place of its shape's cover
uniform sampler2D foot : filter_linear_mipmap, repeat_disable;
uniform bool footed = false;
// BLENDED WHERE THE BLENDING BRUSH WENT (feedback 0046: lips gone over with it were "fainter at the top, while smearing outside the lines
// at the bottom" - softened all over at once): when its hairs reached each point (0-1 of its blend's span, Skins.touch_map; a point
// they never reached keeps its edge)
uniform sampler2D blend_map : filter_linear, repeat_disable;
uniform bool blend_touched = false;
// when its tool first reached each point (0-1 of its strokes' span), and how much of a full load the tool had on it then
uniform sampler2D when_map : filter_linear, repeat_disable;
// BUILT UP AS IT WAS LAID (PaintLayers.render's `built`; the user, 2026-11-08: "the dabs are extremely heavy with paint. There is not
// opacity at all"): what each point holds after each of the first seven marks that reach it and after the last, and the moments of
// those (0-1 of its strokes' span) - each point shown at what the marks so far have laid there, never at what they all come to
uniform sampler2D laid_map : filter_linear, repeat_disable;
uniform sampler2D laid_when : filter_linear, repeat_disable;
// ...and the marks after those four, the last what it holds at the end
uniform sampler2D laid_map2 : filter_linear, repeat_disable;
uniform sampler2D laid_when2 : filter_linear, repeat_disable;
uniform bool laid_on = false;
// THE COLORS ITS MARKS CARRY (PaintLayers.render's `tint`): each point's own, where its marks were mixed on the palette or picked up
// from the surface by a clean brush - in place of its one paint
uniform sampler2D tint_map : source_color, filter_linear, repeat_disable;
uniform bool tinted = false;
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
// how long a point takes to come in as the tool passes (seconds), and to soften as a blending brush does
const float EDGE = 0.18;
const float BLEND_TAKES = 0.6;
// how long a press's film takes to fill as a later press touches it again (seconds)
const float AGAIN_TAKES = 0.4;
// A PRESS: how far its edge wanders from where the tool reached (millimeters), the film the first press leaves (a stipple's cream, a
// pat's powder) and how uneven it is, and how wide its unevenness runs (millimeters - wider than two of the canvas's pixels). A loaded
// sponge's one dab leaves most of its paint, the dabs after it only even it (2026-11-07: at half, every point touched once stayed a peach
// speck in a finished white coat)
const float RAGGED = 1.6;
const vec2 FIRST = vec2(0.85, 0.6);
const float UNEVEN = 0.3;
// ...and what of it a sponge all but run dry still leaves (a share of a full load's): the dab before it goes back for more had been faint
// enough to leave a peach speck in a white coat wherever nothing pressed there again
const float DRY_LEAST = 0.75;
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
	vec3 wl = texture(when_map, at).rgb;
	float u = wl.r;
	float load = clamp(wl.g, 0.0, 1.0);
	float when = mix(span.x, span.y, u);
	float shown = smoothstep(when - EDGE, when + EDGE * 0.25, now);
	float b = smoothstep(blend_span.x, blend_span.y, now);
	if (blend_touched) {
		float bw = mix(blend_span.x, blend_span.y, texture(blend_map, UV).r);
		b = smoothstep(bw - EDGE, bw + BLEND_TAKES, now);
	}
	float c = footed ? textureLod(foot, UV, mix(lods.x, lods.y, b)).r : textureLod(cover, UV, mix(lods.x, lods.y, b)).a;
	if (laid_on) {
		// (...the share of what it comes to that the marks so far have laid: each mark's coming in as the tool reaches it)
		vec4 bt = mix(vec4(span.x), vec4(span.y), texture(laid_when, at));
		vec4 bc = texture(laid_map, at);
		vec4 bt2 = mix(vec4(span.x), vec4(span.y), texture(laid_when2, at));
		vec4 bc2 = texture(laid_map2, at);
		float so_far = bc.r * smoothstep(bt.r - EDGE, bt.r + EDGE * 0.25, now);
		so_far = mix(so_far, bc.g, smoothstep(bt.g - EDGE, bt.g + EDGE * 0.25, now));
		so_far = mix(so_far, bc.b, smoothstep(bt.b - EDGE, bt.b + EDGE * 0.25, now));
		so_far = mix(so_far, bc.a, smoothstep(bt.a - EDGE, bt.a + EDGE * 0.25, now));
		so_far = mix(so_far, bc2.r, smoothstep(bt2.r - EDGE, bt2.r + EDGE * 0.25, now));
		so_far = mix(so_far, bc2.g, smoothstep(bt2.g - EDGE, bt2.g + EDGE * 0.25, now));
		so_far = mix(so_far, bc2.b, smoothstep(bt2.b - EDGE, bt2.b + EDGE * 0.25, now));
		so_far = mix(so_far, bc2.a, smoothstep(bt2.a - EDGE, bt2.a + EDGE * 0.25, now));
		c *= clamp(so_far / max(bc2.a, 1e-3), 0.0, 1.0);
	}
	float a = c * shown * opacity;
	if (pressed > 0) {
		// BUILT UP, NEVER CUT: the first press a thin uneven film - fainter as the tool runs dry, until it is loaded again - filled where
		// and when a later press touches it again (Skins.touch_map's third channel), and only there: thickened toward whole by the
		// strokes' end wherever it was, nothing touching, it had crept up to white ("the darker regions will sometimes slowly increase
		// their brightness to full white, even though nothing is touching those places", 2026-11-07)
		float again = mix(span.x, span.y, wl.b);
		float built = wl.b < 2.0 ? smoothstep(again - EDGE, again + AGAIN_TAKES, now) : 0.0;
		float first = pressed == 1 ? FIRST.x : FIRST.y;
		float film = clamp(first + (fbm(q / GRAIN) - 0.5) * UNEVEN * 2.0 * first, 0.04, 1.0) * mix(DRY_LEAST, 1.0, load);
		a *= mix(film, 1.0, built);
	} else {
		// ...a fill swept on, thinner where its brush ran dry
		a *= load;
	}
	a *= mix(1.0, swept, smoothstep(sweep_span.x, sweep_span.y, now));
	if (dries > 0.0) {
		a *= mix(1.0, dried, smoothstep(span.y, span.y + dries, now));
	}
	vec3 own = tinted ? texture(tint_map, at).rgb : paint.rgb;
	COLOR = finish_pass ? vec4(finish.rgb, a) : vec4(own, a * color_alpha);
}
