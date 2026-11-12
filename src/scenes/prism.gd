extends GhostScene

## Prism - a single living wireframe tetrahedron (from "the-point").
##
## A see-through 4-point prism with a living neural core, ported from the browser Prism via
## [PrismBody]: glowing edges only, tendrils flowing from the center, hovering and slowly
## looking around. The camera holds (static, forward-facing); the core follows the audio.
##
## Color is a [Scheme] mood; only the hue reaches the body (it draws its own saturation from the
## browser's palette).
##
## The shell does not vary: it is the browser tetrahedron every time (see [PrismBody]'s `form`).
## Variety belongs in color, framing and presence.

## How much of the frame the prism claims. A solitary body has no count or arrangement to vary,
## so scale is its silhouette: from a mote lost in the void to a shape that overruns the view.
const PRESENCE := {
	"distant":  [0.15, 0.21],
	"portrait": [0.28, 0.38],
	"looming":  [0.48, 0.62],
}

var _f: AudioFeatures = AudioFeatures.new()
var _prism: PrismBody
var _hue := 0.6


## What this scene can be told ([method GhostScene.choice]): a storyboard entry's `set`, by
## name; a setting not told is drawn from the seed.
const FIELDS := {
	"presence": {"label": "Presence", "type": "choice", "options": "PRESENCE", "default": null,
		"blurb": "How much of the frame the prism claims: a distant mote, a portrait, or a looming shape that overruns the view."},
}


func build_params(rng: RandomNumberGenerator) -> Dictionary:
	render_kind = "scene3d"
	framing = "plane"                          # the prism hovers; keep the view square-on
	var sch := Scheme.pick(rng)
	_hue = sch.vary(rng)
	_prism = PrismBody.new(rng.randi())
	var pres := String(choice("presence", rng))
	var band: Array = PRESENCE[pres]
	return {"radius": rng.randf_range(float(band[0]), float(band[1])),
		"mood": sch.name, "hue": _hue, "presence": pres, "form": _prism.form}


func update(f: AudioFeatures, delta: float) -> void:
	_f = f
	tick(f, delta)
	drift_view(f, 0.01, 0.02)                  # nearly static, per the brief
	_prism.update(delta, clampf(f.energy * 0.8 + f.beat * 0.6, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	begin_draw()
	_prism.draw(self, Vector2.ZERO, float(params.radius) * unit(), _hue)
