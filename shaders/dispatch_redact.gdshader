// Redacted words hidden over the picture (src/dispatch/dispatch_censor.gd): each box is cracked along straight lines into
// large flat shards, each the average color of the frame under it, as an editor hides a name in a video. Drawn after the
// desk's 3D, it reads the finished frame back.
//
// The cracks are a tree of lines per box (DispatchCensor.cracks), in box heights from its top left; a point's shard is the
// leaf its sides of them lead to (DispatchCensor.shard, line for line). A shard's color is the average of a grid of taps
// over its own bounds, each jittered in its cell so the grid does not fall in step with the letters; every shard gets
// the same number of taps, and none are read from the screen texture's mipmaps (Godot blurs them, so every shard would
// come out near the box's mean). Every point of a shard reads the same taps, so a shard is one color.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
// each box (px): its center and half its size, turned by its angle round its center (its words' baseline); the aspect its
// cracks were laid on; its cracks and its shards' bounds (DispatchCensor.MOST, NODES and LEAVES)
uniform vec4 boxes[6];
uniform float angles[6];
uniform float aspects[6];
uniform vec3 cracks[378];
uniform vec4 leaves[384];
uniform int count = 0;

const int DEPTH = 6;
const int NODES = 63;
const int LEAVES = 64;
// taps across a shard's bounds, each way
const int TAPS = 16;

varying vec2 pos;

void vertex() {
	pos = VERTEX;
}

int shard(int b, vec2 p) {
	int n = 0;
	for (int d = 0; d < DEPTH; d++) {
		vec3 k = cracks[b * NODES + n];
		n = 2 * n + (k.x * p.x + k.y * p.y + k.z < 0.0 ? 1 : 2);
	}
	return n;
}

// where in its cell tap (i, j) lies: -0.4 to 0.4 of the cell each way
vec2 jitter(int i, int j, int leaf) {
	uint h = uint(i) * 73856093u ^ uint(j) * 19349663u ^ uint(leaf) * 83492791u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return vec2(float(h & 1023u), float((h >> 10u) & 1023u)) / 1023.0 * 0.8 - 0.4;
}

// frame point p in box b's own frame, from its top left along its baseline (DispatchCensor.local), and back
vec2 to_box(int b, vec2 p) {
	float c = cos(angles[b]);
	float s = sin(angles[b]);
	vec2 d = p - boxes[b].xy;
	return vec2(c * d.x + s * d.y, -s * d.x + c * d.y) + boxes[b].zw;
}

vec2 to_frame(int b, vec2 l) {
	float c = cos(angles[b]);
	float s = sin(angles[b]);
	vec2 d = l - boxes[b].zw;
	return boxes[b].xy + vec2(c * d.x - s * d.y, s * d.x + c * d.y);
}

void fragment() {
	int b = -1;
	for (int i = 0; i < 6; i++) {
		if (i >= count) {
			break;
		}
		vec2 l = to_box(i, pos);
		vec2 s2 = boxes[i].zw * 2.0;
		if (l.x >= 0.0 && l.y >= 0.0 && l.x <= s2.x && l.y <= s2.y) {
			b = i;
			break;
		}
	}
	if (b < 0) {
		discard;
	}
	vec2 size = max(boxes[b].zw * 2.0, vec2(1.0));
	vec2 scale = vec2(aspects[b], 1.0) / size;
	int me = shard(b, to_box(b, pos) * scale);
	vec4 bb = leaves[b * LEAVES + me - NODES];
	vec2 cell = (bb.zw - bb.xy) / float(TAPS);
	vec3 sum = vec3(0.0);
	float n = 0.0;
	for (int j = 0; j < TAPS; j++) {
		for (int i = 0; i < TAPS; i++) {
			vec2 u = bb.xy + (vec2(float(i), float(j)) + 0.5 + jitter(i, j, me)) * cell;
			if (shard(b, u) == me) {
				sum += texture(screen, to_frame(b, u / scale) * SCREEN_PIXEL_SIZE).rgb;
				n += 1.0;
			}
		}
	}
	COLOR = vec4(n > 0.0 ? sum / n : texture(screen, to_frame(b, (bb.xy + bb.zw) * 0.5 / scale) * SCREEN_PIXEL_SIZE).rgb, 1.0);
}
