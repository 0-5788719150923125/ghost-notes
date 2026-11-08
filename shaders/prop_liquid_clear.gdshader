// A CLEAR LIQUID IN ITS VESSEL - water (src/table/table_physics.gd picks it by clarity, TablePhysics.CLEAR_LIQUID): the opaque
// liquid's body (prop_liquid.gdshaderinc) seen through as far as it is clear, and less as what is rinsed in it clouds it. The user,
// 2026-11-07 (feedback 0050's note): "the water starts opaque white. Perhaps it should start clear, and inherit colors based upon the
// volume coming off of brushes and sponges ... it would accumulate color over time, not immediately." Drawn under the glass round it
// (render_priority -1), never over it.
shader_type spatial;
render_mode blend_premul_alpha, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#define CLEAR
#include "res://shaders/prop_liquid.gdshaderinc"
