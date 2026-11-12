// A liquid in its vessel (src/table/table_physics.gd, next/table_physics.md "Liquids"): the vessel's inside, drawn cut
// away above its surface and, where the cut is seen through, the surface itself at its true depth, level in the table's
// space however the vessel is turned. The surface's place, its turning (the swirl), the rings on it and where a stream
// falls on it come from the physics' bake, in the mesh's own space; time is handed in, never TIME, so a render and a
// scrub agree. The heights its ripples stand at (src/table/surface_waves.gd) shape the cut along the glass and the
// surface the eye's ray meets, lit by their slope.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/prop_liquid.gdshaderinc"
