extends RefCounted
class_name Surroundings

## Surroundings - what is round a scene (next/environment.md; [EnvironmentCard]): a list of elements, each a kind of thing
## ([constant KINDS]) - the light the scene is in, shafts of light through its haze, something drifting in its air, something heard
## round it, fog lying low or filling the air - with a number of its own and the properties a person set on it. A property never set is drawn from the element's number
## inside its field's bounds ([Roll]), so a new number is another variant of the same thing. The Dex offers every kind, each light
## preset and a few looks of shafts, beams and fog ([method offers]), and what a person keeps ([EnvironmentLibrary]).
##
## The note's `environment:` block: `elements` (each `{kind, seed, name, off, own, <its fields>}` - `name` where it was kept under one,
## `off` while it is set aside, `own` the words of the host it came from, a table's [TableSurroundings]), `lights` (how strongly each thing in the scene that throws light throws it, by the name its scene
## gives it: a share) and `heard` (how loud each thing that makes a sound of its own is). [method sanitize] makes it safe; a host reads
## it through [method light_of], [method brightness], [method rays], [method effects_of], [method sound_of] and [method fog_for]. A
## scene with no element of a kind keeps its own (its own light, its own shaft, no air, silence).
##
## Every light preset is a row of numbers each host reads as it can: a desk its lamp, candles and the room's light through a window
## ([DeskLook]); the Dispatch desk its hollow's ambient, the shaft that falls through its ceiling and its lamp ([DispatchMedium]). A
## row with no `weight` is only ever chosen: a desk drawing its own light from its number never draws it.

## The kinds of element: `group` the Dex's shelf it stands on ([constant GROUPS]); `one` whether a scene has at most one (another
## added takes its place); for what drifts, the [Effects] effect it is (`effect`, over a region every host names - `far` past the
## work, `near` round it, `room` everywhere, faint - `count` at Amount 1); for what is heard, the [Soundscape] part it is (`part`) and
## its words there (`spec`).
const KINDS := {
	"light": {"label": "Light", "blurb": "The light the scene is in - lamplight, candlelight, daylight, dusk, moonlight or none - and how bright.",
		"group": "light", "one": true},
	"shafts": {"label": "Light shafts", "blurb": "Shafts of light through the haze - through a window, a crack, the leaves: each a column as wide as the gap it came through, landing in a bright patch its own size.",
		"group": "light", "one": false},
	"beams": {"label": "Colored beams", "blurb": "Beams of colored light from fixtures hung high over the scene, as a stage's or a club's: some hold still and some sweep, each keeps a color a while and moves on to another, some strobe.",
		"group": "light", "one": false},
	"haze": {"label": "Haze", "blurb": "A bank of haze far off, out of focus behind the work: the room's depth, and what light shafts fall through.",
		"group": "air", "one": false, "effect": {"kind": "fog", "where": "far", "density": 0.45, "rolls": 0.4, "drift": 0.15, "height": 60.0, "grain": 40.0}},
	"fog": {"label": "Fog", "blurb": "Fog through the scene - lying low on the ground or filling the air, one even sheet or patches with clear air between, still, carried on a wind or swaying to and fro.",
		"group": "air", "one": false, "effect": {"kind": "fog", "where": "room", "density": 0.5, "rolls": 0.35, "drift": 0.0, "height": 40.0, "grain": 30.0}},
	"dust": {"label": "Dust", "blurb": "Motes of dust drifting through the light, barely there.",
		"group": "air", "one": false, "effect": {"kind": "motes", "look": "dust", "where": "near", "count": 160, "glow": 0.8, "speed": 0.3, "size": 2.2}},
	"pixies": {"label": "Pixies", "blurb": "Tiny bright points of colored light that dart and drift, alone or in twos and threes: magic in the air.",
		"group": "air", "one": false, "effect": {"kind": "motes", "look": "pixie", "where": "near", "count": 7, "glow": 0.7, "speed": 0.6}},
	"fireflies": {"label": "Fireflies", "blurb": "Slow, low sparks that blink on for a moment and off for longer.",
		"group": "air", "one": false, "effect": {"kind": "motes", "look": "firefly", "where": "far", "count": 10, "glow": 0.7, "speed": 0.4}},
	"wisps": {"label": "Wisps", "blurb": "Large, faint, slow glows that hang and drift in the distance.",
		"group": "air", "one": false, "effect": {"kind": "motes", "look": "wisp", "where": "far", "count": 4, "glow": 0.5, "speed": 0.3}},
	"embers": {"label": "Embers", "blurb": "Sparks rising from somewhere below, flickering, winking out.",
		"group": "air", "one": false, "effect": {"kind": "motes", "look": "ember", "where": "far", "count": 10, "glow": 0.7, "speed": 0.5}},
	"snow": {"label": "Snow", "blurb": "Flakes falling slowly, drifting as they fall - snow, ash, pollen.",
		"group": "air", "one": false, "effect": {"kind": "motes", "look": "snow", "where": "room", "count": 22, "glow": 0.4, "speed": 0.35}},
	"rain": {"label": "Rain", "blurb": "Rain falling outside, or on what is over the scene.", "group": "sound", "one": true,
		"part": "rain", "spec": {"on": "window", "strength": 0.45}},
	"wind": {"label": "Wind", "blurb": "A wind outside, moaning round the eaves in a gust.", "group": "sound", "one": true,
		"part": "wind", "spec": {"through": "eaves", "level": 0.6}},
	"fire": {"label": "Fire", "blurb": "A fire burning nearby, crackling - a hearth, a stove.", "group": "sound", "one": true,
		"part": "fire", "spec": {"size": 0.45, "distance": 0.5}},
	"insects": {"label": "Insects", "blurb": "Crickets in the grass, chirp after chirp, or cicadas swelling in the trees.", "group": "sound", "one": true,
		"part": "insects", "spec": {"kind": "crickets", "strength": 0.4}},
	"stream": {"label": "Stream", "blurb": "Running water - a brook, a fountain, a gutter after rain.", "group": "sound", "one": true,
		"part": "stream", "spec": {"size": 0.35, "distance": 0.6}},
	"sea": {"label": "Sea", "blurb": "Waves on a shore some way off, against a hull, round a dock.", "group": "sound", "one": true,
		"part": "water", "spec": {"kind": "shore", "size": 0.35, "distance": 0.6}},
	"creature": {"label": "A creature", "blurb": "An animal heard and never seen, made of numbers rather than a kind: how big, how breathy, the calls it makes, how many and how lively.",
		"group": "sound", "one": false, "part": "creatures", "spec": {"calls": ["chirp"], "awake": [0.5, 0.5]}},
	"ride": {"label": "The ride", "blurb": "What the scene is aboard, heard - a train's rumble and its wheels knocking, a cart jolting: heard only where the scene moves.",
		"group": "sound", "one": true, "part": "ride", "spec": {"level": 0.6}},
	"flies": {"label": "Flies", "blurb": "Dark specks that zip about in zig-zags, hover a moment and fly off - flies, gnats.",
		"group": "air", "one": false, "effect": {"kind": "motes", "look": "fly", "where": "near", "count": 6, "glow": 0.9, "speed": 1.0}},
}
## What of a host's own words an element keeps beside its properties, by kind (its `own`): where a sound is heard from, a wind's own
## gusts, a creature's name and calls, where motes fly and fog lies at a table and what else its effect said. An element with `own`
## is a host's as written: a property it does not set is its host's own default, never drawn ([method values_of]), so Roll leaves
## it as it is.
const OWN := {
	"wind": ["from", "strength", "gusts", "every"],
	"sea": ["from"],
	"fire": ["from"],
	"stream": ["from"],
	"creature": ["name", "calls", "awake", "over"],
	"haze": ["name", "where", "height", "grain", "glow", "color", "shape", "settle", "patches", "patch", "chaos", "wind", "turn", "gusts",
		"stretch", "sway", "pace", "breathe", "sight"],
	"motes": ["name", "where", "count", "colors", "away", "light"],
}
## The most an element's `own` holds of a list, and of a word.
const OWN_LIST := 8
const OWN_TEXT := 80
## The Dex's shelves for what is offered built in, by an element's `group`.
const GROUPS := {
	"light": {"label": "Light", "blurb": "The light a scene is in, and shafts of light through its haze."},
	"air": {"label": "In the air", "blurb": "What drifts in the air round the scene."},
	"sound": {"label": "Heard", "blurb": "What is heard round the scene, under the voice."},
}
## The light presets: `weight` how often a desk's number draws it (0: only chosen); `lamp` the share of a working lamp that is on;
## `candles` how many burn on a desk ([least, most]) and whether one lights the page (`leads`); `ambient` the room's own light (its
## color, and `ambient_energy`, a share of the scene's own); `key` what the light comes from where it comes through something - "sun",
## "moon", or "" (a shaft through a crack, a lamp's) - its color (`key_color`) and strength (`key_strength`, a share of the scene's
## own); `fog` the haze's color in it.
const LIGHTS := {
	"lamplight": {"label": "Lamplight", "blurb": "Night: a lamp lights the work, the room dark round it - a screen's glow, a street lamp, a fire, the moon in a window.",
		"weight": 4.0, "lamp": 1.0, "candles": [0, 1], "leads": false, "ambient": "#2e3340", "ambient_energy": 1.0, "key": "",
		"key_color": "#9eb0d0", "key_strength": 1.0, "fog": "#1c1f26"},
	"candlelight": {"label": "Candlelight", "blurb": "Night with the lamp off: candles light the work, their shadows moving with their flames.",
		"weight": 2.5, "lamp": 0.0, "candles": [1, 2], "leads": true, "ambient": "#3a2a1e", "ambient_energy": 0.75, "key": "",
		"key_color": "#ffb066", "key_strength": 0.45, "fog": "#241a12"},
	"daylight": {"label": "Daylight", "blurb": "Day: the sun falls through a window across the work, the bars' shadows over it, the sky filling the room.",
		"weight": 2.0, "lamp": 0.0, "candles": [0, 0], "leads": false, "ambient": "#8c96a6", "ambient_energy": 2.4, "key": "sun",
		"key_color": "#fff1dc", "key_strength": 1.8, "fog": "#9aa3ad"},
	"dusk": {"label": "Dusk", "blurb": "Evening: a low gold sun through the window, long shadows, and the lamp on.",
		"weight": 1.5, "lamp": 0.6, "candles": [0, 1], "leads": false, "ambient": "#5a4a5e", "ambient_energy": 1.5, "key": "sun",
		"key_color": "#ffb070", "key_strength": 1.4, "fog": "#4a3a40"},
	"moonlight": {"label": "Moonlight", "blurb": "Night with every lamp off: the moon through a window, white and cold, bright enough to see by.",
		"weight": 0.0, "lamp": 0.0, "candles": [0, 0], "leads": false, "ambient": "#28324a", "ambient_energy": 0.9, "key": "moon",
		"key_color": "#e4ebff", "key_strength": 1.3, "fog": "#232a38"},
	"darkness": {"label": "No light", "blurb": "Nearly dark: no lamp, no candle, only the faint light of the room - the work's own glow, if it has any.",
		"weight": 0.0, "lamp": 0.0, "candles": [0, 0], "leads": false, "ambient": "#15171c", "ambient_energy": 0.4, "key": "",
		"key_color": "#7d8aa6", "key_strength": 0.3, "fog": "#101216"},
}
## Looks of light shafts the Dex offers beside the kind as it rolls: each with some of its properties set ([constant SHAFT_FIELDS]).
const SHAFT_LOOKS := {
	"leaves": {"label": "Through leaves", "blurb": "Many thin shafts through a canopy, of every width, shimmering as the leaves move.",
		"set": {"count": 18, "width": 0.22, "inner": 0, "variety": -0.8, "flicker": 0.45, "spread": 6.0}},
	"window": {"label": "Through a window", "blurb": "Two broad, still beams, a few narrower shafts bright inside each.",
		"set": {"count": 2, "width": 0.65, "inner": 3, "variety": 0.25, "flicker": 0.0, "spread": 0.0}},
	"crack": {"label": "Through a crack", "blurb": "One narrow shaft from high up, a thinner, brighter one down its middle.",
		"set": {"count": 1, "width": 0.18, "inner": 1, "variety": 0.0, "flicker": 0.0, "spread": 0.0}},
}

