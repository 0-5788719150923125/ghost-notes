// VALUE NOISE ON AN INTEGER HASH, for the light (src/lights.gd): the same numbers on the GPU as in
// Lights' own reckoning on the CPU (Lights.noise, Lights.fbm), so the shade the set dresser is told
// falls on the cards is the shade that is drawn. A float hash (noise_common's `fract(...)` products)
// drifts apart between the two at these coordinates; 32-bit integer arithmetic does not. Both
// multipliers are under 2^31, so GDScript's 64-bit ints hold their products whole.

uint lhash(uint x) {
	x ^= x >> 15u;
	x *= 739982445u;
	x ^= x >> 12u;
	x *= 695872825u;
	x ^= x >> 15u;
	return x;
}

float lcell(int x, int y, uint salt) {
	return float(lhash(lhash(uint(x) ^ salt) ^ uint(y)) & 65535u) / 65535.0;
}

float lnoise(vec2 p, uint salt) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	int x = int(i.x);
	int y = int(i.y);
	return mix(mix(lcell(x, y, salt), lcell(x + 1, y, salt), u.x),
		mix(lcell(x, y + 1, salt), lcell(x + 1, y + 1, salt), u.x), u.y);
}

// four octaves, each turned about 37 degrees and twice as fine
float lfbm(vec2 p, uint salt) {
	float s = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		s += a * lnoise(p, salt + uint(k) * 1013u);
		p = vec2(p.x * 1.6 - p.y * 1.2, p.x * 1.2 + p.y * 1.6) + vec2(5.3, 1.7);
		a *= 0.5;
	}
	return s / 0.9375;
}
