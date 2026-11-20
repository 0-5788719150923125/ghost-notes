// Fog of an effect (see src/table/effects.gd): one FogVolume's density, rolling through its box as a function of SHOW TIME - the noise
// is carried by a wind (the light's own, or the fog's own gusting run, `carried`) and turns over itself - as low lying as `settle` says
// (Effects.fog_layer is the same profile), soft at its sides. Its noise becomes fog and clear air through the curve `shape` names
// (Effects.FOG_SHAPES, Effects.fog_activation the same curves); patches cut it into islands; `chaos` warps its noise by noise, varies
// its thickness from place to place and makes its sway's swings of every length; it sways in slow waves along the wind's way and
// breathes, rising thinner and sinking thicker. Every setting at its default is a bank as it always was. The scene's lights light it
// (Godot's own volumetric fog), so candles and lit motes glow inside it.
shader_type fog;

uniform float show_time = 0.0;
uniform vec3 color : source_color = vec3(0.75, 0.78, 0.82);
uniform float density = 1.0;
uniform float rolls = 0.5;
uniform vec3 wind = vec3(0.03, 0.01, 0.0);   // m/s the fog drifts on its own
uniform vec3 carried = vec3(0.0);            // how far a wind has carried the air, meters (none in still air)
uniform float grain = 0.25;                  // meters: the size of its swirls
uniform float floor_y = 0.0;                 // its floor, world meters
uniform float height = 0.25;                 // how high it reaches above its floor, meters
uniform float edge = 0.15;                   // how far in from its sides it thickens, meters
uniform float glow = 0.0;                    // light of its own
uniform float settle = 0.7;                  // 0 even to near its top, 0.7 a bank's, 1 thinning fast from the floor
uniform int shape = 0;                       // the curve its noise becomes fog through, in Effects.FOG_SHAPES' order
uniform float patches = 0.0;                 // 0 one sheet, toward 1 islands with clear air between
uniform float patch_size = 1.5;              // meters: a patch's size
uniform vec2 way = vec2(1.0, 0.0);           // the wind's way (x, z), a unit
uniform float stretch = 0.0;                 // its swirls drawn out along the way: 0 round, 1 four times as long
uniform float sway = 0.0;                    // meters it swings to either side along the way
uniform float sway_rate = 0.45;              // radians a second
uniform float breathe = 0.0;                 // how much its top rises and sinks
uniform float breath_rate = 0.28;            // radians a second
uniform float chaos = 0.0;                   // how irregular it all is

