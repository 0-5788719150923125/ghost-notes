// REDACTED WORDS HIDDEN OVER THE PICTURE (src/dispatch/dispatch_censor.gd): each box drawn is cracked along straight
// lines into large shards, each one flat, the average color of the frame under it - as an editor hides a name in a video
// after it was shot (2026-11-10, the user: "a big rectangle region with large straight cracks in it"). Drawn after the
// desk's 3D, it reads the finished frame back.
//
// THE CRACKS are a tree of lines per box (DispatchCensor.cracks), in box heights from its top left: a point's shard is the
// leaf its sides of them lead to (DispatchCensor.shard, line for line). A SHARD'S COLOR is read off a grid of taps over
// that shard's own bounds, each jittered in its cell so the grid never falls in step with the letters, averaged over the
// taps inside it - every shard as many taps whatever its size or the frame's, and never off the screen texture's mipmaps,
// which Godot blurs (every shard came out near the box's mean). Every point of a shard reads the same taps, so a shard is
// one color exactly.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
// each box (px): x0, y0, x1, y1; the aspect its cracks were laid on; its cracks and its shards' bounds
// (DispatchCensor.MOST, NODES and LEAVES)
uniform vec4 boxes[6];
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

void fragment() {
	int b = -1;
	for (int i = 0; i < 6; i++) {
		if (i >= count) {
			break;
		}
		vec4 q = boxes[i];
		if (pos.x >= q.x && pos.y >= q.y && pos.x <= q.z && pos.y <= q.w) {
			b = i;
			break;
		}
	}
	if (b < 0) {
		discard;
	}
	vec4 q = boxes[b];
	vec2 size = max(q.zw - q.xy, vec2(1.0));
	vec2 scale = vec2(aspects[b], 1.0) / size;
	int me = shard(b, (pos - q.xy) * scale);
	vec4 bb = leaves[b * LEAVES + me - NODES];
	vec2 cell = (bb.zw - bb.xy) / float(TAPS);
	vec3 sum = vec3(0.0);
	float n = 0.0;
	for (int j = 0; j < TAPS; j++) {
		for (int i = 0; i < TAPS; i++) {
			vec2 u = bb.xy + (vec2(float(i), float(j)) + 0.5 + jitter(i, j, me)) * cell;
			if (shard(b, u) == me) {
				sum += texture(screen, (q.xy + u / scale) * SCREEN_PIXEL_SIZE).rgb;
				n += 1.0;
			}
		}
	}
	COLOR = vec4(n > 0.0 ? sum / n : texture(screen, (q.xy + (bb.xy + bb.zw) * 0.5 / scale) * SCREEN_PIXEL_SIZE).rgb, 1.0);
}
