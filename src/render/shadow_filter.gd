extends RefCounted
class_name ShadowFilter

## ShadowFilter - a positional light's shadow, softened by a filter of a set width and never by the
## light's size.
##
## Godot softens a light's shadow one of two ways. Given a `light_size` it searches the map for what
## stands in front and blurs by how far off that is (PCSS) - which on a tabletop fails twice (feedback
## 0007, a candlelit table). The search takes no bias at all, so a surface the light grazes finds
## ITSELF in front of the light, blurs wide and shades half its own pool, in rings round the flame (the
## cube map's texels, plainest on a card's dark back); and where a caster stands close over what it
## shades (a clock's rim over its face) the blur shrinks to nothing and the map's texels show as
## stairs, crawling as the flame flickers. Without a size it is a filter of `shadow_blur` texels (PCF):
## never narrower than that, and a normal bias as wide as the filter keeps a surface out of its own
## shadow. Measured on the episode of that report: the rings and the stairs gone, the cloth's open
## pools 12-30% brighter (the search had shaded them), the shadows of things near a flame darker and
## crisper (the old 3 cm search radius had washed them out). What a size also did and a filter cannot:
## Godot widens a sized light's highlights as a lamp that big would (its specular term takes the size),
## so a candle's glint on a glossy thing near it is smaller now - a headlamp's corner 13 cm off a flame
## lost its spark. Godot gives the two only together; sized but unblurred is an unfiltered shadow, and
## PCSS kept its stairs and rings on the bigger atlas and at a bigger normal bias too (measured).
##
## [method filter] sets both from one number, the filter's radius in texels of the light's own map -
## the same width at any quality ([method quality_radius]) and any map size (Godot's normal bias is
## counted in the map's texels too). The softness of a shadow is then its texels' angle seen from the
## light: what makes a stage's shadows finer is a bigger shadow atlas, and what it costs is a bigger
## normal bias, which wipes out the shadows of things thinner than it lifts.

## The radius Godot multiplies a filter's `shadow_blur` by at each of the project's soft shadow
## qualities (RendererSceneRenderRD: hard, very low, low, medium, high, ultra).
const QUALITY_RADIUS := [1.0, 1.5, 2.0, 2.0, 3.0, 4.0]
const QUALITY_SETTING := "rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality"


## The radius the project's soft shadow quality spreads a filter's `shadow_blur` over.
static func quality_radius() -> float:
	var q := int(ProjectSettings.get_setting(QUALITY_SETTING, 2))
	return float(QUALITY_RADIUS[clampi(q, 0, QUALITY_RADIUS.size() - 1)])


## [param light]'s shadow filtered [param texels] wide (the filter's radius, in texels of its own
## shadow map), with the normal bias that filter needs. A spot's angle is read, so set it first.
static func filter(light: Light3D, texels: float) -> void:
	light.light_size = 0.0
	light.shadow_blur = blur(texels)
	light.shadow_normal_bias = normal_bias(light, texels)


## The `shadow_blur` that filters a light without a size [param texels] wide at the project's
## quality: a light whose biases were tuned by hand keeps its softness when the quality changes.
static func blur(texels: float) -> float:
	return texels / quality_radius()


## THE NORMAL BIAS THAT KEEPS A SURFACE OUT OF ITS OWN SHADOW under a filter [param texels] wide.
## Godot reads a shadow off the surface, moved along its normal by `shadow_normal_bias` x 10 texels'
## angle as the light sees them (10 / N radians for a map N texels wide), times 1 - |N.L| - all of it
## at a graze, where the filter's lower half would read the surface itself. The move must clear the
## filter and the texel the map rounds the surface to: an omni light's filter reaches 2 x texels / N
## radians and its coarsest texel (the middle of a cube face, rendered at N / 2) 4 / N; a spot's
## filter is texels of its own and one more, each 2 tan(angle) / N. Taken at 1 - |N.L| = 0.8 (a graze
## of 12 degrees): nearer the normal the depth bias clears it.
static func normal_bias(light: Light3D, texels: float) -> float:
	if light is SpotLight3D:
		return (texels + 1.0) * tan(deg_to_rad((light as SpotLight3D).spot_angle)) / 4.0
	return (texels + 2.0) / 4.0
