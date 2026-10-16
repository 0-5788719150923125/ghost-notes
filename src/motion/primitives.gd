extends RefCounted
class_name Primitives

## Primitives - the registry of reusable physical forces.
##
## Each force is a small class that reads/writes [Particle] fields given the audio
## and dt. They compose: a scene names a few by key and the same primitive shows
## up across unrelated scenes (the scatter that bursts glass also bursts rocks and
## sparks). Constants are baked per use via the constructor `cfg`, the Praxis
## registry move - no per-scene flags.
##
## Two phases per step (run by [ParticleSystem]):
##   accumulate(ps, f, dt) - add accelerations into p.acc (gravity, spring, wind).
##   resolve(ps, f, dt)    - impulses, damping, constraints, kinematic sets.
## A force returns is_dynamic() == true if it participates in velocity/position
## integration; purely kinematic forces (pulse, orbit, wobble) return false.

class Force:
	var cfg: Dictionary = {}
	func _init(c: Dictionary = {}) -> void:
		cfg = c
	func num(k: String, d: float) -> float:
		return float(cfg.get(k, d))
	func flag(k: String, d: bool) -> bool:
		return bool(cfg.get(k, d))
	func is_dynamic() -> bool:
		return false
	func accumulate(_ps, _f, _dt) -> void:
		pass
	func resolve(_ps, _f, _dt) -> void:
		pass


## Constant downward pull, with an optional bouncy floor at a fixed altitude.
class Gravity extends Force:
	## WHAT IT CAN BE TOLD, as data (next/structure.md, step 16): each setting it reads, with
	## what it does - a timeline's inspector and an agent read these; docs.py holds them to the code.
	const FIELDS := {
		"g": {"label": "Pull", "type": "num", "default": 1.8,
			"blurb": "How hard every particle is pulled down."},
		"floor_on": {"label": "Floor", "type": "flag", "default": true,
			"blurb": "Whether particles land on a floor and bounce, or fall out of the frame."},
		"floor": {"label": "Floor height", "type": "num", "default": 0.46,
			"blurb": "How far below the center the floor sits."},
		"bounce": {"label": "Bounce", "type": "num", "default": 0.35,
			"blurb": "How much of its fall a particle keeps as it bounces off the floor: 0 lands dead, 1 bounces back as high."},
	}
	func is_dynamic() -> bool:
		return true
	func accumulate(ps, _f, _dt) -> void:
		var g := num("g", 1.8)
		for p: Particle in ps:
			p.acc.y += g
	func resolve(ps, _f, _dt) -> void:
		if not flag("floor_on", true):
			return
		var fl := num("floor", 0.46)
		var b := num("bounce", 0.35)
		for p: Particle in ps:
			if p.home.y + p.off.y > fl:
				p.off.y -= (p.home.y + p.off.y - fl)
				p.vel.y *= -b
				p.vel.x *= 0.6
				p.angvel *= 0.5


## Pull each particle back toward its home (recombine / cohesion).
class Spring extends Force:
	## WHAT IT CAN BE TOLD, as data (next/structure.md, step 16): each setting it reads, with
	## what it does - a timeline's inspector and an agent read these; docs.py holds them to the code.
	const FIELDS := {
		"k": {"label": "Stiffness", "type": "num", "default": 4.0,
			"blurb": "How hard each particle is pulled back toward its home - the higher, the quicker a scattered shape comes back together."},
	}
	func is_dynamic() -> bool:
		return true
	func accumulate(ps, _f, _dt) -> void:
		var k := num("k", 4.0)
		for p: Particle in ps:
			p.acc += -p.off * k


## Velocity damping.
class Drag extends Force:
	## WHAT IT CAN BE TOLD, as data (next/structure.md, step 16): each setting it reads, with
	## what it does - a timeline's inspector and an agent read these; docs.py holds them to the code.
	const FIELDS := {
		"k": {"label": "Drag", "type": "num", "default": 0.9,
			"blurb": "How quickly a particle's speed dies away, per second."},
	}
	func is_dynamic() -> bool:
		return true
	func resolve(ps, _f, dt) -> void:
		var k := num("k", 0.9)
		var m := maxf(0.0, 1.0 - k * dt)
		for p: Particle in ps:
			p.vel *= m