## What a light can be told ([Roll]'s rows): its preset ("own" the scene's own), how bright the whole scene is, and whether the lamp at
## the work is on ([method lamp_of]) - never drawn: as its light has it until it is set.
const LIGHT_FIELDS := {
	"preset": {"label": "Light", "blurb": "The light the scene is in; its own, as the scene lights itself.", "type": "enum",
		"options": ["own", "lamplight", "candlelight", "daylight", "dusk", "moonlight", "darkness"], "default": "own",
		"roll": ["lamplight", "candlelight", "daylight", "dusk", "moonlight"]},
	"brightness": {"label": "Brightness", "blurb": "How bright the whole scene is, over its light's own: 1 as the light is.", "type": "float",
		"min": 0.25, "max": 2.5, "step": 0.05, "default": 1.0, "roll": [0.85, 1.25]},
	"lamp": {"label": "Lamp", "blurb": "Whether the lamp at the work is on: as the light has it (moonlight, daylight and candlelight put it out), or switched on or off whatever the light.",
		"type": "enum", "options": ["light", "on", "off"], "labels": {"light": "As the light has it", "on": "On", "off": "Off"}, "default": "light"},
}
## Looks of colored beams the Dex offers beside the kind as it rolls ([constant BEAM_FIELDS]).
const BEAM_LOOKS := {
	"disco": {"label": "Disco", "blurb": "A dozen beams in the club's colors, most of them sweeping, changing color every second or two, a few strobing.",
		"set": {"count": 12, "palette": "club", "moving": 0.75, "sweep": 32.0, "speed": 0.45, "hold": 1.6, "variety": 0.7, "strobe": 0.25, "width": 0.3}},
	"stage": {"label": "Stage", "blurb": "Six broad, still beams, each holding its warm color a long while.",
		"set": {"count": 6, "palette": "warm", "moving": 0.0, "hold": 9.0, "variety": 0.5, "strobe": 0.0, "width": 0.7, "spread": 9.0, "blend": 0.6}},
	"lasers": {"label": "Lasers", "blurb": "Many thin beams that barely open, sweeping quickly, in every hue.",
		"set": {"count": 20, "palette": "rainbow", "moving": 0.9, "sweep": 40.0, "speed": 0.75, "hold": 1.0, "variety": 0.4, "strobe": 0.1, "width": 0.0, "spread": 0.5, "blend": 0.0}},
}