float fog_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float fog_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(fog_hash(i), fog_hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(fog_hash(i + vec3(0.0, 1.0, 0.0)), fog_hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(fog_hash(i + vec3(0.0, 0.0, 1.0)), fog_hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(fog_hash(i + vec3(0.0, 1.0, 1.0)), fog_hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float fog_fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * fog_noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

// Effects.fog_activation: how thick the fog is where its lifted noise is v (bare noise n0, for the wisps' ridge)
float fog_activation(float v, float n0) {
	if (shape == 1) {
		return mix(0.35, 1.0, smoothstep(0.25, 0.8, v));
	} else if (shape == 2) {
		return smoothstep(0.72, 0.96, 1.0 - abs(2.0 * n0 - 1.0) + (v - n0) * 0.5);
	} else if (shape == 3) {
		return smoothstep(0.5, 0.53, v);
	} else if (shape == 4) {
		return smoothstep(0.3, 0.55, v) * (0.5 + 0.5 * cos(v * 30.0));
	}
	return smoothstep(0.44, 0.72, v);
}

void fog() {
	vec3 w = WORLD_POSITION;
	float t = show_time;
	float c = chaos;
	vec3 along = vec3(way.x, 0.0, way.y);
	vec3 across = vec3(-way.y, 0.0, way.x);
	// SWAY: slow waves along the wind's way, each place a little behind the one upwind of it; chaos makes the swings of every length
	if (sway > 0.0) {
		float rt = sway_rate * t;
		float swing = rt + c * (1.4 * sin(0.37 * rt + 1.1) + 0.7 * sin(0.71 * rt + 2.3));
		float place = dot(w, along) * 2.1 + c * 4.0 * fog_noise(w * 0.4 + vec3(7.1));
		w -= along * sway * (1.0 + 0.45 * c * sin(0.29 * rt + 0.4)) * sin(swing - place);
	}
	vec3 p = w - wind * t - carried;
	// along the wind and across it, drawn out along it by its streaks (with the way left to right, as it was)
	p = vec3(dot(p, along) / (1.0 + 3.0 * stretch), p.y, dot(p, across));
	vec3 q = p / max(grain, 0.02);
	// ROLLING: the noise's own space turns slowly over itself, so the fog billows as it drifts
	q += rolls * 1.2 * vec3(sin(q.y * 0.71 + t * 0.13), sin(q.z * 0.63 + t * 0.11) * 0.6, sin(q.x * 0.52 + t * 0.17));
	// CHAOS folds the noise into itself: its space warped by noise of its own
	if (c > 0.0) {
		vec3 k = q * 0.37;
		q += c * 1.6 * (vec3(fog_noise(k + vec3(3.3, 0.0, 0.0)), fog_noise(k + vec3(0.0, 5.7, 0.0)), fog_noise(k + vec3(0.0, 0.0, 9.1))) - 0.5);
	}
	// billows (the noise at its grain) carved by finer wisps, so the fog has shape and not only depth
	float n = fog_fbm(q + vec3(0.0, -t * 0.02 / max(grain, 0.02), 0.0));
	n = n * 0.75 + 0.25 * fog_noise(q * 3.1 + vec3(t * 0.05, 0.0, 0.0));
	// BREATHING: its top rising and sinking, a little apart from place to place, thinner as it rises
	float top = height;
	float spread = 1.0;
	if (breathe > 0.0) {
		top *= 1.0 + 0.45 * breathe * sin(breath_rate * t - dot(w, along) * 1.3 - dot(w, across) * 0.7);
		spread = height / max(top, 0.01);
	}
	float h = clamp((w.y - floor_y) / max(top, 0.01), 0.0, 2.0);
	float layer = (1.0 - smoothstep((1.0 - settle) / 1.2, 1.0, h)) * exp(-5.0 * max(settle - 0.7, 0.0) / 0.3 * h);
	// Soft at its sides, never at its floor or its top: a layer lying on the cloth thickens toward the
	// cloth (the distance to the nearest face would thin it to nothing exactly there)
	vec2 e = vec2(edge) / max(SIZE.xz, vec2(0.01));
	float side = smoothstep(0.0, e.x, UVW.x) * smoothstep(0.0, e.x, 1.0 - UVW.x)
		* smoothstep(0.0, e.y, UVW.z) * smoothstep(0.0, e.y, 1.0 - UVW.z);
	// PATCHES: islands wide and flat, carried with it and slowly changing, their edges warped by chaos
	float mask = 1.0;
	if (patches > 0.0) {
		vec3 pp = p / max(patch_size, 0.05);
		pp.y = pp.y * 0.3 + t * 0.015;
		pp.xz += c * 0.8 * (vec2(fog_noise(pp * 1.7 + vec3(2.0)), fog_noise(pp * 1.7 + vec3(8.0))) - 0.5);
		float pn = fog_noise(pp) * 0.65 + fog_noise(pp * 2.3 + vec3(4.2)) * 0.35;
		float cut = mix(0.22, 0.68, patches);
		mask = smoothstep(cut - 0.1, cut + 0.1, pn);
	}
	// thick and thin from place to place, by chaos
	float shift = c > 0.0 ? c * 0.22 * (fog_noise(p / max(patch_size, 0.05) * 0.7 + vec3(11.0)) - 0.5) : 0.0;
	// BILLOWS with gaps between them (or the shape asked): thick where the noise is high, clear where it is low
	float d = density * spread * layer * side * mask * fog_activation(n + 0.15 * (1.0 - h) + shift, n);
	DENSITY = d;
	ALBEDO = color;
	EMISSION = color * glow * d;
}
