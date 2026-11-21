shader_type canvas_item;

// A thing drawn into the stage that stays straight under the Look's fisheye, as the subtitles above the stage do: each
// vertex is moved to the point of the picture the lens shows where it was laid, so the stage's fisheye puts it back.
// For a canvas item whose local space is the stage viewport's pixels (the title card). A glyph is small enough that its
// corners carry it; a long edge between two vertices bows a little, so a big shape wants soft edges.

#include "res://shaders/fisheye.gdshaderinc"

// The viewport's size in pixels, and the fisheye the stage shows it through (0 off).
uniform vec2 u_size = vec2(1920.0, 1080.0);
uniform float u_fisheye : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	if (u_fisheye > 0.0) {
		VERTEX = fisheye_lens(VERTEX / u_size, u_fisheye, u_size.x / max(u_size.y, 1.0)) * u_size;
	}
}
