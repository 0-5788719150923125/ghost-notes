// A LIQUID IN ITS VESSEL (src/table/table_physics.gd, next/table_physics.md "Liquids"): the vessel's inside, drawn
// cut away above its surface - and, where the cut is seen through, the surface itself at its true depth, level in
// the table's space however the vessel is turned. The user, 2026-10-28: "The liquids are not liquids". The surface's
// place, its turning (the swirl), the rings on it and where a stream falls on it are handed in by the physics' bake,
// all in the mesh's own space, and the time is handed in - never TIME - so a render and a scrub agree. ITS SHAPE TOO
// (2026-10-29, the ladle going round in its cauldron: "I am not seeing any water physics, surface tension, or any of
// that"): the heights its ripples stand at (src/table/surface_waves.gd), and its curve as it turns - the cut along the
// glass follows them, and the surface is where the eye's ray meets them, its light by their slope.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/prop_liquid.gdshaderinc"
