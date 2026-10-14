extends RefCounted
class_name SceneRoster

## SceneRoster - the scenes in the rotation: the catalog's registry, kept with the catalog.
##
## The Director walks it ([method Director._pick]), a storyboard names its scenes from it, the
## storyboard's editor lists it, and docs/scenes.md is written from it - none of which needs the
## Director, so the list is not in the Director (next/structure.md, "A registry is in the folder
## of the thing it lists"). A scene file not listed here is reachable only by a storyboard
## (`stage`) or a medium that mints it itself (the comic's film).
##
## THE ORDER AND THE NAMES ARE THE SHOW'S. The Director picks by an entry's file name and
## behavior (`_scene_key`), so renaming a scene's file, or moving an entry's behavior, re-rolls
## every seeded show that drew it.

## Each entry pairs a scene script with a motion behavior (see GhostScene). The
## same scene appears more than once with different behaviors - that is how the
## original, un-modulated "static" looks are kept as first-class options.
const SCENES := [
	{"script": preload("res://src/scenes/spectrum_ring.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/spectrum_ring.gd"), "behavior": "fluid"},
	{"script": preload("res://src/scenes/harmonic_lattice.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/harmonic_lattice.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/rooted_growth.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/filaments.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/filaments.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/furry.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/furry.gd"), "behavior": "fluid"},
	{"script": preload("res://src/scenes/fog_lights.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/strata.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/bloom.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/bloom.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/wire_solid.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/planes.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/planes.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/voxel_blocks.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/cityscape.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/shatter_glass.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/gaussian_landscape.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/rocks.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/embers.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/metropolis.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/clockwork.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/clockwork.gd"), "behavior": "drift"},
	# Weather & atmosphere - composed from the shared Layer registry (see src/scene_kit/layer.gd).
	{"script": preload("res://src/scenes/snowfall.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/snowflakes.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/rainfall.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/clouds.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/clouds.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/fog_volume.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/fire.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/underwater.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/fireflies.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/starfield.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/starfield.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/aurora.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/fog_bank.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/petals.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/bubbles.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/motes.gd"), "behavior": "drift"},
	# Vapors - the FIELD half of the atmosphere: a fragment program, not puffs, which is
	# what lets it have a hard front and fiber (see scenes/vapors.gd). Registered on both
	# behaviors: the drifting camera suits the nebula characters and a held one suits the
	# denser ink, where the twisting is already all the movement the frame needs.
	{"script": preload("res://src/scenes/vapors.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/vapors.gd"), "behavior": "static"},
	# Worlds & projections - real 3D terrain, cities on it, latent geometry.
	{"script": preload("res://src/scenes/projection.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/projection.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/terrain.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/terrain.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/terrain_city.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/spires.gd"), "behavior": "drift"},
	# Simulation, structure and graphic work - the batch that widened the catalog past
	# "particles over a color bed" and "a body in a void", which between them were most
	# of what came before. Each of these is a language nothing else here speaks: a running
	# physical state, a real symmetry group, a written script, a routed graph, a plant in
	# depth, standing waves.
	{"script": preload("res://src/scenes/chladni.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/chladni.gd"), "behavior": "drift"},
	# wallpaper is DEREGISTERED, not deleted. Judged in the field: "everything about it
	# looked bad - the colors, the way the patterns were exactly the same everywhere, and
	# no movement at all besides a camera that shifted every once in a while."
	#
	# That is not a bug report, it is the design being wrong, and the design is mine. The
	# scene's stated bet was that a perfectly synchronized RE-INK of a static tiling would
	# be dramatic where motion would be cheap. It is not: an unchanging motif repeated to
	# the frame edge reads as a background texture, and a lattice glide on the beat reads
	# as the camera slipping rather than as the pattern stepping. The palette compounded it
	# - a black keyline against saturated inks on paper has to be composed, and these are
	# sampled.
	#
	# The file and [WallpaperGroup] stay: the seventeen plane groups are correct, tested
	# and reusable, and a motif worth repeating would still want them. What is missing is a
	# reason for the eye to stay, and that is a redesign rather than a tuning pass - one
	# that should be done where it can actually be looked at, which is what --scene is for.
	{"script": preload("res://src/scenes/glyphs.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/falling_sand.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/falling_sand.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/neural_field.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/canopy.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/cloth.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/murmuration.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/tidepool.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/tidepool.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/contour_map.gd"), "behavior": "drift"},
	# Two things the catalog had no version of at all. `fractal_zoom` is the only scene whose
	# subject has detail at every scale, so it is the only one that can move FORWARD forever
	# without repeating - and the only one where the camera's motion is the whole content.
	# `tunnel_run` is the only RIDE: everything else here is looked at, and a first-person track
	# puts the viewer inside the frame instead. Both are registered on `drift` (their own camera
	# does the work; the 2D view adds almost nothing) and the fractal also on `static`, where a
	# completely fixed frame suits a fall that is already all the motion there is.
	{"script": preload("res://src/scenes/fractal_zoom.gd"), "behavior": "drift"},
	{"script": preload("res://src/scenes/fractal_zoom.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/tunnel_run.gd"), "behavior": "drift"},
	# "the-point" scenes (camera holds, per the brief).
	{"script": preload("res://src/scenes/eye.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/two_eyes.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/prism.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/prism_split.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/eye_prism.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/two_prisms.gd"), "behavior": "static"},
	{"script": preload("res://src/scenes/prism_swarm.gd"), "behavior": "drift"},
]

## The LAYER transition phases two scenes ASYNCHRONOUSLY: the incoming fades IN over the
## outgoing (both visible, layered), then the outgoing fades OUT, leaving the incoming behind -
## a slow dissolve-through-an-overlap rather than a dip to black. To keep the overlap tasteful it
## is only used when the INCOMING scene is one of these ATMOSPHERIC field scenes (they read well
## washed over another look). During the overlap the two are pushed to opposite regions (one left
## /smaller, one right/larger) so they compose instead of colliding at the focal point.
const ATMOSPHERIC := [
	"res://src/scenes/starfield.gd", "res://src/scenes/aurora.gd",
	"res://src/scenes/fog_bank.gd", "res://src/scenes/fog_lights.gd",
	"res://src/scenes/fireflies.gd", "res://src/scenes/snowfall.gd",
	"res://src/scenes/rainfall.gd", "res://src/scenes/motes.gd",
	"res://src/scenes/bubbles.gd", "res://src/scenes/petals.gd",
	"res://src/scenes/embers.gd", "res://src/scenes/clouds.gd",
	"res://src/scenes/underwater.gd", "res://src/scenes/fire.gd",
	"res://src/scenes/vapors.gd",
	"res://src/scenes/clouds.gd", "res://src/scenes/fog_volume.gd",
	# The soft-edged half of the new bright scenes. A LAYER dissolve suits them for the
	# same reason it suits the weather - they are full-frame fields with no silhouette to
	# collide with, and arriving through a wash rather than out of a beat of black is
	# kinder to a high-key image.
	#
	# The HARD-edged new ones are deliberately NOT here. A printed survey sheet or a flat
	# wallpaper pattern half-dissolved over another scene reads as a rendering fault
	# rather than as a transition; those want the clean dip, and a bright picture fading
	# up from black is a perfectly good entrance - it is a cut onto white that would jar.
	"res://src/scenes/tidepool.gd", "res://src/scenes/murmuration.gd",
]
