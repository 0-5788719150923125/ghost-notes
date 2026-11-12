extends RefCounted
class_name ShadowFilter

## ShadowFilter - a positional light's shadow, softened by a filter of a set width and never by the
## light's size.
## Given a `light_size`, Godot searches the map for what stands in front and blurs by how far off that is (PCSS),
## which fails on a tabletop: the search takes no bias, so a surface the light grazes finds itself in front of the
## light and shades half its own pool in rings, and where a caster stands close over what it shades the blur shrinks
## to nothing and the map's texels show as stairs. Without a size the shadow is a filter of `shadow_blur` texels
## (PCF): never narrower than that, and a normal bias as wide as the filter keeps a surface out of its own shadow.
## A size also widens a light's highlights (its specular term takes the size), so a filter makes a candle's glint on
## a glossy thing smaller. Godot gives the two only together; sized but unblurred is an unfiltered shadow.
##
## [method filter] sets both from one number, the filter's radius in texels of the light's own map: the same width at
## any quality ([method quality_radius]) and any map size (Godot's normal bias is counted in the map's texels too). A
## shadow's softness is then its texels' angle seen from the light: a bigger shadow atlas makes a stage's shadows
## finer, at the cost of a bigger normal bias, which wipes out the shadows of things thinner than it lifts.
##
## An omni light's map is its cube: Godot draws its six faces at half its atlas slot and copies them into the slot's
## two paraboloids, where its `shadow_blur` is counted, so a filter counted in the slot's texels spans a texel and a
## half of the cube and the cube's stairs show through it. Counted in the cube's own texels ([constant OMNI_MAP]),
## shadows come out smooth.

## The radius Godot multiplies a filter's `shadow_blur` by at each of the project's soft shadow
## qualities (RendererSceneRenderRD: hard, very low, low, medium, high, ultra).
const QUALITY_RADIUS := [1.0, 1.5, 2.0, 2.0, 3.0, 4.0]
const QUALITY_SETTING := "rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality"
## How many of its atlas slot's texels make one of an omni light's own: Godot draws its cube at half the
## slot (RendererSceneRenderRD, `shadow_size / 2`).
const OMNI_MAP := 2.0


## The radius the project's soft shadow quality spreads a filter's `shadow_blur` over.
static func quality_radius() -> float:
	var q := int(ProjectSettings.get_setting(QUALITY_SETTING, 2))
	return float(QUALITY_RADIUS[clampi(q, 0, QUALITY_RADIUS.size() - 1)])


## [param light]'s shadow filtered [param texels] wide (the filter's radius, in texels of its own
## shadow map - an omni light's cube), with the normal bias that filter needs. A spot's angle is read,
## so set it first.
static func filter(light: Light3D, texels: float) -> void:
	light.light_size = 0.0
	light.shadow_blur = blur(texels * (OMNI_MAP if _cubed(light) else 1.0))
	light.shadow_normal_bias = normal_bias(light, texels)


## Whether [param light] draws its shadow as a cube copied into its slot (an omni light in cube mode) - its own texels then OMNI_MAP of the
## slot's; one drawn straight into its paraboloids reads the slot itself.
static func _cubed(light: Light3D) -> bool:
	return light is OmniLight3D and (light as OmniLight3D).omni_shadow_mode == OmniLight3D.SHADOW_CUBE


## The `shadow_blur` that filters a light without a size [param texels] wide at the project's
## quality: a light whose biases were tuned by hand keeps its softness when the quality changes.
static func blur(texels: float) -> float:
	return texels / quality_radius()


## The normal bias that keeps a surface out of its own shadow under a filter [param texels] wide.
## Godot reads a shadow off the surface, moved along its normal by `shadow_normal_bias` x 10 texels'
## angle as the light sees them (10 / N radians for a map N texels wide), times 1 - |N.L| - all of it
## at a graze, where the filter's lower half would read the surface itself. The move must clear the
## filter and the texel the map rounds the surface to: an omni light's filter, [param texels] of its cube
## (each OMNI_MAP of the slot's), reaches 4 x texels / N radians and its coarsest texel (the middle of a
## cube face, rendered at N / 2) 4 / N; a spot's filter is texels of its own and one more, each
## 2 tan(angle) / N. Taken at 1 - |N.L| = 0.8 (a graze of 12 degrees): nearer the normal the depth bias
## clears it.
static func normal_bias(light: Light3D, texels: float) -> float:
	if light is SpotLight3D:
		return (texels + 1.0) * tan(deg_to_rad((light as SpotLight3D).spot_angle)) / 4.0
	if not _cubed(light):
		# drawn straight into its paraboloids: its filter 2 x texels / N, its coarsest texel (a pole's) 4 / N
		return (texels + 2.0) / 4.0
	return (texels + 1.0) / 2.0
