// THE LIKENESS'S ONE PASS (next/likeness.md, "The second build", "The third pass"): their still, bent by
// the mesh, with the mouth and the eyes drawn from their own, cut out by their matte over the room.
//
// The mesh is drawn over the whole frame. Each vertex sits where the moved and bent face puts it
// (VERTEX), reads the still where that point really is (UV), and the library's box where it is in the
// layout (COLOR.rg, carried as a varying): the GPU interpolates both across each triangle, which is a
// piecewise affine warp of each, for nothing.
//
// Inside the mouth's mask (tight to the lips) up to two library mouths are mixed with the still's own
// mouth by their weights; inside the eyes' mask, up to two library eyes with the still's own. Each image
// is matched to the still's light first - its gain and offset per channel, from the cheeks' mean and
// spread in its own frame and in the still. Everything is sRGB, blended as it is.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2DArray library : filter_linear, repeat_disable;
uniform sampler2D mouth_mask : filter_linear, repeat_disable;
uniform sampler2D eye_mask : filter_linear, repeat_disable;
// the mouth's two images (layers), their weights (the still's own is what is left), and their light
uniform vec2 m_layers = vec2(0.0);
uniform vec2 m_weights = vec2(0.0);
uniform vec3 m_gain0 = vec3(1.0);
uniform vec3 m_gain1 = vec3(1.0);
uniform vec3 m_off0 = vec3(0.0);
uniform vec3 m_off1 = vec3(0.0);
// ...and the eyes'
uniform vec2 e_layers = vec2(0.0);
uniform vec2 e_weights = vec2(0.0);
uniform vec3 e_gain0 = vec3(1.0);
uniform vec3 e_gain1 = vec3(1.0);
uniform vec3 e_off0 = vec3(0.0);
uniform vec3 e_off1 = vec3(0.0);
// 0 draws the still alone (the identity test, and a set with no library)
uniform float library_on = 1.0;
// THEIR MATTE, read where the still is: them, over the room drawn under (the third pass). Off, the
// still is drawn whole, its own room and all.
uniform sampler2D matte : filter_linear, repeat_disable;
uniform float matte_on = 0.0;
// a debug view: 1 shows where the masks reach
uniform float show_mask = 0.0;

varying vec2 lay_uv;

void vertex() {
	lay_uv = COLOR.rg;
	COLOR = vec4(1.0);
}

vec3 from_library(float layer, vec3 gain, vec3 off) {
	return texture(library, vec3(lay_uv, layer)).rgb * gain + off;
}

void fragment() {
	vec3 base = texture(TEXTURE, UV).rgb;
	vec2 inside = step(vec2(0.0), lay_uv) * step(lay_uv, vec2(1.0));
	float in_box = library_on * inside.x * inside.y;
	float mm = in_box * texture(mouth_mask, lay_uv).r;
	float em = in_box * texture(eye_mask, lay_uv).r;
	vec3 col = base;
	if (mm > 0.001 && m_weights.x + m_weights.y > 0.001) {
		vec3 m = base * (1.0 - m_weights.x - m_weights.y)
			+ m_weights.x * from_library(m_layers.x, m_gain0, m_off0)
			+ m_weights.y * from_library(m_layers.y, m_gain1, m_off1);
		col = mix(col, clamp(m, 0.0, 1.0), mm);
	}
	if (em > 0.001 && e_weights.x + e_weights.y > 0.001) {
		vec3 e = col * (1.0 - e_weights.x - e_weights.y)
			+ e_weights.x * from_library(e_layers.x, e_gain0, e_off0)
			+ e_weights.y * from_library(e_layers.y, e_gain1, e_off1);
		col = mix(col, clamp(e, 0.0, 1.0), em);
	}
	col = mix(col, vec3(1.0, 0.0, 1.0), show_mask * max(mm, em) * 0.5);
	COLOR = vec4(col, matte_on > 0.5 ? texture(matte, UV).r : 1.0);
}
