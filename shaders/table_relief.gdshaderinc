// HOW A TABLE SURFACE'S RELIEF IS SEEN (see table_common.gdshaderinc): included after the shader
// defines `float natural(vec2 p, float aa)` - its material's own relief, in [-1, 0].

// The whole height field at [param p], millimeters below the surface (<= 0).
float height_mm(vec2 p, float aa, float lod, float hem) {
	float h = natural(p, aa) * natural_depth;
	// a painted surface's own relief, where the painter drew its height: the painting's depth
	if (relief == 1 && has_height > 0.5) {
		h += (painting_detail(p, lod) - 1.0) * natural_depth;
	}
	if (relief >= 2) {
		h += shaped(p, aa, lod, hem) * relief_depth;
	}
	return h;
}

// The deepest the field goes, millimeters.
float depth_mm() {
	return natural_depth * (relief == 1 && has_height > 0.5 ? 2.0 : 1.0) + (relief >= 2 ? relief_depth : 0.0);
}

// THE SURFACE'S OWN FRAME in view space, from how its flat space (UV, cm) runs across the screen -
// exact per triangle, so the normal it bends is smooth (a height's own screen derivatives, the old
// way, are 2x2 blocks). Columns: across (u), along (v), the normal.
mat3 surface_frame(vec3 pos, vec3 n, vec2 uv) {
	vec3 dp1 = dFdx(pos);
	vec3 dp2 = dFdy(pos);
	vec2 du1 = dFdx(uv);
	vec2 du2 = dFdy(uv);
	vec3 p2 = cross(dp2, n);
	vec3 p1 = cross(n, dp1);
	vec3 t = p2 * du1.x + p1 * du2.x;
	vec3 b = p2 * du1.y + p1 * du2.y;
	float k = inversesqrt(max(max(dot(t, t), dot(b, b)), 1e-30));
	t *= k;
	b *= k;
	if (dot(t, t) < 1e-12 || dot(b, b) < 1e-12) {
		t = normalize(cross(n, abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
		b = cross(n, t);
	}
	return mat3(normalize(t), normalize(b), n);
}

// PARALLAX: where the line of sight through [param p] first meets the field below the surface - the
// point the pixel really shows, its hollows hidden behind the ridges in front of them. [param vt] is
// the eye's direction in the surface's frame (z out of it). Steep steps, then one refinement.
vec2 parallax(vec2 p, vec3 vt, float aa, float lod, float hem) {
	float dmax = depth_mm();
	if (dmax < 0.05 || vt.z < 0.02) {
		return p;
	}
	// centimeters along the surface per millimeter down
	vec2 dir = -vt.xy / max(vt.z, 0.12) * 0.1;
	int n = int(mix(22.0, 6.0, clamp(vt.z, 0.0, 1.0)));
	float step_mm = dmax / float(n);
	float d = 0.0;
	float h = -height_mm(p, aa, lod, hem);
	float pd = 0.0;
	float ph = h;
	for (int i = 0; i < 24; i++) {
		if (i >= n || d >= h) {
			break;
		}
		pd = d;
		ph = h;
		d += step_mm;
		h = -height_mm(p + dir * d, aa, lod, hem);
	}
	float a = ph - pd;
	float b = h - d;
	float t = a / max(a - b, 1e-5);
	return p + dir * mix(pd, d, clamp(t, 0.0, 1.0));
}

// THE NORMAL the field bends [param frame]'s to at [param p]: its slope there, from the field itself
// a fraction of a pixel either side - millimeters over centimeters, a tenth of a slope.
vec3 relief_normal(mat3 frame, vec2 p, float aa, float lod, float hem) {
	if (depth_mm() < 0.005) {
		return frame[2];
	}
	float e = max(aa * 0.5, 0.004);
	float hx = height_mm(p + vec2(e, 0.0), aa, lod, hem) - height_mm(p - vec2(e, 0.0), aa, lod, hem);
	float hz = height_mm(p + vec2(0.0, e), aa, lod, hem) - height_mm(p - vec2(0.0, e), aa, lod, hem);
	vec2 slope = vec2(hx, hz) / (2.0 * e) * 0.1;
	return normalize(frame[2] - frame[0] * slope.x - frame[1] * slope.y);
}