## Outward impulse on each beat (rising edge), from each particle's sub-group
## center. `once` fires a single time (oneshot crumble); `period` adds a fallback
## tempo when the track has no detectable beats.
class Scatter extends Force:
	## WHAT IT CAN BE TOLD, as data (next/structure.md, step 16): each setting it reads, with
	## what it does - a timeline's inspector and an agent read these; docs.py holds them to the code.
	const FIELDS := {
		"period": {"label": "Fallback period", "type": "num", "default": 0.0,
			"blurb": "Seconds between bursts when the music gives no beat to burst on; 0 bursts on beats only."},
		"once": {"label": "Once", "type": "flag", "default": false,
			"blurb": "Burst a single time and never again - a shape that crumbles once."},
		"strength": {"label": "Strength", "type": "num", "default": 0.5,
			"blurb": "How hard each burst throws the particles out from their group's center."},
		"jitter": {"label": "Jitter", "type": "num", "default": 0.5,
			"blurb": "How far each particle's direction strays from straight out, so a burst does not read as a perfect ring."},
		"spin": {"label": "Spin", "type": "num", "default": 2.0,
			"blurb": "How much spin a burst gives each particle."},
	}
	var _was := 0.0
	var _acc := 0.0
	var _fired := false
	func is_dynamic() -> bool:
		return true
	func resolve(ps, f, dt) -> void:
		_acc += dt
		var period := num("period", 0.0)
		var beat_edge: bool = f.beat > 0.5 and _was <= 0.5
		_was = f.beat
		var trig := beat_edge or (period > 0.0 and _acc >= period)
		if not trig:
			return
		_acc = 0.0
		if flag("once", false) and _fired:
			return
		_fired = true
		var s := num("strength", 0.5)
		var jit := num("jitter", 0.5)
		var spin := num("spin", 2.0)
		for p: Particle in ps:
			var center: Vector2 = p.data.get("center", Vector2.ZERO)
			var radial := p.home - center
			var dir: Vector2 = radial.normalized() if radial.length() > 0.001 else Vector2.UP
			dir = (dir + p.noise * jit).normalized()
			p.vel += dir * s * (0.7 + 0.5 * absf(p.noise.y))
			p.angvel += p.nspin * spin


## A horizontal flow that varies with height and time (plus optional vertical
## lift), so detached particles drift as if in wind.
class Wind extends Force:
	## WHAT IT CAN BE TOLD, as data (next/structure.md, step 16): each setting it reads, with
	## what it does - a timeline's inspector and an agent read these; docs.py holds them to the code.
	const FIELDS := {
		"amp": {"label": "Strength", "type": "num", "default": 0.4,
			"blurb": "How hard the wind pushes sideways; the treble adds a little more."},
		"freq": {"label": "Gusts", "type": "num", "default": 0.4,
			"blurb": "How fast the wind's sway comes and goes, and how tightly it varies with height."},
		"lift": {"label": "Lift", "type": "num", "default": 0.0,
			"blurb": "A steady push up (below 0) or down (above 0) on top of the sway."},
	}
	var _t := 0.0
	func is_dynamic() -> bool:
		return true
	func accumulate(ps, f, _dt) -> void:
		var amp := num("amp", 0.4)
		var freq := num("freq", 0.4)
		var lift := num("lift", 0.0)
		for p: Particle in ps:
			# Per-particle phase (p.noise.x * TAU) decorrelates the sway, so the cloud
			# drifts as individuals instead of swaying back and forth as one block. An
			# optional per-particle "mobility" (in p.data, default 1) scales the whole push,
			# so different particles ride the wind at different speeds (varied, not uniform).
			var mob: float = float(p.data.get("mobility", 1.0))
			p.acc.x += mob * (amp * sin((p.home.y * 3.0 + p.noise.x * TAU + _t) * freq * TAU) \
				+ 0.4 * amp * f.treble * p.noise.x)
			p.acc.y += mob * (lift + 0.3 * amp * sin((p.noise.y * TAU + _t) * freq * TAU))
	func resolve(_ps, _f, dt) -> void:
		_t += dt