## What colored beams can be told ([StageBeams]): how many, how wide at the lens and how much each opens, the colors they draw from (or
## one color), how many sweep and how far and fast, how long each keeps a color and how much their holds differ, how quickly a color
## changes, how many strobe and how fast, how strong, and where round the scene their fixtures hang.
const BEAM_FIELDS := {
	"count": {"label": "Beams", "blurb": "How many beams there are.", "type": "int", "min": 1, "max": 24, "step": 1, "default": 8, "roll": [5, 14]},
	"width": {"label": "Width", "blurb": "How wide each beam is at its lens, from a laser's to a floodlight's.", "type": "float", "min": 0.0,
		"max": 1.0, "step": 0.01, "default": 0.3, "roll": [0.15, 0.5]},
	"spread": {"label": "Spread", "blurb": "How much each beam opens as it goes (degrees): 0 a column, more a cone.", "type": "float",
		"min": 0.0, "max": 15.0, "step": 0.5, "default": 4.0, "roll": [1.5, 7.0]},
	"palette": {"label": "Colors", "blurb": "The colors the beams draw from.", "type": "enum",
		"options": ["club", "rainbow", "warm", "cool", "ice", "one"], "default": "club", "roll": ["club", "rainbow", "warm", "cool"]},
	"color": {"label": "Color", "blurb": "One color for every beam; unset, the palette's.", "type": "color", "default": ""},
	"moving": {"label": "Moving", "blurb": "How many of the beams sweep: 0 all hold still, 1 all move.", "type": "float", "min": 0.0,
		"max": 1.0, "step": 0.05, "default": 0.6, "roll": [0.35, 0.85]},
	"sweep": {"label": "Sweep", "blurb": "How far a moving beam swings (degrees).", "type": "float", "min": 0.0, "max": 70.0, "step": 1.0,
		"default": 28.0, "roll": [14.0, 45.0]},
	"speed": {"label": "Speed", "blurb": "How fast the moving beams swing: a slow sway to a quick sweep.", "type": "float", "min": 0.0,
		"max": 1.0, "step": 0.05, "default": 0.35, "roll": [0.2, 0.6]},
	"hold": {"label": "Hold", "blurb": "How long a beam keeps a color before it changes (seconds).", "type": "float", "min": 0.2,
		"max": 20.0, "step": 0.1, "default": 2.5, "roll": [1.2, 5.0]},
	"variety": {"label": "Variety", "blurb": "How much the beams' holds differ: 0 all change together; 1 some keep theirs four times as long, some change four times as often.",
		"type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.6, "roll": [0.3, 0.9]},
	"blend": {"label": "Blend", "blurb": "How a color gives way to the next: 0 at once, 1 eased over the whole hold.", "type": "float",
		"min": 0.0, "max": 1.0, "step": 0.05, "default": 0.15, "roll": [0.0, 0.4]},
	"strobe": {"label": "Strobe", "blurb": "How many of the beams strobe, in bursts.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05,
		"default": 0.15, "roll": [0.0, 0.3]},
	"rate": {"label": "Strobe rate", "blurb": "How many times a second a strobing beam flashes.", "type": "float", "min": 1.0, "max": 15.0,
		"step": 0.5, "default": 5.0, "roll": [3.0, 8.0]},
	"strength": {"label": "Strength", "blurb": "How strongly they light the haze, and the patches where they land.", "type": "float",
		"min": 0.0, "max": 1.0, "step": 0.05, "default": 0.6, "roll": [0.45, 0.8]},
	"turn": {"label": "Direction", "blurb": "Where round the scene their fixtures hang, turned from where its own light comes from (degrees).",
		"type": "float", "min": -180.0, "max": 180.0, "step": 1.0, "default": 0.0, "roll": [-40.0, 40.0]},
}
## What light shafts can be told: how many beams, how wide (a share of what the scene allows: a pencil's width to a window's, [constant
## LightShafts.WIDTH]), how many narrower shafts inside each, which way they come from and how steeply (turned from the scene's own
## light), how far each beam's way strays from the rest, how strong, how much they differ, how much they shimmer, their color.
const SHAFT_FIELDS := {
	"count": {"label": "Beams", "blurb": "How many beams fall.", "type": "int", "min": 1, "max": 30, "step": 1, "default": 4, "roll": [3, 14]},
	"width": {"label": "Width", "blurb": "How wide each beam is, from a pencil's width to a window's.", "type": "float", "min": 0.0, "max": 1.0,
		"step": 0.01, "default": 0.3, "roll": [0.1, 0.55]},
	"inner": {"label": "Inner shafts", "blurb": "How many narrower shafts fall inside each beam, twice as bright where they cross it.", "type": "int",
		"min": 0, "max": 3, "step": 1, "default": 1, "roll": [0, 2]},
	"turn": {"label": "Direction", "blurb": "Which way they come from, turned round from the scene's own light (degrees).", "type": "float",
		"min": -180.0, "max": 180.0, "step": 1.0, "default": 0.0, "roll": [-60.0, 60.0]},
	"steep": {"label": "Steepness", "blurb": "How steeply they fall, over the scene's own light: below 0 lower, as a sun near setting (degrees).",
		"type": "float", "min": -40.0, "max": 30.0, "step": 1.0, "default": 0.0, "roll": [-20.0, 12.0]},
	"spread": {"label": "Spread", "blurb": "How far each beam's way strays from the others' (degrees): 0 all parallel, as through one window; more, as through leaves.",
		"type": "float", "min": 0.0, "max": 25.0, "step": 0.5, "default": 0.0, "roll": [0.0, 9.0]},
	"strength": {"label": "Strength", "blurb": "How strongly they light the haze, and the patches where they land.", "type": "float",
		"min": 0.0, "max": 1.0, "step": 0.05, "default": 0.5, "roll": [0.3, 0.7]},
	"variety": {"label": "Variety", "blurb": "How the beams' widths stray from the Width: 0 all alike; above 0 some much fatter, below 0 some much skinnier; and how much they differ in brightness.",
		"type": "float", "min": -1.0, "max": 1.0, "step": 0.05, "default": 0.0, "roll": [-0.6, 0.6]},
	"flicker": {"label": "Flicker", "blurb": "How much they shimmer, as light through moving leaves does.", "type": "float",
		"min": 0.0, "max": 1.0, "step": 0.05, "default": 0.0, "roll": [0.0, 0.3]},
	"color": {"label": "Color", "blurb": "Their color; unset, the light's own.", "type": "color", "default": ""},
}
## What drifting motes can be told; a kind's own size (its effect's, else its look's), glow, speed and color are its defaults, drawn
## near them ([method fields_of]).
const MOTE_FIELDS := {
	"amount": {"label": "Amount", "blurb": "How many: 1 as the kind is.", "type": "float", "min": 0.25, "max": 2.5, "step": 0.05, "default": 1.0,
		"roll": [0.7, 1.5]},
	"size": {"label": "Size", "blurb": "How big each is (mm).", "type": "float", "step": 0.1},
	"glow": {"label": "Glow", "blurb": "How brightly each glows.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05},
	"speed": {"label": "Speed", "blurb": "How fast they wander.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05},
	"color": {"label": "Color", "blurb": "Their color.", "type": "color"},
}
## What haze can be told: how thick, how much it rolls, which way and how fast it drifts.
const HAZE_FIELDS := {
	"density": {"label": "Density", "blurb": "How thick the haze is.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.45,
		"roll": [0.3, 0.6]},
	"rolls": {"label": "Rolls", "blurb": "How much it rolls and billows.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.4,
		"roll": [0.2, 0.6]},
	"drift": {"label": "Drift", "blurb": "Which way it drifts, and how fast.", "type": "float", "min": -1.0, "max": 1.0, "step": 0.05, "default": 0.15,
		"roll": [-0.3, 0.3]},
}
## What fog can be told ([method Effects.fog_run], `effect_fog.gdshader`): how thick and how high, how much it lies low (full to its
## top, or thick on the ground and thin above), one sheet or patches, its swirls and the curve that turns them into fog and clear air
## (`activation`, [constant Effects.FOG_SHAPES]), how irregular it all is (`chaos`), the wind that carries it and its gusts, a slow sway
## to and fro along the wind's way and a slower breathing, its own glow and its color.
const FOG_FIELDS := {
	"density": {"label": "Density", "blurb": "How thick it is: a whisper of mist to fog nothing is seen through.", "type": "float", "min": 0.0,
		"max": 1.0, "step": 0.05, "default": 0.5, "roll": [0.35, 0.7]},
	"height": {"label": "Height", "blurb": "How high it reaches above the ground (cm).", "type": "float", "min": 5.0, "max": 300.0, "step": 5.0,
		"default": 40.0, "roll": [20.0, 90.0]},
	"settle": {"label": "Low lying", "blurb": "How it lies: 0 as thick at its top as on the ground, filling all it reaches; 1 thick on the ground and thinning fast above it.",
		"type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.8, "roll": [0.55, 0.95]},
	"patches": {"label": "Patches", "blurb": "0 one even sheet; toward 1 patches of fog with clear air between them.", "type": "float", "min": 0.0,
		"max": 1.0, "step": 0.05, "default": 0.3, "roll": [0.0, 0.6]},
	"patch": {"label": "Patch size", "blurb": "How big each patch is (m).", "type": "float", "min": 0.2, "max": 8.0, "step": 0.1, "default": 1.5,
		"roll": [0.8, 3.0]},
	"grain": {"label": "Swirls", "blurb": "How big its swirls and billows are (cm).", "type": "float", "min": 3.0, "max": 200.0, "step": 1.0,
		"default": 30.0, "roll": [15.0, 60.0]},
	"activation": {"label": "Activation", "blurb": "The curve that turns its swirls into fog and clear air: smooth, billows with gaps, thin wisps, sharp-edged clumps, or folds like poured smoke.",
		"type": "enum", "default": "smooth", "roll": ["smooth", "billows", "wisps"]},
	"chaos": {"label": "Chaos", "blurb": "How irregular it all is: 0 even - its sway and gusts regular, its swirls as drawn; 1 wild - swings and gusts of every length, swirls folded into themselves, thick and thin from place to place.",
		"type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.25, "roll": [0.1, 0.45]},
	"rolls": {"label": "Rolls", "blurb": "How much it rolls and turns over as it goes.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05,
		"default": 0.35, "roll": [0.15, 0.6]},
	"wind": {"label": "Wind", "blurb": "How fast a wind carries it: 0 still air, 1 a stiff breeze.", "type": "float", "min": 0.0, "max": 1.0,
		"step": 0.05, "default": 0.2, "roll": [0.05, 0.35]},
	"turn": {"label": "Wind direction", "blurb": "Which way it blows (degrees): 0 left to right as the scene is first seen, 90 toward the viewer, -90 away, 180 right to left.",
		"type": "float", "min": -180.0, "max": 180.0, "step": 5.0, "default": 0.0, "roll": [-60.0, 60.0]},
	"gusts": {"label": "Gusts", "blurb": "How much the wind comes and goes: 0 steady; 1 from a lull to gusts twice as strong.", "type": "float",
		"min": 0.0, "max": 1.0, "step": 0.05, "default": 0.3, "roll": [0.1, 0.5]},
	"stretch": {"label": "Streaks", "blurb": "How far its swirls are drawn out along the wind: 0 round, 1 long streaks.", "type": "float",
		"min": 0.0, "max": 1.0, "step": 0.05, "default": 0.3, "roll": [0.1, 0.6]},
	"sway": {"label": "Sway", "blurb": "How far it swings back and forth along the wind's way, in slow waves passing through it.", "type": "float",
		"min": 0.0, "max": 1.0, "step": 0.05, "default": 0.2, "roll": [0.0, 0.4]},
	"pace": {"label": "Sway pace", "blurb": "How long one swing takes (seconds); it breathes a little slower.", "type": "float", "min": 2.0,
		"max": 60.0, "step": 0.5, "default": 14.0, "roll": [9.0, 22.0]},
	"breathe": {"label": "Breathe", "blurb": "How much it rises and sinks, thinning as it rises and thickening as it sinks.", "type": "float",
		"min": 0.0, "max": 1.0, "step": 0.05, "default": 0.15, "roll": [0.0, 0.35]},
	"glow": {"label": "Glow", "blurb": "Light of its own, so it shows where no light falls on it.", "type": "float", "min": 0.0, "max": 1.0,
		"step": 0.05, "default": 0.1, "roll": [0.0, 0.2]},
	"color": {"label": "Color", "blurb": "Its color; unset, the light's fog.", "type": "color", "default": ""},
}
## A fog's color unset ([method fog_albedo]): this pale, tinted this much by the light's fog.
const FOG_PALE := Color(0.82, 0.84, 0.87)
const FOG_TINT := 0.3
## Looks of fog the Dex offers beside the kind as it rolls ([constant FOG_FIELDS]).
const FOG_LOOKS := {
	"ground": {"label": "Ground fog", "blurb": "A low layer lying on the ground, thinning fast above it, carried gently on a breeze and swaying slowly.",
		"set": {"density": 0.6, "height": 35.0, "settle": 0.9, "patches": 0.3, "patch": 2.0, "activation": "smooth", "wind": 0.15,
			"gusts": 0.3, "stretch": 0.5, "sway": 0.25, "pace": 16.0, "breathe": 0.3, "chaos": 0.25}},
	"thick": {"label": "Thick fog", "blurb": "Fog filling all the air, as thick high up as on the ground, barely moving.",
		"set": {"density": 0.7, "height": 300.0, "settle": 0.1, "patches": 0.0, "activation": "smooth", "wind": 0.05, "sway": 0.0,
			"breathe": 0.0, "chaos": 0.1}},
	"patchy": {"label": "Patchy mist", "blurb": "Islands of mist with clear air between them, drifting slowly.",
		"set": {"density": 0.55, "height": 80.0, "settle": 0.6, "patches": 0.75, "patch": 1.6, "activation": "billows", "wind": 0.12,
			"sway": 0.1, "chaos": 0.35}},
	"rolling": {"label": "Rolling bank", "blurb": "A bank rolling in on a gusting wind, billowing and turning over, drawn out in streaks.",
		"set": {"density": 0.65, "height": 120.0, "settle": 0.5, "patches": 0.2, "activation": "billows", "rolls": 0.8, "wind": 0.5,
			"gusts": 0.6, "stretch": 0.6, "chaos": 0.5}},
}
## What each sound can be told, by its [Soundscape] part: how loud it is, and what it is like (a choice's options are the part's own,
## [method fields_of]).
const SOUND_FIELDS := {
	"rain": {"strength": {"label": "Strength", "blurb": "How hard it rains.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.3, 0.6]},
		"on": {"label": "On", "blurb": "What it falls on.", "type": "enum", "roll": ["window", "roof", "leaves"]}},
	"wind": {"level": {"label": "Level", "blurb": "How loud the wind is.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.4, 0.75]},
		"through": {"label": "Through", "blurb": "What it blows through.", "type": "enum", "roll": ["eaves", "trees", "open"]}},
	"fire": {"size": {"label": "Size", "blurb": "How big the fire is.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.3, 0.6]},
		"distance": {"label": "Distance", "blurb": "How far off it burns.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.3, 0.7]}},
	"insects": {"strength": {"label": "Strength", "blurb": "How loud they are.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.25, 0.55]},
		"sort": {"label": "Kind", "blurb": "Which insects sing.", "type": "enum", "roll": ["crickets", "cicadas"]},
		"amount": {"label": "How many", "blurb": "A lone cricket to a whole field of them; a few cicadas to a chorus.", "type": "float",
			"min": 0.0, "max": 1.0, "step": 0.05, "default": 0.25, "roll": [0.1, 0.5]},
		"pitch": {"label": "Pitch", "blurb": "How high they sing.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.5,
			"roll": [0.3, 0.7]},
		"pace": {"label": "Pace", "blurb": "How quickly each chirps, or the chorus swells and fades.", "type": "float", "min": 0.0, "max": 1.0,
			"step": 0.05, "default": 0.5, "roll": [0.3, 0.7]}},
	"stream": {"size": {"label": "Size", "blurb": "How much water runs.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.25, 0.5]},
		"distance": {"label": "Distance", "blurb": "How far off it runs.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.4, 0.8]}},
	"water": {"size": {"label": "Size", "blurb": "How big the waves are.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.25, 0.5]},
		"distance": {"label": "Distance", "blurb": "How far off the water is.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05, "roll": [0.4, 0.8]},
		"sort": {"label": "Kind", "blurb": "What the water is.", "type": "enum", "roll": ["shore", "dock"]}},
	"creatures": {"size": {"label": "Size", "blurb": "From small, quick and high to large, slow and deep.", "type": "float", "min": 0.0, "max": 1.0,
			"step": 0.05, "default": 0.3, "roll": [0.1, 0.7]},
		"breath": {"label": "Breath", "blurb": "From a clear voice to a breathy one.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05,
			"default": 0.4, "roll": [0.2, 0.7]},
		"count": {"label": "How many", "blurb": "How many of them there are, each a voice of its own.", "type": "int", "min": 1,
			"max": Soundscape.MAX_BODIES, "step": 1, "default": 1, "roll": [1, 3]},
		"rate": {"label": "Calls", "blurb": "About how many calls a minute when lively, fewer when drowsy.", "type": "float", "min": 0.2,
			"max": 40.0, "step": 0.2, "default": 6.0, "roll": [2.0, 10.0]},
		"side": {"label": "Side", "blurb": "Where they are: the far left to the far right.", "type": "float", "min": -1.0, "max": 1.0,
			"step": 0.05, "default": 0.0, "roll": [-0.7, 0.7]},
		"near": {"label": "Near", "blurb": "How close: far off, quieter and duller, to close by.", "type": "float", "min": 0.0, "max": 1.0,
			"step": 0.05, "default": 0.5, "roll": [0.3, 0.7]}},
	"ride": {"level": {"label": "Level", "blurb": "How loud the ride is.", "type": "float", "min": 0.0, "max": 1.0, "step": 0.05,
		"default": 0.6, "roll": [0.4, 0.75]}},
}
## How loud a sound is over how it is made (dB), every sound's: never drawn, 0 until set ([constant Soundscape.VOLUME]).
const VOLUME_FIELD := {"label": "Volume", "blurb": "How loud it is, over how it is made (dB): 0 as it is, below quieter, above louder.",
	"type": "float", "min": -30.0, "max": 30.0, "step": 1.0, "default": 0.0}
## The block's keys and what each is when it says nothing.
const KNOBS := {"elements": [], "lights": {}, "heard": {}}
## The most elements a scene has, and the keys of an element that are no property of it.
const MOST := 12
const OWN_KEYS := ["kind", "seed", "name", "off", "own"]
## How strongly a thing throws its light, and how loud it is, over how it is made.
const LIGHT_SHARE := Vector2(0.0, 3.0)
const HEARD_SHARE := Vector2(0.0, 2.0)
## How loud what is heard is under the voice ([Soundscape]'s bed level).
const BED_LEVEL := 0.5
## An element's picture, on its row and the Dex (pixels); a fog's picture is a room this many centimeters tall, drawn in blocks this
## many pixels square.
const PICTURE := Vector2i(176, 132)
const PICTURE_ROOM := 200.0
const PICTURE_BLOCK := 4


## The block [param raw] made safe: its elements each a kind it knows with a number and the properties its fields allow, a kind there
## may be one of kept once (the first), at most [constant MOST]; a lit or heard thing's share kept by its name, held to its range.
static func sanitize(raw: Variant) -> Dictionary:
	var d: Dictionary = raw if raw is Dictionary else {}
	var out := {"elements": [], "lights": _shares(d.get("lights"), LIGHT_SHARE), "heard": _shares(d.get("heard"), HEARD_SHARE)}
	var seen := {}
	for e in ((d["elements"] as Array) if d.get("elements") is Array else []):
		var el := element(e)
		if el.is_empty() or (out["elements"] as Array).size() >= MOST:
			continue
		var kind := String(el["kind"])
		if bool((KINDS[kind] as Dictionary)["one"]) and seen.has(kind):
			continue
		seen[kind] = true
		(out["elements"] as Array).append(el)
	return out


## One element made safe from [param raw]: `{kind, seed}`, its `name` and `off` where it has them, and what it sets of its kind's
## fields ([method Roll.clean]); {} for a kind it does not know. An element with no number is given its kind's own.
static func element(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	var kind := String(d.get("kind", "")).strip_edges().to_lower() if d.get("kind") is String else ""
	if not KINDS.has(kind):
		return {}
	var seed := int(d["seed"]) if typeof(d.get("seed")) in [TYPE_INT, TYPE_FLOAT] else absi(hash(kind)) % 1000000
	var out := {"kind": kind, "seed": seed}
	var name := Props._text(d.get("name", ""), 60)
	if not name.is_empty():
		out["name"] = name
	if d.get("off") == true:
		out["off"] = true
	if d.get("own") is Dictionary:
		out["own"] = _own(kind, d["own"])
	out.merge(Roll.clean(fields_of(kind), d))
	return out


## What of [param raw] a [param kind] keeps as its host's own words ([constant OWN]): plain numbers, words, flags and short lists of
## them, each bounded; its host makes them safe as it reads them.
static func _own(kind: String, raw: Dictionary) -> Dictionary:
	var out := {}
	for k in own_keys(kind):
		var v: Variant = raw.get(k)
		match typeof(v):
			TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
				out[k] = v
			TYPE_STRING:
				out[k] = String(v).left(OWN_TEXT)
			TYPE_ARRAY:
				var list: Array = []
				for x in (v as Array).slice(0, OWN_LIST):
					if typeof(x) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
						list.append(x)
					elif x is String:
						list.append(String(x).left(OWN_TEXT))
				out[k] = list
	return out


## The keys of a host's own words a kind keeps ([constant OWN]): motes of any look keep the motes' own.
static func own_keys(kind: String) -> Array:
	if OWN.has(kind):
		return OWN[kind]
	var fx: Dictionary = (KINDS.get(kind, {}) as Dictionary).get("effect", {})
	return OWN["motes"] if String(fx.get("kind", "")) == "motes" else []


## What element [param el] sets of its fields: the element without its kind, number, name and whether it is set aside.
static func set_of(el: Dictionary) -> Dictionary:
	var out := el.duplicate(true)
	for k in OWN_KEYS:
		out.erase(k)
	return out


## The fields a kind [param kind] can be told ([Roll]'s rows): a light's, shafts', haze's, fog's, motes' (their own size, glow, speed and
## color its defaults), or a sound's (its part's own choices). A shaft's or a fog's color unset is [param color] ("" where it follows the
## scene's).
static func fields_of(kind: String, color := "") -> Dictionary:
	var row: Dictionary = KINDS.get(kind, {})
	if kind == "light":
		var out := LIGHT_FIELDS.duplicate(true)
		var labels := {"own": "The scene's own"}
		for k in LIGHTS:
			labels[k] = Registry.label(LIGHTS, k)
		(out["preset"] as Dictionary)["labels"] = labels
		return out
	if kind == "shafts":
		var out := SHAFT_FIELDS.duplicate(true)
		(out["color"] as Dictionary)["default"] = color
		return out
	if kind == "beams":
		var out := BEAM_FIELDS.duplicate(true)
		var labels := {}
		for k in StageBeams.PALETTES:
			labels[k] = Registry.label(StageBeams.PALETTES, k)
		(out["palette"] as Dictionary)["labels"] = labels
		return out
	if row.has("effect"):
		var fx: Dictionary = row["effect"]
		if kind == "fog":
			var out := FOG_FIELDS.duplicate(true)
			var shape: Dictionary = out["activation"]
			shape["options"] = Effects.FOG_SHAPES.keys()
			var labels := {}
			for k in Effects.FOG_SHAPES:
				labels[k] = Registry.label(Effects.FOG_SHAPES, k)
			shape["labels"] = labels
			(out["color"] as Dictionary)["default"] = color
			return out
		if String(fx["kind"]) == "fog":
			return HAZE_FIELDS.duplicate(true)
		var base: Dictionary = Effects.MOTES[String(fx["look"])]
		var out := MOTE_FIELDS.duplicate(true)
		var sizes: Vector2 = base["sizes"]
		var size := float(fx.get("size", base["size"]))
		out["size"].merge({"min": sizes.x, "max": sizes.y, "default": size,
			"roll": [maxf(sizes.x, size * 0.75), minf(sizes.y, size * 1.35)]})
		for k in ["glow", "speed"]:
			var v := float(fx[k])
			out[k].merge({"default": v, "roll": [maxf(0.0, v - 0.15), minf(1.0, v + 0.15)]})
		out["color"]["default"] = String(base["color"])
		return out
	if row.has("part"):
		var part := String(row["part"])
		var out: Dictionary = (SOUND_FIELDS.get(part, {}) as Dictionary).duplicate(true)
		out["volume"] = VOLUME_FIELD.duplicate()
		var spec: Dictionary = row["spec"]
		var tables := {"on": Soundscape.RAINS, "through": Soundscape.THROUGH, "sort": Soundscape.INSECTS if part == "insects" else Soundscape.WATERS}
		for k in out:
			var f: Dictionary = out[k]
			var fallback: Variant = f.get("min", 0.0)
			if String(f["type"]) == "enum":
				f["options"] = (tables[k] as Dictionary).keys()
				fallback = (f["options"] as Array)[0]
			f["default"] = spec.get(_heard_key(k), f.get("default", fallback))
		return out
	return {}


## Every property of element [param el]: what it sets, the rest drawn by its number ([method Roll.values]) - or, for a host's as written
## (its `own`), the rest its field's default ([method Roll.own_or_drawn]). A shaft's color unset is "" (the scene's).
static func values_of(el: Dictionary) -> Dictionary:
	var fields := fields_of(String(el.get("kind", "")))
	if el.has("own"):
		return Roll.own_or_drawn(fields, set_of(el))
	return Roll.values(fields, set_of(el), int(el.get("seed", 0)))


## The fields of element [param el] as its entry shows them ([method Roll.shown], [method Roll.shown_for] for a host's as written),
## a shaft's or a fog's color unset [param color].
static func shown_of(el: Dictionary, color := "") -> Dictionary:
	var fields := fields_of(String(el.get("kind", "")), color)
	if el.has("own"):
		return Roll.shown_for(fields, set_of(el))
	return Roll.shown(fields, set_of(el), int(el.get("seed", 0)))


## How many motes element [param el] (a kind that drifts) is at its Amount ([param v], its values): its kind's own count, or its host's
## as written (`own`'s `count`), times its Amount.
static func mote_count(el: Dictionary, v: Dictionary) -> int:
	var fx: Dictionary = (KINDS.get(String(el.get("kind", "")), {}) as Dictionary).get("effect", {})
	var own: Dictionary = el.get("own", {})
	var base := float(own["count"]) if typeof(own.get("count")) in [TYPE_INT, TYPE_FLOAT] else float(fx.get("count", 1))
	return maxi(1, roundi(base * float(v.get("amount", 1.0))))


## The elements of [param spec] in use (none set aside), of group [param group] ("" every group).
static func in_use(spec: Dictionary, group := "") -> Array:
	var out: Array = []
	for e in (spec.get("elements", []) as Array):
		var el: Dictionary = e
		if el.get("off") == true:
			continue
		if not KINDS.has(String(el.get("kind", ""))):
			continue
		if group.is_empty() or String((KINDS[String(el["kind"])] as Dictionary)["group"]) == group:
			out.append(el)
	return out


## The light element in use, or {} where the scene keeps its own.
static func light_element(spec: Dictionary) -> Dictionary:
	for el in in_use(spec, "light"):
		if String((el as Dictionary)["kind"]) == "light":
			return el
	return {}


## The light preset the block [param spec] chooses (made safe here, so a document's own will do), "" where it chooses none (the
## scene's own).
static func preset_of(spec: Variant) -> String:
	var el := light_element(sanitize(spec))
	if el.is_empty():
		return ""
	var p := String(values_of(el)["preset"])
	return p if LIGHTS.has(p) else ""


## The preset row of the light [param spec] chooses, or the row a scene's own light is nearest to ([param own]) where it chooses none.
static func light_of(spec: Dictionary, own := "lamplight") -> Dictionary:
	var k := preset_of(spec)
	return LIGHTS[k] if LIGHTS.has(k) else LIGHTS.get(own, LIGHTS["lamplight"])


## How bright the whole scene is over its light's own: the light element's, 1 with none.
static func brightness(spec: Dictionary) -> float:
	var el := light_element(spec)
	return float(values_of(el)["brightness"]) if not el.is_empty() else 1.0


## How strongly the thing a scene calls [param name] throws its light ([constant KNOBS] `lights`): 1 where the block says nothing.
static func share_of(spec: Dictionary, name: String) -> float:
	return float((spec.get("lights", {}) as Dictionary).get(name, 1.0))


## How loud the thing a scene calls [param name] is in what it makes of its own ([constant KNOBS] `heard`): 1 where the block says
## nothing.
static func heard_of(spec: Dictionary, name: String) -> float:
	return float((spec.get("heard", {}) as Dictionary).get(name, 1.0))


## Whether [param spec] has shafts of light in use: a scene's own shaft then gives way to them.
static func has_shafts(spec: Dictionary) -> bool:
	return in_use(spec, "light").any(func(el: Dictionary) -> bool: return String(el["kind"]) == "shafts")


## Every shafts and beams element in use in [param spec], built under one node ([method LightShafts.build], [method StageBeams.build]):
## falling [param reach] (m) from [param toward] (the way to their light) onto [param over] (boxes in the host's space, each's top where
## they land), a shaft [param color] where its own is unset. Its meta `levels`: each element's place in the spec's `elements` -> its
## materials and strength, which [method tick_rays] scales. Null where there are none.
static func rays(spec: Dictionary, color: Color, toward: Vector3, over: Array, reach: float) -> Node3D:
	var shafts: Array = []
	var beams: Array = []
	var all: Array = spec.get("elements", [])
	for el in in_use(spec, "light"):
		var kind := String((el as Dictionary)["kind"])
		if kind != "shafts" and kind != "beams":
			continue
		var v := values_of(el)
		v["seed"] = int((el as Dictionary)["seed"])
		v["key"] = all.find(el)
		(shafts if kind == "shafts" else beams).append(v)
	if shafts.is_empty() and beams.is_empty():
		return null
	var root := LightShafts.build(shafts, color, toward, over, reach)
	if not beams.is_empty():
		StageBeams.build(beams, toward, over, reach, root)
	return root


## The shafts and beams [param rays_root] ([method rays]) as they are at show time [param t]: each element at its share of itself in
## [param levels] (its place in the spec's `elements` -> 0 to 1; one not there is whole), and hidden at none.
static func tick_rays(rays_root: Node3D, t: float, levels := {}) -> void:
	if rays_root == null:
		return
	LightShafts.tick(rays_root, t)
	StageBeams.tick(rays_root, t)
	var by: Dictionary = rays_root.get_meta("levels", {})
	for key in by:
		var lv := clampf(float(levels.get(key, 1.0)), 0.0, 1.0)
		var row: Dictionary = by[key]
		for m in (row["mats"] as Array):
			(m as ShaderMaterial).set_shader_parameter("strength", float(row["strength"]) * lv)
	if not by.is_empty():
		for n in rays_root.get_children():
			var mi := n as MeshInstance3D
			if mi != null and mi.material_override != null:
				mi.visible = float((mi.material_override as ShaderMaterial).get_shader_parameter("strength")) > 1e-5


## The elements of [param spec] that [param name] names: those of that kind, or kept under that name (either in any case); for
## a scene that switches them on and off as it plays ([DispatchScript]'s `environment:`). Their places in the spec's `elements`.
static func named(spec: Dictionary, name: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	var want := name.strip_edges().to_lower()
	var all: Array = spec.get("elements", [])
	for i in all.size():
		var el: Dictionary = all[i]
		if String(el.get("kind", "")) == want or String(el.get("name", "")).to_lower() == want:
			out.append(i)
	return out


## What drifts in the air ([param spec]'s air elements) as [Effects] effects over a host's regions `far`, `near` and `room`, each as
## many as its Amount says (those round the work [param near] times as many, for a host whose region round it is larger), its fog the
## color of [param fog] (a fog's own Color where it has one): made safe by [method Effects.sanitize]. A mote never goes away on a visit:
## its exit is out of the picture the air was built for, and a host's camera moves on to another, where the motes leaving and waiting
## there would stand in a line. Each element's number places its own motes and its own fog's gusts. A fog lies on the floor of the room
## round the scene, as thick as its Density says looked down through it (`sight`: its height and a half again, a line of sight's slant),
## pale where its Color is unset ([method fog_albedo]).
static func effects_of(spec: Dictionary, fog: Color, near := 1.0) -> Array:
	var raw: Array = []
	for e in in_use(spec, "air"):
		var el: Dictionary = e
		var v := values_of(el)
		var fx: Dictionary = (KINDS[String(el["kind"])] as Dictionary)["effect"].duplicate(true)
		# a host's own words first (a table's), then its properties over them; where it is, only where this host has that place
		var own: Dictionary = el.get("own", {})
		for k in own:
			if k != "where" and k != "name":
				fx[k] = own[k]
		if String(own.get("where", "")) in ["far", "near", "room"]:
			fx["where"] = String(own["where"])
		fx["name"] = "%s %d" % [String(el["kind"]), int(el["seed"])]
		if String(fx["kind"]) == "motes":
			fx["count"] = maxi(1, roundi(float(mote_count(el, v)) * (near if String(fx.get("where", "")) == "near" else 1.0)))
			fx["size"] = v["size"]
			fx["glow"] = v["glow"]
			fx["speed"] = v["speed"]
			fx["colors"] = own_colors(own, String(v["color"]))
			fx["away"] = float(own.get("away", 0.0))
		elif String(el["kind"]) == "fog":
			for k in ["density", "rolls", "height", "grain", "settle", "patches", "patch", "chaos", "wind", "turn", "gusts", "stretch",
					"sway", "pace", "breathe", "glow"]:
				fx[k] = v[k]
			fx["shape"] = v["activation"]
			fx["sight"] = float(v["height"]) * 0.025
			fx["color"] = String(v["color"]) if Color.html_is_valid(String(v["color"])) else "#" + fog_albedo(fog).to_html(false)
		else:
			fx["density"] = v["density"]
			fx["rolls"] = v["rolls"]
			fx["drift"] = v["drift"]
			if not Color.html_is_valid(String(own.get("color", ""))):
				fx["color"] = "#" + fog.to_html(false)
		raw.append(fx)
	return Effects.sanitize(raw, ["#" + fog.to_html(false)], ["far", "near", "room"], [])


## The colors motes of color [param color] take, given their host's own words [param own]: its own list where it led with that color
## (each mote takes one), else that color alone.
static func own_colors(own: Dictionary, color: String) -> Array:
	var had: Array = own.get("colors", []) if own.get("colors") is Array else []
	if not had.is_empty() and Color.html_is_valid(String(had[0])) and Color.html(String(had[0])).is_equal_approx(Color.html(color)):
		return had.duplicate()
	return [color]


## What is heard ([param spec]'s sound elements) as a [Soundscape]'s `sound`, made safe; {} for silence. A creature each is one of its
## `creatures`; a host's as written (its `own`) is its words with what it sets over them, its host's own default where it sets nothing.
static func sound_of(spec: Dictionary) -> Dictionary:
	var raw := {}
	for e in in_use(spec, "sound"):
		var el: Dictionary = e
		var row: Dictionary = KINDS[String(el["kind"])]
		var part: Dictionary = (row["spec"] as Dictionary).duplicate(true)
		part.merge(el.get("own", {}), true)
		var v := set_of(el) if el.has("own") else values_of(el)
		for k in v:
			part[_heard_key(String(k))] = v[k]
		if String(row["part"]) == "creatures":
			if not raw.has("creatures"):
				raw["creatures"] = []
			(raw["creatures"] as Array).append(part)
		else:
			raw[String(row["part"])] = part
	return Soundscape.sanitize(raw) if not raw.is_empty() else {}


## A sound's field [param k] as [Soundscape] names it: its `sort` is the soundscape's `kind` (an element's own `kind` is what it is).
static func _heard_key(k: String) -> String:
	return "kind" if k == "sort" else k


## A fog's color where its own is unset: pale, as fog is (the light on it is what colors it), tinted by the light's fog [param fog] -
## never that color itself, the dark a scene fades into far off, which a fog of would only darken the room.
static func fog_albedo(fog: Color) -> Color:
	return FOG_PALE.lerp(fog, FOG_TINT)


## How much of the lamp at the work is on in what [param spec] chooses: [param share] as its light has it (a preset's `lamp`, or the
## scene's own), unless its light switches the lamp on or off ([constant LIGHT_FIELDS] `lamp`).
static func lamp_of(spec: Dictionary, share: float) -> float:
	var el := light_element(spec)
	if el.is_empty():
		return share
	match String(values_of(el).get("lamp", "light")):
		"on":
			return 1.0
		"off":
			return 0.0
	return share


## Whether fog of any kind is in use in [param spec]: a bank of haze, or a fog.
static func hazy(spec: Dictionary) -> bool:
	return in_use(spec, "air").any(func(el: Dictionary) -> bool:
		return String(((KINDS[String(el["kind"])] as Dictionary)["effect"] as Dictionary)["kind"]) == "fog")


## The volumetric fog a scene's environment [param env] wants for what [param spec] chooses: on where a bank of haze or a fog lies (a
## fog volume needs it), at the scene's own density [param own] (0 a scene with none, whose fog is then off), colored as the light's fog.
static func fog_for(env: Environment, spec: Dictionary, own: float) -> void:
	var row := light_of(spec)
	env.volumetric_fog_enabled = own > 0.0 or hazy(spec)
	env.volumetric_fog_density = own
	env.volumetric_fog_albedo = Color.html(String(row["fog"])).lerp(Color(0.75, 0.76, 0.8), 0.5)


## The way to light [param from] (degrees round the scene, [constant Lights.FROM]'s: 0 from behind the viewer, 90 their right) at
## [param height] degrees up: a direction in a scene's own space (x right, y up, z toward the viewer).
static func toward(from: float, height: float) -> Vector3:
	var a := deg_to_rad(from)
	var h := deg_to_rad(height)
	return Vector3(sin(a) * cos(h), sin(h), cos(a) * cos(h))


# --- what the Dex offers -------------------------------------------------------------------------------------------------

## Every element offered built in, by its key on the Dex: each light preset (`preset:<key>`), light shafts, colored beams and fog as
## they roll (`kind:shafts`, `kind:beams`, `kind:fog`) and in each of their looks (`look:<key>`, on their kind's shelf), and every other
## kind (`kind:<key>`) - each `{label, blurb, group, element}`, its element with a fixed number (a new one is drawn when it is added).
## The ride is never offered: it is heard only from a moving table's own plan.
static func offers() -> Dictionary:
	var out := {}
	for k in LIGHTS:
		out["preset:" + k] = {"label": Registry.label(LIGHTS, k), "blurb": Registry.blurb(LIGHTS, k), "group": "light",
			"element": {"kind": "light", "seed": absi(hash(k)) % 1000000, "preset": k}}
	for k in KINDS:
		if k == "light" or k == "ride":
			continue
		out["kind:" + k] = {"label": Registry.label(KINDS, k), "blurb": Registry.blurb(KINDS, k), "group": String((KINDS[k] as Dictionary)["group"]),
			"element": {"kind": k, "seed": absi(hash(k)) % 1000000}}
		var looks: Dictionary = {"shafts": SHAFT_LOOKS, "beams": BEAM_LOOKS, "fog": FOG_LOOKS}.get(k, {})
		for look in looks:
			var el := {"kind": k, "seed": absi(hash(look)) % 1000000}
			el.merge((looks[look] as Dictionary)["set"])
			out["look:" + look] = {"label": Registry.label(looks, look), "blurb": Registry.blurb(looks, look),
				"group": String((KINDS[k] as Dictionary)["group"]), "element": el}
	return out


## What element [param el] is, in a line: its kind's properties that say most ("7 beams, wide, flickering"; "110% as bright as it
## is").
static func line_of(el: Dictionary) -> String:
	var v := values_of(el)
	match String(el.get("kind", "")):
		"light":
			return "%s%% as bright as it is" % str(roundi(float(v["brightness"]) * 100.0))
		"shafts":
			var parts := PackedStringArray(["%d beam%s" % [int(v["count"]), "" if int(v["count"]) == 1 else "s"]])
			parts.append(["thin", "narrow", "wide", "broad"][clampi(int(float(v["width"]) * 4.0), 0, 3)])
			if int(v["inner"]) > 0:
				parts.append("%d inside each" % int(v["inner"]))
			if float(v["flicker"]) >= 0.1:
				parts.append("flickering")
			return ", ".join(parts)
		"beams":
			var parts := PackedStringArray(["%d beam%s" % [int(v["count"]), "" if int(v["count"]) == 1 else "s"]])
			var colors := String(v["color"])
			parts.append("one color" if Color.html_is_valid(colors) and not colors.is_empty() else Registry.label(StageBeams.PALETTES, String(v["palette"])).to_lower())
			parts.append("%d%% moving" % roundi(float(v["moving"]) * 100.0))
			parts.append("a color %ss" % str(snappedf(float(v["hold"]), 0.1)))
			if float(v["strobe"]) >= 0.05:
				parts.append("strobing")
			return ", ".join(parts)
		"fog":
			var parts := PackedStringArray(["%s%% thick" % str(roundi(float(v["density"]) * 100.0))])
			parts.append(("low, %d cm" if float(v["settle"]) >= 0.5 else "%d cm deep") % roundi(float(v["height"])))
			if float(v["patches"]) >= 0.4:
				parts.append("in patches")
			if float(v["wind"]) >= 0.05:
				parts.append("drifting")
			if float(v["sway"]) >= 0.1:
				parts.append("swaying")
			return ", ".join(parts)
	if String(el.get("kind", "")) == "creature":
		var calls: Array = (el.get("own", {}) as Dictionary).get("calls", (KINDS["creature"] as Dictionary)["spec"]["calls"])
		var n := int(v["count"])
		var near := float(v["near"])
		var line := "%s, %s, %s, %s a minute %s" % ["one" if n == 1 else "%d of them" % n, " and ".join(PackedStringArray(calls)),
			"close by" if near > 0.66 else ("some way off" if near > 0.33 else "far off"), str(snappedf(float(v["rate"]), 0.1)),
			"each" if n > 1 else "or so"]
		var vol := float(v.get("volume", 0.0))
		return line + (", %+d dB" % roundi(vol) if absf(vol) >= 0.5 else "")
	var kind_row: Dictionary = KINDS.get(String(el.get("kind", "")), {})
	if kind_row.has("effect"):
		if String((kind_row["effect"] as Dictionary)["kind"]) == "fog":
			return "%s%% thick" % str(roundi(float(v["density"]) * 100.0))
		return "%d%% as many, %s mm" % [roundi(float(v["amount"]) * 100.0), str(snappedf(float(v["size"]), 0.1))]
	return _heard_line(String(el.get("kind", "")), v)


## What sound [param kind] is, in a line, from its values [param v]: what it is like, how far off, and its volume where it is turned
## up or down.
static func _heard_line(kind: String, v: Dictionary) -> String:
	var how := func(x: float, words: Array) -> String: return String(words[clampi(int(x * float(words.size())), 0, words.size() - 1)])
	var off := func(d: float) -> String: return how.call(d, ["close by", "some way off", "far off"])
	var parts := PackedStringArray()
	match kind:
		"wind":
			parts.append("through the %s" % String(v.get("through", "")) if String(v.get("through", "")) != "open" else "in the open")
			parts.append(how.call(float(v.get("level", 0.5)), ["faint", "soft", "steady", "strong"]))
		"rain":
			parts.append("on the %s" % String(v.get("on", "")))
			parts.append(how.call(float(v.get("strength", 0.5)), ["a few drops", "light", "steady", "a downpour"]))
		"fire":
			parts.append(how.call(float(v.get("size", 0.5)), ["embers", "a small fire", "a good fire", "a blaze"]))
			parts.append(off.call(float(v.get("distance", 0.5))))
		"stream":
			parts.append(how.call(float(v.get("size", 0.5)), ["a trickle", "a brook", "a stream", "a rush"]))
			parts.append(off.call(float(v.get("distance", 0.5))))
		"sea":
			parts.append(String(v.get("sort", "")))
			parts.append(how.call(float(v.get("size", 0.5)), ["calm", "moderate", "rough"]))
			parts.append(off.call(float(v.get("distance", 0.5))))
		"insects":
			parts.append(String(v.get("sort", "")))
			parts.append(how.call(float(v.get("amount", 0.25)), ["a lone one", "a few", "many", "a field of them"]))
		"ride":
			parts.append(how.call(float(v.get("level", 0.6)), ["faint", "soft", "steady", "loud"]))
	var vol := float(v.get("volume", 0.0))
	if absf(vol) >= 0.5:
		parts.append("%+d dB" % roundi(vol))
	return ", ".join(parts)


# --- an element's picture ------------------------------------------------------------------------------------------------

## Element [param el] drawn small, as it would be under the light [param spec] chooses: a light its sky over its room, shafts their
## beams over the dark (narrower ones bright inside each, their patches where they land), what drifts as its motes or its haze, what
## is heard as its sound's shape. Drawn in boxes alone, so it is quick on any thread.
static func picture(el: Dictionary, spec: Dictionary, size := PICTURE) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	var kind := String(el.get("kind", ""))
	var v := values_of(el)
	var row := light_of(spec)
	var dark := Color.html(String(row["ambient"])).darkened(0.6)
	img.fill(dark)
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(el.get("seed", 0)), kind, "picture"])
	match String((KINDS.get(kind, {}) as Dictionary).get("group", "")):
		"light":
			if kind == "light":
				_sky(img, v)
			elif kind == "beams":
				_fixtures(img, v, r)
			else:
				_beams(img, v, Color.html(String(v["color"])) if Color.html_is_valid(String(v["color"])) else Color.html(String(row["key_color"])), r)
		"air":
			var fx: Dictionary = (KINDS[kind] as Dictionary)["effect"]
			if kind == "fog":
				var own := Color.html(String(v["color"])) if Color.html_is_valid(String(v["color"])) else fog_albedo(Color.html(String(row["fog"])))
				_fog_picture(img, v, dark, own, r)
			elif String(fx["kind"]) == "fog":
				var fog := Color.html(String(row["fog"])).lerp(Color(0.75, 0.76, 0.8), 0.5)
				for y in size.y:
					var a := float(v["density"]) * (0.25 + 0.75 * float(y) / float(size.y)) * (0.85 + 0.15 * sin(float(y) * 0.21 + r.randf()))
					img.fill_rect(Rect2i(0, y, size.x, 1), dark.lerp(fog, clampf(a, 0.0, 1.0)))
			else:
				var c := Color.html(String(v["color"]))
				var n := mini(mote_count(el, v), 400)
				var px := clampi(roundi(float(v["size"]) * 1.2), 1, 7)
				for i in n:
					var at := Vector2i(r.randi_range(2, size.x - px - 2), r.randi_range(2, size.y - px - 2))
					img.fill_rect(Rect2i(at, Vector2i(px, px)), dark.lerp(c, clampf(0.35 + float(v["glow"]) * r.randf_range(0.5, 1.0), 0.0, 1.0)))
		"sound":
			_sound_shape(img, kind, v, r)
	return img


## A light's picture: its sky's color over its room's, brighter as it is.
static func _sky(img: Image, v: Dictionary) -> void:
	var p := String(v["preset"])
	var row: Dictionary = LIGHTS.get(p, {"ambient": "#30343c", "key_color": "#8a8f99"})
	var sky := Color.html(String(row["key_color"]))
	var room := Color.html(String(row["ambient"]))
	var b := clampf(float(v["brightness"]), 0.25, 2.5)
	var h := img.get_height()
	for y in h:
		var k := float(y) / float(h - 1)
		var c := sky.lerp(room, smoothstep(0.0, 0.8, k))
		img.fill_rect(Rect2i(0, y, img.get_width(), 1), Color(c.r * b, c.g * b, c.b * b).clamp())


## Shafts' picture: each beam a band down the picture, a narrower band inside it adding to it, a patch where it lands.
static func _beams(img: Image, v: Dictionary, color: Color, r: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var floor := h - 14
	var light := PackedFloat32Array()
	light.resize(w)
	var n := int(v["count"])
	var variety := float(v["variety"])
	for i in n:
		var rad := clampf(lerpf(1.0, 18.0, float(v["width"])) * pow(LightShafts.VARIETY_MOST, variety * r.randf()), 0.7, 40.0)
		var mid := (float(i) + r.randf_range(0.25, 0.75)) / float(n) * float(w)
		var bright := 0.75 * (1.0 + r.randf_range(-0.45, 0.25) * absf(variety))
		_band(light, mid, rad, bright)
		for j in int(v["inner"]):
			var ir := rad * r.randf_range(LightShafts.INNER.x, LightShafts.INNER.y)
			_band(light, mid + r.randf_range(-1.0, 1.0) * (rad - ir) * 0.9, ir, 0.75)
	var base := img.get_pixel(0, 0)
	var s := float(v["strength"])
	for x in w:
		var l := light[x]
		img.fill_rect(Rect2i(x, 0, 1, floor), base.lerp(color, clampf(l * s * 0.55, 0.0, 1.0)))
		img.fill_rect(Rect2i(x, floor, 1, h - floor), base.lightened(0.08).lerp(color, clampf(l * s * 1.4, 0.0, 1.0)))


## Colored beams' picture: each a line of its color fanning down from a lens along the top, wider as it opens, a still one straight,
## a moving one leaning as far as it sweeps.
static func _fixtures(img: Image, v: Dictionary, r: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var colors := StageBeams.colors_of(v)
	var n := int(v["count"])
	var base := img.get_pixel(0, 0)
	var s := clampf(float(v["strength"]), 0.1, 1.0)
	for i in n:
		var x0 := (float(i) + 0.5) / float(n) * float(w)
		var lean := 0.0
		if r.randf() < float(v["moving"]):
			lean = r.randf_range(-1.0, 1.0) * float(v["sweep"]) / 70.0
		var c: Color = colors[r.randi() % colors.size()]
		var x1 := x0 + lean * float(h) + r.randf_range(-0.15, 0.15) * float(w) / float(n) * 4.0
		var rad0 := lerpf(0.5, 2.5, float(v["width"]))
		var rad1 := rad0 + float(v["spread"]) * 0.5
		for y in h:
			var u := float(y) / float(h - 1)
			var cx := lerpf(x0, x1, u)
			var rad := lerpf(rad0, rad1, u)
			for x in range(maxi(0, floori(cx - rad - 1.0)), mini(w, ceili(cx + rad + 1.0))):
				var d := absf(float(x) - cx) / maxf(rad, 0.5)
				if d < 1.0:
					var was := img.get_pixel(x, y)
					var a := clampf((1.0 - d * d) * s * (1.0 - 0.45 * u), 0.0, 1.0)
					img.set_pixel(x, y, Color(minf(was.r + c.r * a, 1.0), minf(was.g + c.g * a, 1.0), minf(was.b + c.b * a, 1.0)))
	for i in n:
		img.fill_rect(Rect2i(roundi((float(i) + 0.5) / float(n) * float(w)) - 2, 0, 4, 3), base.lightened(0.5))


## A fog's picture: the ground along its bottom, the fog over it as high as its Height says of a room [constant PICTURE_ROOM] cm tall,
## as low lying as it is, broken into patches and swirls shaped by its Activation, drawn out by its Streaks - in blocks of
## [constant PICTURE_BLOCK] pixels.
static func _fog_picture(img: Image, v: Dictionary, dark: Color, fog: Color, r: RandomNumberGenerator) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var ground := h - 10
	img.fill_rect(Rect2i(0, ground, w, h - ground), dark.lightened(0.12))
	var noise := FastNoiseLite.new()
	noise.seed = r.randi()
	noise.frequency = 1.0
	var top := clampf(float(v["height"]) / PICTURE_ROOM, 0.04, 1.0) * float(ground)
	var settle := float(v["settle"])
	var swirl := maxf(float(v["grain"]) / PICTURE_ROOM * float(ground), 3.0)
	var patch := maxf(float(v["patch"]) * 100.0 / PICTURE_ROOM * float(ground), 6.0)
	var long := 1.0 + 3.0 * float(v["stretch"])
	var shape := String(v["activation"])
	var b := PICTURE_BLOCK
	for y in range(0, ground, b):
		var layer := Effects.fog_layer(settle, float(ground - y) / maxf(top, 1.0))
		if layer <= 0.001:
			continue
		var up := minf(float(ground - y) / maxf(top, 1.0), 1.0)
		for x in range(0, w, b):
			var n := 0.5 + 0.5 * noise.get_noise_2d(float(x) / swirl / long, float(y) / swirl)
			var a := Effects.fog_activation(shape, n + 0.15 * (1.0 - up), n)
			if float(v["patches"]) > 0.0:
				var pn := 0.5 + 0.5 * noise.get_noise_2d(float(x) / patch + 40.0, float(y) / patch * 0.3 + 40.0)
				var cut := lerpf(0.22, 0.68, float(v["patches"]))
				a *= smoothstep(cut - 0.1, cut + 0.1, pn)
			var d := clampf(float(v["density"]) * 1.4 * layer * a, 0.0, 1.0)
			img.fill_rect(Rect2i(x, y, b, b), dark.lerp(fog, d))


static func _band(light: PackedFloat32Array, mid: float, rad: float, bright: float) -> void:
	for x in range(maxi(0, floori(mid - rad)), mini(light.size(), ceili(mid + rad) + 1)):
		var d := (float(x) - mid) / maxf(rad, 0.5)
		if absf(d) < 1.0:
			light[x] += bright * sqrt(1.0 - d * d)


## A sound's picture: bars in its shape - rain many and quick, wind a slow swell, fire crackling, insects in pulses, water in waves.
static func _sound_shape(img: Image, kind: String, v: Dictionary, r: RandomNumberGenerator) -> void:
	var colors := {"rain": "#8fa8c8", "wind": "#c8d0d8", "fire": "#ff9a4a", "insects": "#a8d878", "stream": "#78c8c0", "sea": "#6898d8",
		"creature": "#d8b888", "ride": "#a89888"}
	var c := Color.html(String(colors.get(kind, "#cccccc")))
	var w := img.get_width()
	var h := img.get_height()
	var loud := clampf(float(v.get("strength", v.get("level", v.get("size", 0.5)))), 0.05, 1.0)
	var bars := 44
	var bw := maxi(1, w / bars - 1)
	for i in bars:
		var x := float(i) / float(bars)
		var a := 0.5
		match kind:
			"rain":
				a = r.randf_range(0.2, 1.0)
			"wind":
				a = 0.35 + 0.65 * (0.5 + 0.5 * sin(x * TAU * 1.3))
			"fire":
				a = 0.3 + (0.7 if r.randf() < 0.18 else 0.2 * r.randf())
			"insects":
				a = 0.9 if (i % 6) < 2 else 0.1
			"creature":
				a = 0.8 if r.randf() < 0.12 else 0.06
			"ride":
				a = 0.45 + (0.5 if i % 11 == 0 else 0.05 * r.randf())
			_:
				a = 0.4 + 0.6 * (0.5 + 0.5 * sin(x * TAU * 2.2)) * r.randf_range(0.7, 1.0)
		var bh := maxi(2, roundi(a * loud * float(h) * 0.8))
		img.fill_rect(Rect2i(i * (bw + 1) + 1, (h - bh) / 2, bw, bh), c)


## A thing's name -> its share, made safe from [param v]: names kept short, shares held to [param range], at most 32.
static func _shares(v: Variant, range: Vector2) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in (v as Dictionary):
			var key := Props._text(k, 60)
			if not key.is_empty() and out.size() < 32:
				out[key] = Props._num((v as Dictionary)[k], 1.0, range.x, range.y)
	return out
