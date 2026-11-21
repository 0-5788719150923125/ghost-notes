// The Look's fisheye: where a point of the frame shown reads the picture. Shared by the stage filter (the whole
// picture through it) and fisheye_straight.gdshader (a thing laid where the lens puts it back straight); mirrored line
// for line by Filters.lens, which a click on the stage goes through.
//
// The picture is taken as rectilinear with its corners FISHEYE_FIELD * sqrt(amount) off the axis and laid out as an
// equidistant fisheye: a point's angle from the middle spaced evenly, so the middle swells, the edges crowd and
// straight lines bow outward round the middle. The corners are pinned, so the frame stays full and nothing is read
// from outside the picture. The square root makes the bow grow evenly along the dial.

// The corners' angle off the axis at the top of the dial (75 degrees): the middle is then taken in nearly three times.
const float FISHEYE_FIELD = 1.309;

// [param uv] 0..1 across a frame [param aspect] wide to its one high; returns the picture's point, 0..1.
vec2 fisheye_lens(vec2 uv, float amount, float aspect) {
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
	// 0 at the middle, 1 in a corner; never quite 0, where the ratio below is its limit field / tan(field)
	float rho = max(length(p) / (0.5 * sqrt(aspect * aspect + 1.0)), 0.00001);
	float field = FISHEYE_FIELD * sqrt(amount);
	return 0.5 + (uv - 0.5) * (tan(rho * field) / (tan(field) * rho));
}