## Kinematic: grow/shrink a sub-group coherently about its center (rocks
## breathing), driven by energy/beat plus a slow organic wobble.
class Pulse extends Force:
	## WHAT IT CAN BE TOLD, as data (next/structure.md, step 16): each setting it reads, with
	## what it does - a timeline's inspector and an agent read these; docs.py holds them to the code.
	const FIELDS := {
		"amp": {"label": "Loudness", "type": "num", "default": 0.3,
			"blurb": "How much a group grows with the music's loudness."},
		"beat": {"label": "Beat", "type": "num", "default": 0.4,
			"blurb": "How much it swells on each beat."},
		"organic": {"label": "Breathing", "type": "num", "default": 0.15,
			"blurb": "A slow swelling of its own, each particle in its own time, whatever the music does."},
	}
	var _t := 0.0
	func resolve(ps, f, dt) -> void:
		_t += dt
		var amp := num("amp", 0.3)
		var beat := num("beat", 0.4)
		var organic := num("organic", 0.15)
		var base: float = 1.0 + amp * f.energy + beat * f.beat
		for p: Particle in ps:
			var c: Vector2 = p.data.get("center", Vector2.ZERO)
			var s := base + organic * sin(_t * 0.7 + p.noise.x * TAU)
			p.off = (p.home - c) * (s - 1.0)
			p.scale = s


## Kinematic: revolve every particle around the origin, optionally spinning each.
class Orbit extends Force:
	## WHAT IT CAN BE TOLD, as data (next/structure.md, step 16): each setting it reads, with
	## what it does - a timeline's inspector and an agent read these; docs.py holds them to the code.
	const FIELDS := {
		"rate": {"label": "Rate", "type": "num", "default": 0.2,
			"blurb": "How fast everything turns about the center, in radians a second."},
		"audio": {"label": "With the music", "type": "num", "default": 0.0,
			"blurb": "How much faster it turns as the music gets louder."},
		"spin": {"label": "Spin", "type": "num", "default": 1.0,
			"blurb": "How much each particle turns on itself as it goes round: 1 keeps it facing the center."},
	}
	var _th := 0.0
	func resolve(ps, f, dt) -> void:
		_th += (num("rate", 0.2) + num("audio", 0.0) * f.energy) * dt
		var spin := num("spin", 1.0)
		for p: Particle in ps:
			p.off = p.home.rotated(_th) - p.home
			p.ang = _th * spin


## Kinematic: independent per-particle organic drift (decorrelated by noise).
class Wobble extends Force:
	## WHAT IT CAN BE TOLD, as data (next/structure.md, step 16): each setting it reads, with
	## what it does - a timeline's inspector and an agent read these; docs.py holds them to the code.
	const FIELDS := {
		"amp": {"label": "Distance", "type": "num", "default": 0.04,
			"blurb": "How far each particle drifts from its home."},
		"rate": {"label": "Rate", "type": "num", "default": 0.5,
			"blurb": "How fast the drift wanders."},
	}
	var _t := 0.0
	func resolve(ps, _f, dt) -> void:
		_t += dt
		var amp := num("amp", 0.04)
		var rate := num("rate", 0.5)
		for p: Particle in ps:
			var a := _t * rate + p.noise.x * TAU
			p.off = Vector2(cos(a * 1.1), sin(a)) * amp * (0.5 + p.noise.length())


const REGISTRY := {
	"gravity": Gravity,
	"spring": Spring,
	"drag": Drag,
	"scatter": Scatter,
	"wind": Wind,
	"pulse": Pulse,
	"orbit": Orbit,
	"wobble": Wobble,
}


## Build a force by registry key with its constants baked in.
static func make(key: String, cfg := {}) -> Force:
	return REGISTRY[key].new(cfg)
