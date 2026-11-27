extends RefCounted
class_name DeliveryBank

## DeliveryBank - the vocabulary a script says HOW its words are said in (next/delivery.md), and what it makes of a
## stretch of them. One vocabulary, three forms that differ only in how much they cover: `[words]{terms}` the words in
## the brackets ([constant Manuscript.DELIVERED], read as a closed stretch round them), `<!-- delivery: terms -->` a
## stretch (to its paragraph's end, or to `<!-- /delivery -->`), and the terms themselves comma-separated.
##
## A term is a delivery of [constant BANK] (an expression, a word for one axis, a ramp), an act of [constant ACTS] on
## the stretch's last word (or every word, for `none`, `hit` and `spaced`), a shape of [constant SHAPES] over the
## stretch, or an axis of [constant AXES] given a number (`rate 1.2`, `pitch +3st`, `volume -6dB`, `rate 1..1.4` a ramp).
## Any of them takes a degree: a word of [constant DEGREES] before or after it, or a number after it (0-2). A bank row
## is written in these same terms, so a row is a list of axis values, and a note may name its own
## (`<!-- delivery: giddy = excited, speeding up -->`).
##
## Degree 1 is clearly that, as a good reader would give it: about half of what an actor gives it in the acted corpora
## (`extremely`, 2, is the acted size). Semitones and dB scale with the degree, multipliers by its power.
##
## Pure: [method parse] reads terms, [method resolve] lays a passage's stretches over its tokens - every token's axis
## values (`x`) and acts (`acts`) as the voice host reads them (hosts/voice/inflection.py, piper.py).

## The axes a delivery moves, each against the voice's own. `kind` "mult" adds in log space (a multiplier),
## "add" adds as it is; `lo`/`hi` clamp the sum.
const AXES := {
	"rate": {"label": "Rate", "blurb": "How fast the words go, as a multiplier on the voice's own pace.", "kind": "mult", "lo": 0.5, "hi": 2.0, "unit": "x"},
	"pauses": {"label": "Pauses", "blurb": "How long every rest in the stretch is, as a multiplier over the four kinds below: its commas, its sentence and paragraph ends, its hesitations.", "kind": "mult", "lo": 0.05, "hi": 3.0, "unit": "x"},
	"commas": {"label": "Comma rests", "blurb": "How long the rests at commas, semicolons and colons inside a sentence are, as a multiplier on the voice's own Pause at them.", "kind": "mult", "lo": 0.05, "hi": 4.0, "unit": "x"},
	"ends": {"label": "Sentence rests", "blurb": "How long the rest after a sentence's end is, as a multiplier on the voice's own Pause at sentence ends.", "kind": "mult", "lo": 0.05, "hi": 4.0, "unit": "x"},
	"paragraphs": {"label": "Paragraph rests", "blurb": "How long the rest after a paragraph's end is, as a multiplier on the voice's own Pause at paragraph ends.", "kind": "mult", "lo": 0.05, "hi": 4.0, "unit": "x"},
	"hesitations": {"label": "Hesitations", "blurb": "How long a marked hesitation (<!-- hesitation -->) in the stretch is, as a multiplier on the voice's own Hesitate: near 0 takes it out.", "kind": "mult", "lo": 0.0, "hi": 4.0, "unit": "x"},
	"pitch": {"label": "Pitch", "blurb": "The register, in semitones up or down, moved inside the model so the speaker keeps their size.", "kind": "add", "lo": -8.0, "hi": 14.0, "unit": "st"},
	"range": {"label": "Range", "blurb": "How far the pitch swings about its running mean, as a multiplier: 0 is a monotone, 2 twice as lively. Scales the inflections too.", "kind": "mult", "lo": 0.02, "hi": 3.0, "unit": "x"},
	"volume": {"label": "Volume", "blurb": "The level in the mix, in dB, eased in and out and never into the clip.", "kind": "add", "lo": -20.0, "hi": 8.0, "unit": "dB"},
	"effort": {"label": "Effort", "blurb": "The spectral tilt of a tense (up to 1) or lax (down to -1) voice, the level kept.", "kind": "add", "lo": -1.0, "hi": 1.0, "unit": ""},
	"push": {"label": "Push", "blurb": "The pressed voice of the model's own style space: 1 is two of its readers' standard deviations along it.", "kind": "add", "lo": -1.0, "hi": 1.0, "unit": ""},
	"breath": {"label": "Breath", "blurb": "The breathy voice of the model's own style space: 1 is three of its readers' standard deviations along it.", "kind": "add", "lo": -1.0, "hi": 1.0, "unit": ""},
	"whisper": {"label": "Whisper", "blurb": "How much of the voice is breath in place of its voicing: 1 a whisper.", "kind": "add", "lo": 0.0, "hi": 1.0, "unit": ""},
	"tremor": {"label": "Tremor", "blurb": "A shaking voice: 1 is +-0.8 semitones and +-3 dB at about six a second, its rate wandering.", "kind": "add", "lo": 0.0, "hi": 1.0, "unit": ""},
	"precision": {"label": "Precision", "blurb": "Consonants held longer (crisp, up to 1) or shorter (slurred, down to -1).", "kind": "add", "lo": -1.0, "hi": 1.0, "unit": ""},
}

## Words of degree, before or after a term (`very sad`, `drawn a little`).
const DEGREES := {
	"barely": {"label": "Barely", "blurb": "A quarter of the term.", "value": 0.25},
	"slightly": {"label": "Slightly", "blurb": "Half of the term.", "value": 0.5},
	"a little": {"label": "A little", "blurb": "Half of the term.", "value": 0.5},
	"a bit": {"label": "A bit", "blurb": "Half of the term.", "value": 0.5},
	"somewhat": {"label": "Somewhat", "blurb": "Three quarters of the term.", "value": 0.75},
	"quite": {"label": "Quite", "blurb": "One and a half times the term.", "value": 1.5},
	"really": {"label": "Really", "blurb": "One and a half times the term.", "value": 1.5},
	"much": {"label": "Much", "blurb": "One and a half times the term.", "value": 1.5},
	"very": {"label": "Very", "blurb": "One and three quarters times the term.", "value": 1.75},
	"a lot": {"label": "A lot", "blurb": "One and three quarters times the term.", "value": 1.75},
	"extremely": {"label": "Extremely", "blurb": "Twice the term: the size an actor gives it.", "value": 2.0},
}

## How a stretch's terms move between its start and its end. With none, a stretch to its paragraph's end eases in
## over its first syllables and back out after it; a closed one is exact.
const SHAPES := {
	"building": {"label": "Building", "blurb": "From nothing at the stretch's start to all of it at its end: crescendo, poco a poco.", "aka": ["building up", "gradually", "growing", "poco a poco"]},
	"fading": {"label": "Fading", "blurb": "From all of it at the stretch's start to nothing at its end: diminuendo.", "aka": ["fading out", "easing off"]},
	"swelling": {"label": "Swelling", "blurb": "From nothing to all of it three fifths of the way, and back to nothing.", "aka": ["swell"]},
	"sudden": {"label": "Sudden", "blurb": "All of it from the first word, eased neither in nor out: subito.", "aka": ["suddenly", "subito", "all at once"]},
}

## What a word does: on the stretch's last word, or every word (`every`). `kind` says where the voice host makes it:
## "contour" a pitch shape on the word, "timing" its sounds held or cut, "emph" the stress italic (1) or bold (2) gives.
## `told` is what it sounds like in a few words, as an agent writing a script is told it ([method listed]).
## `contour` is the pitch it draws over its word at degree 1, as the voice host draws it (inflection.py `_contour`): `[[at,
## semitones]]`, `at` 0 to 1 across the word or an anchor on its stressed vowel ("stress<" its start, "stress" its middle,
## "stress>" its end). A delivery may draw its own ([method from_spec]: an act's third element), times its degree.
const ACTS := {
	"rise": {"label": "Rise", "told": "a question's rise", "blurb": "A question's rise by the word's end, whatever the sentence is (H-H%).", "kind": "contour", "aka": ["rising end", "question"], "contour": [[0.0, 0.0], ["stress<", -0.7], ["stress>", 6.0], [1.0, 6.0]]},
	"low rise": {"label": "Low rise", "told": "low, rising at the end: tentative", "blurb": "Low, then a rise at the very end: a polite or tentative question (L* H-H%).", "kind": "contour", "aka": ["tentative"], "contour": [[0.0, 0.0], ["stress<", -1.5], ["stress>", -1.0], [1.0, 4.0]]},
	"fall": {"label": "Fall", "told": "a firm fall: final", "blurb": "A full fall to the floor: final and certain, a question said as a statement (H* L-L%).", "kind": "contour", "aka": ["falling end", "final"], "contour": [["stress<", 0.0], ["stress", 1.0], [1.0, -5.0]]},
	"rise-fall": {"label": "Rise-fall", "told": "up then down: impressed, insisting", "blurb": "Up then down across the stressed vowel: impressed, insisting.", "kind": "contour", "aka": ["rise fall"], "contour": [["stress<", 0.0], ["stress", 4.0], ["stress>", 2.0], [1.0, -3.0]]},
	"fall-rise": {"label": "Fall-rise", "told": "down then up: a reservation", "blurb": "Down then up: a reservation, an implied but.", "kind": "contour", "aka": ["fall rise"], "contour": [["stress<", 0.0], ["stress", -3.0], ["stress>", -2.0], [1.0, 3.0]]},
	"contrast": {"label": "Contrast", "told": "this one, not that one", "blurb": "A dip, then a steep rise onto the stressed vowel and a fall: this one, not that one (L+H*).", "kind": "contour", "aka": ["correction", "contrastive"], "contour": [[0.0, 0.0], ["stress<", -2.0], ["stress", 4.0], [1.0, -1.0]]},
	"scoop": {"label": "Scoop", "told": "low, rising late: doubt, disbelief", "blurb": "Low on the stressed vowel, rising late in the word: doubt, incredulity (L*+H).", "kind": "contour", "aka": ["incredulous", "doubting"], "contour": [["stress<", -2.0], ["stress", -1.5], ["stress>", 1.0], [1.0, 3.0]]},
	"reminder": {"label": "Reminder", "told": "a step down: as we know", "blurb": "A step down onto the stressed vowel: as we know (H+!H*).", "kind": "contour", "aka": ["as we know"], "contour": [[0.0, 2.0], ["stress<", 2.0], ["stress", -1.0], [1.0, -2.0]]},
	"held": {"label": "Held", "told": "level, unfinished: a list, suspense", "blurb": "Level from the stressed vowel on, no fall: not finished, a list, suspense.", "kind": "contour", "aka": ["level", "suspended", "hanging"], "contour": [["stress<", 0.0], [1.0, 0.0]]},
	"chant": {"label": "Chant", "told": "a name called across a room", "blurb": "Two levels held, high then a step lower: a name called across a room.", "kind": "contour", "aka": ["calling contour", "sing-song call"], "contour": [["stress<", 2.0], ["stress>", 2.0], [0.8, 0.0], [1.0, 0.0]]},
	"drawn": {"label": "Drawn", "told": "held longer on a gentle hill", "blurb": "The word's last vowel and what sounds after it held a third of a second more, its pitch a gentle hill (up, then down): searching, suspense, savoring.", "kind": "timing", "aka": ["drawn out", "elongated", "stretched", "lengthened", "prolonged"], "contour": [["stress<", 0.0], [0.25, 3.0], [1.0, -3.0]]},
	"clipped": {"label": "Clipped", "told": "cut short: curt", "blurb": "The word's last sound cut short, no trail: curt.", "kind": "timing", "aka": ["curt"]},
	"cut off": {"label": "Cut off", "told": "stops at its first vowel: interrupted", "blurb": "The word stops at its first vowel's end, as if interrupted.", "kind": "timing", "aka": ["broken off", "interrupted"]},
	"spaced": {"label": "Spaced", "told": "every word hit, slow and crisp", "blurb": "Every word hit and slowed, crisp: ab-so-lute-ly.", "kind": "timing", "every": true, "aka": ["marcato", "each syllable"], "contour": [["stress<", 0.0], ["stress", 2.0], [1.0, -1.0]]},
	"none": {"label": "None", "told": "plain: no accent, no rise", "blurb": "No accent and no rise the text would give: as plain as the voice says it.", "kind": "contour", "every": true, "aka": ["no inflection", "uninflected"]},
	"hit": {"label": "Hit", "told": "stressed as an italic word", "blurb": "Stressed as an italic word is: higher at its stressed vowel, held longer, a little louder.", "kind": "emph", "every": true, "aka": ["stressed", "emphasized", "leaned on"]},
	"hit hard": {"label": "Hit hard", "told": "stressed as a bold word", "blurb": "Stressed as a bold word is, the hardest of the two.", "kind": "emph", "every": true, "aka": ["strongly stressed"]},
}

## The families [constant BANK] is offered in.
const FAMILIES := {
	"axis": {"label": "One axis", "blurb": "A word for a step along one axis."},
	"ramp": {"label": "Ramps", "blurb": "One axis or a few moved from the stretch's start to its end."},
	"lively": {"label": "Lively", "blurb": "High arousal, pleasant."},
	"heated": {"label": "Heated", "blurb": "High arousal, unpleasant: anger and its kin."},
	"afraid": {"label": "Afraid", "blurb": "Fear and its kin."},
	"low": {"label": "Low", "blurb": "Low arousal, unpleasant: sadness and its kin."},
	"calm": {"label": "Calm and warm", "blurb": "Low arousal, pleasant."},
	"stance": {"label": "Stance", "blurb": "An attitude to what is said or who hears it."},
	"effort": {"label": "Effort", "blurb": "Vocal effort, a whisper to a scream: loudness carried by quality more than level."},
	"style": {"label": "Performance styles", "blurb": "A person's way of telling."},
	"state": {"label": "Physical states", "blurb": "What the body is doing to the voice."},
}

## Every named delivery: its family, its terms (the same grammar a mark takes), its synonyms (`aka`), and for a ramp of
## rate how it brakes (`curve`: q of Friberg and Sundberg's v(x) = [1 + (w^q - 1) x]^(1/q); 2 constant braking force,
## 3 constant power). Numbers are degree 1, anchored in next/delivery.md.
const BANK := {
	# -- one axis
	"faster": {"label": "Faster", "blurb": "Quicker than the voice's own.", "family": "axis", "terms": "rate 1.15", "aka": ["quicker", "brisker", "quick", "fast"]},
	"slower": {"label": "Slower", "blurb": "Slower than the voice's own.", "family": "axis", "terms": "rate 0.87", "aka": ["slow"]},
	"higher": {"label": "Higher", "blurb": "Two semitones up.", "family": "axis", "terms": "pitch +2st", "aka": ["higher pitched"]},
	"lower": {"label": "Lower", "blurb": "Two semitones down.", "family": "axis", "terms": "pitch -2st", "aka": ["lower pitched", "deeper"]},
	"livelier": {"label": "Livelier", "blurb": "The pitch swinging half as far again.", "family": "axis", "terms": "range 1.5", "aka": ["more expressive", "animated"]},
	"flatter": {"label": "Flatter", "blurb": "The pitch swinging a little over half as far.", "family": "axis", "terms": "range 0.6", "aka": ["less expressive"]},
	"monotone": {"label": "Monotone", "blurb": "Nearly no pitch movement at all.", "family": "axis", "terms": "range 0.15", "aka": []},
	"louder": {"label": "Louder", "blurb": "Up 4 dB, a little more effort.", "family": "axis", "terms": "volume +4dB, effort 0.2", "aka": []},
	"softer": {"label": "Softer", "blurb": "Down 4 dB, a little less effort.", "family": "axis", "terms": "volume -4dB, effort -0.2", "aka": ["quieter"]},
	"tighter": {"label": "Tighter", "blurb": "Every rest seven tenths as long.", "family": "axis", "terms": "pauses 0.7", "aka": ["shorter pauses"]},
	"looser": {"label": "Looser", "blurb": "Every rest two fifths longer.", "family": "axis", "terms": "pauses 1.4", "aka": ["longer pauses"]},
	"brighter": {"label": "Brighter", "blurb": "A semitone up and a little livelier.", "family": "axis", "terms": "pitch +1st, range 1.2", "aka": []},
	"graver": {"label": "Graver", "blurb": "A semitone down and a little flatter.", "family": "axis", "terms": "pitch -1st, range 0.85", "aka": ["darker"]},
	"tense": {"label": "Tense", "blurb": "A tense voice's tilt.", "family": "axis", "terms": "effort 0.5", "aka": ["tenser"]},
	"lax": {"label": "Lax", "blurb": "A lax voice's tilt.", "family": "axis", "terms": "effort -0.5", "aka": []},
	"pressed": {"label": "Pressed", "blurb": "Along the model's pressed axis.", "family": "axis", "terms": "push 0.6", "aka": []},
	"slack": {"label": "Slack", "blurb": "Against the model's pressed axis.", "family": "axis", "terms": "push -0.6", "aka": []},
	"breathier": {"label": "Breathier", "blurb": "Along the model's breathy axis.", "family": "axis", "terms": "breath 0.5", "aka": ["breathy"]},
	"clearer": {"label": "Clearer", "blurb": "Against the model's breathy axis.", "family": "axis", "terms": "breath -0.5", "aka": []},
	"whispered": {"label": "Whispered", "blurb": "All breath, no voicing.", "family": "axis", "terms": "whisper 1", "aka": []},
	"unhesitating": {"label": "Unhesitating", "blurb": "Its marked hesitations a fifth as long: sure of every word.", "family": "axis", "terms": "hesitations 0.2", "aka": ["fluent", "without hesitating"]},
	"unhurried": {"label": "Unhurried", "blurb": "Longer rests after its sentences and its paragraphs, its words at their own pace.", "family": "axis", "terms": "ends 1.3, paragraphs 1.5", "aka": ["taking its time", "leisurely"]},
	"crisp": {"label": "Crisp", "blurb": "Consonants held longer.", "family": "axis", "terms": "precision 0.6", "aka": ["precise"]},
	"slurred": {"label": "Slurred", "blurb": "Consonants run together.", "family": "axis", "terms": "precision -0.6", "aka": []},
	"steady": {"label": "Steady", "blurb": "The voice's own: on a line of its own, it ends a delivery.", "family": "axis", "terms": "", "aka": ["neutral", "normal", "plain", "narrator"]},
	# -- ramps
	"speeding up": {"label": "Speeding up", "blurb": "Rate from the voice's own to 1.3 times it.", "family": "ramp", "terms": "rate 1..1.3", "curve": 2, "aka": ["accelerando", "getting faster", "accelerating", "picking up speed"]},
	"slowing down": {"label": "Slowing down", "blurb": "Rate down to three quarters, braking as a runner stops.", "family": "ramp", "terms": "rate 1..0.75", "curve": 2, "aka": ["ritardando", "getting slower", "slowing"]},
	"running down": {"label": "Running down", "blurb": "Rate down to seven tenths, braking harder at the end.", "family": "ramp", "terms": "rate 1..0.7", "curve": 3, "aka": ["rallentando"]},
	"rising": {"label": "Rising", "blurb": "The register climbing four semitones.", "family": "ramp", "terms": "pitch 0..4st", "aka": ["climbing", "pitch rising"]},
	"sinking": {"label": "Sinking", "blurb": "The register sinking three semitones.", "family": "ramp", "terms": "pitch 0..-3st", "aka": ["dropping", "pitch falling"]},
	"getting louder": {"label": "Getting louder", "blurb": "Up 6 dB by the end, with effort: crescendo.", "family": "ramp", "terms": "volume 0..6dB, effort 0..0.3", "aka": ["crescendo", "growing louder"]},
	"getting softer": {"label": "Getting softer", "blurb": "Down 6 dB by the end: diminuendo.", "family": "ramp", "terms": "volume 0..-6dB, effort 0..-0.3", "aka": ["diminuendo", "growing softer", "getting quieter"]},
	"tightening": {"label": "Tightening", "blurb": "Every rest shortening to half by the end.", "family": "ramp", "terms": "pauses 1..0.5", "aka": ["picking up the cues"]},
	"loosening": {"label": "Loosening", "blurb": "Every rest lengthening to nearly twice by the end.", "family": "ramp", "terms": "pauses 1..1.8", "aka": []},
	"opening up": {"label": "Opening up", "blurb": "The pitch swinging wider by the end.", "family": "ramp", "terms": "range 1..1.6", "aka": []},
	"flattening": {"label": "Flattening", "blurb": "The pitch swinging half as far by the end.", "family": "ramp", "terms": "range 1..0.5", "aka": []},
	"dying away": {"label": "Dying away", "blurb": "Slower, softer, lower and breathier together: morendo.", "family": "ramp", "terms": "rate 1..0.8, volume 0..-8dB, pitch 0..-2st, breath 0..0.4", "aka": ["morendo", "smorzando", "trailing off", "fading away"]},
	"heating up": {"label": "Heating up", "blurb": "Faster, higher, louder and more pressed together.", "family": "ramp", "terms": "rate 1..1.2, pitch 0..3st, volume 0..5dB, push 0..0.5", "aka": ["worked up", "getting heated"]},
	"cooling down": {"label": "Cooling down", "blurb": "Settling a little slower, lower and softer.", "family": "ramp", "terms": "rate 1..0.9, pitch 0..-1st, volume 0..-3dB, push 0..-0.2", "aka": ["calming down", "settling"]},
	# -- lively
	"excited": {"label": "Excited", "blurb": "Quick, high, lively and loud, the rests short.", "family": "lively", "terms": "rate 1.15, commas 0.7, ends 0.75, paragraphs 0.9, hesitations 0.6, pitch +3st, range 1.6, volume +3dB, push 0.3", "aka": []},
	"joyful": {"label": "Joyful", "blurb": "Up in pitch and lively, a little quick.", "family": "lively", "terms": "rate 1.05, pauses 0.9, pitch +2.5st, range 1.5, volume +2dB, push 0.1", "aka": ["happy", "cheerful", "glad"]},
	"amused": {"label": "Amused", "blurb": "Up and lively with breath in it.", "family": "lively", "terms": "rate 1.05, pauses 0.9, pitch +2st, range 1.4, volume +1dB, breath 0.3", "aka": []},
	"playful": {"label": "Playful", "blurb": "Quick, up and swinging.", "family": "lively", "terms": "rate 1.1, pauses 0.9, pitch +2st, range 1.5, volume +1dB", "aka": ["teasing"]},
	"triumphant": {"label": "Triumphant", "blurb": "Full, loud and measured.", "family": "lively", "terms": "rate 0.95, pitch +1st, range 1.3, volume +4dB, push 0.4", "aka": ["proud", "victorious"]},
	"amazed": {"label": "Amazed", "blurb": "Slow, wide and breathy: awe.", "family": "lively", "terms": "rate 0.85, pauses 1.3, pitch +2st, range 1.6, breath 0.4", "aka": ["awed", "in awe", "astonished", "wondering"]},
	"surprised": {"label": "Surprised", "blurb": "High and swinging far.", "family": "lively", "terms": "rate 0.95, pitch +6st, range 2.5, volume +3dB, push 0.2", "aka": ["startled"]},
	"curious": {"label": "Curious", "blurb": "Up and a little lively.", "family": "lively", "terms": "rate 1.05, pitch +1.5st, range 1.3, volume +1dB", "aka": ["interested"]},
	"eager": {"label": "Eager", "blurb": "Quick and up, leaning in.", "family": "lively", "terms": "rate 1.12, pauses 0.8, pitch +1.5st, range 1.3, volume +2dB, push 0.2", "aka": ["enthusiastic"]},
	# -- heated
	"angry": {"label": "Angry", "blurb": "Loud, pressed, high and crisp, the pitch swinging far.", "family": "heated", "terms": "rate 1.1, commas 0.75, ends 0.85, hesitations 0.5, pitch +4st, range 1.8, volume +5dB, push 0.7, effort 0.4, precision 0.5", "aka": ["mad", "cross"]},
	"furious": {"label": "Furious", "blurb": "Angry, twice over.", "family": "heated", "terms": "angry 2", "aka": ["enraged", "livid", "raging"]},
	"seething": {"label": "Seething", "blurb": "Cold anger: low, slow, pressed and crisp.", "family": "heated", "terms": "rate 0.9, commas 1.2, ends 1.4, hesitations 0.6, pitch -1.5st, range 1.4, volume +1dB, push 0.5, precision 0.6", "aka": ["cold anger", "coldly angry"]},
	"irritated": {"label": "Irritated", "blurb": "A little quick, loud and pressed.", "family": "heated", "terms": "rate 1.05, pauses 0.9, pitch +1st, range 1.2, volume +2dB, push 0.4", "aka": ["annoyed", "irritable"]},
	"frustrated": {"label": "Frustrated", "blurb": "Up, loud, with breath in it.", "family": "heated", "terms": "pauses 0.9, pitch +2st, range 1.5, volume +3dB, push 0.2, breath 0.3", "aka": ["exasperated"]},
	"disgusted": {"label": "Disgusted", "blurb": "Slow and narrow.", "family": "heated", "terms": "rate 0.8, pauses 1.1, pitch +1st, range 1.4, push 0.2", "aka": ["revolted"]},
	"contemptuous": {"label": "Contemptuous", "blurb": "The lowest pitch of all, slow.", "family": "heated", "terms": "rate 0.85, pauses 1.2, pitch -3st, range 1.2, volume -1dB, push 0.2", "aka": ["scornful", "disdainful"]},
	"impatient": {"label": "Impatient", "blurb": "Quick and loud, the rests short.", "family": "heated", "terms": "rate 1.15, commas 0.65, ends 0.7, hesitations 0.4, pitch +1st, range 1.2, volume +3dB, push 0.3", "aka": []},
	"urgent": {"label": "Urgent", "blurb": "Quick, loud and tight.", "family": "heated", "terms": "rate 1.15, commas 0.65, ends 0.7, paragraphs 0.8, hesitations 0.4, pitch +1st, range 1.1, volume +3dB, push 0.3", "aka": ["hurried", "rushed"]},
	# -- afraid
	"nervous": {"label": "Nervous", "blurb": "A little quick, flat and breathy, shaking a little.", "family": "afraid", "terms": "rate 1.08, commas 0.9, ends 1.1, hesitations 1.6, pitch +0.5st, range 0.8, volume -1dB, breath 0.3, tremor 0.15", "aka": ["anxious", "uneasy"]},
	"scared": {"label": "Scared", "blurb": "Quick, high and breathy, shaking.", "family": "afraid", "terms": "rate 1.15, commas 0.75, ends 0.8, hesitations 1.4, pitch +5st, range 1.2, volume +1dB, breath 0.4, tremor 0.3", "aka": ["afraid", "frightened", "fearful"]},
	"panicked": {"label": "Panicked", "blurb": "Very quick and very high, shaking hard.", "family": "afraid", "terms": "rate 1.3, commas 0.5, ends 0.6, paragraphs 0.7, hesitations 0.8, pitch +8st, range 1.5, volume +4dB, push 0.2, breath 0.3, tremor 0.5", "aka": ["terrified", "panicking"]},
	"desperate": {"label": "Desperate", "blurb": "High and loud, flat, shaking.", "family": "afraid", "terms": "rate 0.9, pauses 1.1, hesitations 1.3, pitch +4st, range 0.8, volume +4dB, breath 0.3, tremor 0.3", "aka": ["despairing"]},
	"pleading": {"label": "Pleading", "blurb": "Up and lively, breathy, shaking a little.", "family": "afraid", "terms": "rate 0.92, pauses 1.1, pitch +3st, range 1.4, volume +1dB, breath 0.4, tremor 0.2", "aka": ["begging"]},
	# -- low
	"sad": {"label": "Sad", "blurb": "Slow, low, flat and soft, the rests long.", "family": "low", "terms": "rate 0.85, commas 1.3, ends 1.5, paragraphs 1.7, hesitations 1.3, pitch -1.5st, range 0.6, volume -4dB, breath 0.4, precision -0.3", "aka": ["unhappy"]},
	"grieving": {"label": "Grieving", "blurb": "Quiet sorrow: very slow, low and soft.", "family": "low", "terms": "rate 0.7, commas 1.4, ends 1.7, paragraphs 2, hesitations 1.5, pitch -2.5st, range 0.5, volume -6dB, breath 0.6", "aka": ["grief", "mournful", "sorrowful"]},
	"tearful": {"label": "Tearful", "blurb": "Up, breathy and shaking.", "family": "low", "terms": "rate 0.85, pauses 1.3, pitch +3st, range 0.8, volume -2dB, breath 0.6, tremor 0.6", "aka": ["close to tears"]},
	"disappointed": {"label": "Disappointed", "blurb": "A little slow, low and soft.", "family": "low", "terms": "rate 0.9, pauses 1.2, pitch -1st, range 0.8, volume -2dB, breath 0.3", "aka": ["let down"]},
	"resigned": {"label": "Resigned", "blurb": "Slow, low and flat.", "family": "low", "terms": "rate 0.88, pauses 1.3, pitch -2st, range 0.6, volume -3dB, breath 0.4", "aka": []},
	"weary": {"label": "Weary", "blurb": "Slow, low, slack and slurred.", "family": "low", "terms": "rate 0.85, pauses 1.3, pitch -2st, range 0.6, volume -3dB, push -0.3, breath 0.4, precision -0.3", "aka": ["tired", "exhausted"]},
	"bored": {"label": "Bored", "blurb": "Slow, low and flat.", "family": "low", "terms": "rate 0.85, pauses 1.2, pitch -3st, range 0.5, volume -2dB, breath 0.2", "aka": []},
	"ashamed": {"label": "Ashamed", "blurb": "Quiet and a little low.", "family": "low", "terms": "rate 0.9, pauses 1.2, pitch -1st, range 1.1, volume -5dB, breath 0.4", "aka": ["embarrassed", "sheepish"]},
	"hurt": {"label": "Hurt", "blurb": "Soft and breathy, shaking a little.", "family": "low", "terms": "rate 0.9, pauses 1.2, pitch +1st, range 0.9, volume -2dB, breath 0.4, tremor 0.2", "aka": ["wounded"]},
	"wistful": {"label": "Wistful", "blurb": "Slow, soft and breathy.", "family": "low", "terms": "rate 0.88, pauses 1.3, pitch -1st, range 0.8, volume -3dB, breath 0.4", "aka": ["nostalgic", "melancholy", "longing"]},
	# -- calm and warm
	"tender": {"label": "Tender", "blurb": "Slow, low, soft and breathy.", "family": "calm", "terms": "rate 0.9, pauses 1.2, pitch -1st, range 0.8, volume -3dB, push -0.2, breath 0.4", "aka": ["affectionate", "loving", "gentle"]},
	"calm": {"label": "Calm", "blurb": "Even and a little low.", "family": "calm", "terms": "rate 0.92, pauses 1.15, pitch -1st, range 0.75, volume -1dB, push -0.2, breath 0.2", "aka": ["serene", "peaceful"]},
	"content": {"label": "Content", "blurb": "Lax and easy.", "family": "calm", "terms": "rate 0.95, pauses 1.1, pitch -0.5st, range 0.9, volume -1dB, push -0.2, breath 0.2", "aka": ["relaxed", "pleased", "satisfied"]},
	"relieved": {"label": "Relieved", "blurb": "Up a little, breathy.", "family": "calm", "terms": "rate 0.92, pauses 1.2, pitch +1st, range 1.2, volume -1dB, breath 0.4", "aka": []},
	"warm": {"label": "Warm", "blurb": "Up a little and lively.", "family": "calm", "terms": "pitch +1st, range 1.2, breath 0.1", "aka": ["friendly", "kind"]},
	"reassuring": {"label": "Reassuring", "blurb": "Slow, low and even.", "family": "calm", "terms": "rate 0.88, pauses 1.2, pitch -1.5st, range 0.8, volume -2dB, breath 0.3", "aka": ["soothing", "comforting"]},
	"intimate": {"label": "Intimate", "blurb": "Close and quiet, breathy.", "family": "calm", "terms": "rate 0.9, pauses 1.1, pitch -1st, range 0.8, volume -6dB, push -0.3, breath 0.6", "aka": ["confiding"]},
	"dreamy": {"label": "Dreamy", "blurb": "Slow and breathy, drifting up.", "family": "calm", "terms": "rate 0.85, pauses 1.3, pitch +1st, range 1.2, volume -2dB, breath 0.5", "aka": []},
	# -- stance
	"serious": {"label": "Serious", "blurb": "A little slow, low and flat.", "family": "stance", "terms": "rate 0.95, pauses 1.15, hesitations 0.7, pitch -1st, range 0.7, push 0.1", "aka": []},
	"deadpan": {"label": "Deadpan", "blurb": "A straight face: nearly no inflection.", "family": "stance", "terms": "rate 0.95, pitch -1st, range 0.3", "aka": ["straight-faced", "poker-faced"]},
	"grave": {"label": "Grave", "blurb": "Slow, low and flat.", "family": "stance", "terms": "rate 0.85, pauses 1.3, pitch -2st, range 0.6, volume -1dB, push 0.1", "aka": ["solemn", "somber"]},
	"dry": {"label": "Dry", "blurb": "A little low and flat.", "family": "stance", "terms": "pitch -0.5st, range 0.7", "aka": ["wry"]},
	"confident": {"label": "Confident", "blurb": "Lower, louder and a little quick.", "family": "stance", "terms": "rate 1.05, pauses 0.9, hesitations 0.4, pitch -1st, range 1.1, volume +2dB, push 0.3", "aka": ["assured", "certain", "sure"]},
	"commanding": {"label": "Commanding", "blurb": "Low, loud, pressed and crisp.", "family": "stance", "terms": "rate 0.95, commas 0.9, hesitations 0.3, pitch -2st, volume +4dB, push 0.5, precision 0.4", "aka": ["authoritative", "stern", "firm"]},
	"doubtful": {"label": "Doubtful", "blurb": "Higher and slower.", "family": "stance", "terms": "rate 0.92, pauses 1.2, hesitations 1.4, pitch +1.5st, range 1.1, volume -1dB, breath 0.2", "aka": ["uncertain", "unsure", "hesitant"]},
	"confused": {"label": "Confused", "blurb": "Higher, slower and swinging.", "family": "stance", "terms": "rate 0.92, pauses 1.2, hesitations 1.4, pitch +1.5st, range 1.3", "aka": ["puzzled", "baffled"]},
	"sarcastic": {"label": "Sarcastic", "blurb": "Slow, low and flat, a little rough.", "family": "stance", "terms": "rate 0.75, pauses 1.1, pitch -1st, range 0.75, volume +1dB, breath 0.2", "aka": ["ironic"]},
	"mocking": {"label": "Mocking", "blurb": "Up and swinging too far.", "family": "stance", "terms": "pitch +2st, range 1.8", "aka": ["taunting", "sing-song"]},
	"suspicious": {"label": "Suspicious", "blurb": "Slow and low.", "family": "stance", "terms": "rate 0.9, pauses 1.2, pitch -1st, range 1.1, volume -1dB", "aka": ["skeptical", "wary"]},
	"conspiratorial": {"label": "Conspiratorial", "blurb": "Quick and hushed.", "family": "stance", "terms": "rate 1.05, pauses 0.9, pitch -1st, range 0.8, volume -6.5dB, breath 0.6, whisper 0.3", "aka": ["secretive"]},
	"polite": {"label": "Polite", "blurb": "A little up, even and crisp.", "family": "stance", "terms": "rate 0.95, pauses 1.05, pitch +0.5st, range 0.9, volume -1dB, precision 0.3", "aka": ["formal", "courteous"]},
	"casual": {"label": "Casual", "blurb": "Quick, easy and slurred a little.", "family": "stance", "terms": "rate 1.1, pauses 0.9, pitch -0.5st, range 0.8, volume -1dB, push -0.2, precision -0.2", "aka": ["offhand", "nonchalant"]},
	"defiant": {"label": "Defiant", "blurb": "Loud and pressed.", "family": "stance", "terms": "range 1.2, volume +3dB, push 0.5", "aka": ["determined", "resolute"]},
	"impressed": {"label": "Impressed", "blurb": "Slow and swinging wide.", "family": "stance", "terms": "rate 0.9, pauses 1.1, pitch +1st, range 1.6, volume +1dB", "aka": []},
	"mysterious": {"label": "Mysterious", "blurb": "Slow, low, soft and breathy.", "family": "stance", "terms": "rate 0.85, commas 1.2, ends 1.3, paragraphs 1.5, hesitations 1.2, pitch -1st, range 1.1, volume -3dB, breath 0.4", "aka": ["ominous", "eerie", "intrigued"]},
	"apologetic": {"label": "Apologetic", "blurb": "Up a little, soft and breathy.", "family": "stance", "terms": "rate 0.92, pauses 1.1, pitch +1st, range 0.9, volume -2dB, breath 0.3", "aka": ["sorry"]},
	"thrown away": {"label": "Thrown away", "blurb": "An aside not worth a stress: quick, flat, soft, no accent.", "family": "stance", "terms": "rate 1.2, range 0.4, volume -3dB, none", "aka": ["aside", "throwaway"]},
	# -- effort
	"whispering": {"label": "Whispering", "blurb": "A whisper: all breath.", "family": "effort", "terms": "rate 0.9, range 0.7, volume -1dB, whisper 1", "aka": ["whisper"]},
	"hushed": {"label": "Hushed", "blurb": "Under the breath: half whispered.", "family": "effort", "terms": "rate 0.92, pauses 1.1, pitch -1st, range 0.7, volume -6dB, breath 0.6, whisper 0.4", "aka": ["murmuring", "under the breath", "sotto voce"]},
	"soft": {"label": "Soft", "blurb": "A relaxed, quiet voice.", "family": "effort", "terms": "rate 0.95, pitch -0.5st, range 0.9, volume -4dB, push -0.3, breath 0.3, effort -0.4", "aka": ["softly", "quiet"]},
	"raised": {"label": "Raised", "blurb": "A voice raised a step.", "family": "effort", "terms": "pitch +3st, volume +3dB, push 0.3, effort 0.3", "aka": ["raised voice", "projecting"]},
	"loud": {"label": "Loud", "blurb": "A loud voice: higher, pressed.", "family": "effort", "terms": "rate 0.97, pitch +5st, range 0.9, volume +5dB, push 0.6, effort 0.6", "aka": []},
	"calling": {"label": "Calling", "blurb": "Calling across a distance.", "family": "effort", "terms": "rate 0.9, pitch +6st, volume +6dB, push 0.6, effort 0.6", "aka": ["calling out", "hailing"]},
	"shouting": {"label": "Shouting", "blurb": "A shout: eight semitones up, fully pressed, the tilt flat.", "family": "effort", "terms": "rate 0.95, pitch +8st, range 0.8, volume +7dB, push 1, effort 1", "aka": ["shout", "shouted", "yelling", "yell"]},
	"screaming": {"label": "Screaming", "blurb": "A scream: twelve semitones up, strained.", "family": "effort", "terms": "pitch +12st, range 0.7, volume +8dB, push 1, effort 1, breath 0.3", "aka": ["scream", "shrieking"]},
	# -- performance styles
	"storyteller": {"label": "Storyteller", "blurb": "Wide and unhurried, room in the rests.", "family": "style", "terms": "rate 0.95, commas 1.15, ends 1.3, paragraphs 1.6, range 1.5", "aka": ["telling a story"]},
	"bedtime": {"label": "Bedtime", "blurb": "Soft, slow and warm.", "family": "style", "terms": "rate 0.85, commas 1.2, ends 1.4, paragraphs 1.7, pitch -1st, range 1.1, volume -4dB, push -0.3, breath 0.4", "aka": ["bedtime story", "lullaby"]},
	"sports commentator": {"label": "Sports commentator", "blurb": "Fast, high and loud.", "family": "style", "terms": "rate 1.25, commas 0.5, ends 0.6, paragraphs 0.9, hesitations 0.5, pitch +3st, range 1.4, volume +4dB, push 0.4", "aka": ["commentator", "play-by-play"]},
	"game show host": {"label": "Game show host", "blurb": "Bright, swinging and loud.", "family": "style", "terms": "rate 1.1, commas 0.75, ends 0.8, paragraphs 1.2, pitch +3st, range 1.7, volume +4dB, push 0.3", "aka": ["show host"]},
	"ring announcer": {"label": "Ring announcer", "blurb": "Slow, high and swinging as wide as a voice goes.", "family": "style", "terms": "rate 0.8, commas 1.1, ends 1.3, paragraphs 1.5, pitch +4st, range 2, volume +6dB, push 0.6", "aka": ["announcer"]},
	"newsreader": {"label": "Newsreader", "blurb": "Steady and crisp.", "family": "style", "terms": "commas 0.9, ends 1.05, paragraphs 1.2, hesitations 0.3, range 0.9, push 0.1, precision 0.4", "aka": ["news anchor", "newscaster"]},
	"auctioneer": {"label": "Auctioneer", "blurb": "Very fast and nearly flat.", "family": "style", "terms": "rate 1.8, commas 0.25, ends 0.3, paragraphs 0.7, hesitations 0.05, pitch +2st, range 0.4, volume +3dB, push 0.3", "aka": []},
	"orator": {"label": "Orator", "blurb": "Measured, wide and loud.", "family": "style", "terms": "rate 0.9, commas 1.2, ends 1.5, paragraphs 1.8, range 1.4, volume +4dB, push 0.4", "aka": ["preacher", "making a speech"]},
	"drill sergeant": {"label": "Drill sergeant", "blurb": "Loud, pressed and crisp.", "family": "style", "terms": "rate 1.1, pauses 0.8, hesitations 0.05, pitch -1st, range 1.1, volume +7dB, push 0.8, precision 0.5", "aka": []},
	"radio host": {"label": "Radio host", "blurb": "Quick and bright.", "family": "style", "terms": "rate 1.12, pauses 0.8, hesitations 0.5, pitch +2st, range 1.4, volume +2dB, push 0.2", "aka": ["radio dj", "dj"]},
	"campfire": {"label": "Campfire", "blurb": "Slow, low and hushed: a ghost story.", "family": "style", "terms": "rate 0.85, commas 1.25, ends 1.6, paragraphs 1.9, hesitations 1.3, pitch -2st, range 1.2, volume -5dB, breath 0.4", "aka": ["ghost story", "spooky"]},
	"game master": {"label": "Game master", "blurb": "Theatrical: wide, with room in the rests.", "family": "style", "terms": "rate 0.95, commas 1.1, ends 1.3, paragraphs 1.5, range 1.6, volume +1dB", "aka": ["dungeon master"]},
	"mechanical": {"label": "Mechanical", "blurb": "No pitch movement at all.", "family": "style", "terms": "pauses 0.8, hesitations 0.05, range 0.02", "aka": ["robotic", "robot"]},
	# -- physical states
	"out of breath": {"label": "Out of breath", "blurb": "Quick and very breathy.", "family": "state", "terms": "rate 1.1, pitch +1st, breath 0.7", "aka": ["breathless", "panting"]},
	"laughing": {"label": "Laughing", "blurb": "Speaking through a laugh: up, breathy, shaking.", "family": "state", "terms": "rate 1.05, pitch +2st, range 1.4, volume +1dB, breath 0.4, tremor 0.3", "aka": ["giggling"]},
	"crying": {"label": "Crying", "blurb": "Up, breathy and shaking hard.", "family": "state", "terms": "rate 0.85, pauses 1.3, pitch +3st, range 0.8, volume -2dB, breath 0.6, tremor 0.6", "aka": ["sobbing"]},
	"trembling": {"label": "Trembling", "blurb": "A shaking voice.", "family": "state", "terms": "breath 0.2, tremor 0.5", "aka": ["shaky", "shaking", "quavering"]},
	"sleepy": {"label": "Sleepy", "blurb": "Slow, low and slack.", "family": "state", "terms": "rate 0.8, pauses 1.3, hesitations 1.3, pitch -2st, range 0.6, volume -3dB, push -0.4, breath 0.4", "aka": ["drowsy", "yawning"]},
	"straining": {"label": "Straining", "blurb": "Pressed and tense.", "family": "state", "terms": "rate 0.9, pitch +2st, volume +2dB, push 0.8, effort 0.5", "aka": ["strained", "with effort"]},
	"shivering": {"label": "Shivering", "blurb": "Shaking with cold.", "family": "state", "terms": "breath 0.2, tremor 0.4", "aka": ["chattering"]},
	"muffled": {"label": "Muffled", "blurb": "Dulled, as through a hand.", "family": "state", "terms": "volume -2dB, effort -0.8", "aka": []},
}

## Syllables a stretch to its paragraph's end eases in over at its start (never more than EASE_SHARE of it: a one-line
## stretch is mostly itself), and back out over after its end.
const EASE_SYLLABLES := 4.0
const EASE_SHARE := 0.15
const RELEASE_SYLLABLES := 6.0
## The seconds a `drawn` act holds at degree 1 (GAT's `:` is 0.2-0.5 s, a prolongation 0.29-0.34 on average).
const DRAWN_SECONDS := 0.35

## The ARPAbet vowels: what counts a token's syllables.
const VOWELS := ["AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER", "EY", "IH", "IY", "OW", "OY", "UH", "UW"]

const NUMBER_TERM := "^(rate|pauses|commas|ends|paragraphs|hesitations|pitch|range|volume|effort|push|breath|whisper|tremor|precision)\\s*[:=]?\\s*([+-]?[0-9]*\\.?[0-9]+)\\s*(st|db|x|%|s|secs?|seconds)?(?:\\s*(?:\\.\\.|to)\\s*([+-]?[0-9]*\\.?[0-9]+)\\s*(st|db|x|%)?)?$"
## The kinds of rest a delivery lengthens or shortens, each over the voice's own dial ([constant AXES]), and given in seconds
## where a term says them so (`paragraphs 2s`: that rest, whatever the dial says; `pauses 1s` every kind). A rest belongs to
## the word before it.
const RESTS := ["commas", "ends", "paragraphs", "hesitations"]
const DRAWN_TERM := "^(?:drawn|drawn out)\\s+([0-9]*\\.?[0-9]+)\\s*(?:s|secs?|seconds)$"
const BARE_NUMBER := "^(.*?)\\s+([0-9]*\\.?[0-9]+)$"

static var _rows := {}           # a bank row's key -> its parse, made once
static var _names := {}          # every name and synonym -> ["bank" | "act" | "shape", key]
static var _rx := {}


static func _re(pattern: String) -> RegEx:
	if not _rx.has(pattern):
		var r := RegEx.new()
		r.compile(pattern)
		_rx[pattern] = r
	return _rx[pattern]


## Every name a term may be, its synonyms included: `{name: [kind, key]}`.
static func names() -> Dictionary:
	if _names.is_empty():
		for k in BANK:
			_names[k] = ["bank", k]
		for k in ACTS:
			_names[k] = ["act", k]
		for k in SHAPES:
			_names[k] = ["shape", k]
		for table in [[BANK, "bank"], [ACTS, "act"], [SHAPES, "shape"]]:
			for k in table[0]:
				for a in (table[0][k] as Dictionary).get("aka", []):
					if not _names.has(String(a)):
						_names[String(a)] = [table[1], k]
	return _names


## An empty delivery: nothing moved. `aside` names what it read that the note sets aside ([method defs_for]).
static func empty() -> Dictionary:
	return {"axes": {}, "ramps": {}, "acts": [], "shape": "", "emph": 0, "unknown": [], "aside": [], "secs": {}}


## Whether [param d] moves nothing at all.
static func is_empty(d: Dictionary) -> bool:
	return (d["axes"] as Dictionary).is_empty() and (d["ramps"] as Dictionary).is_empty() \
		and (d["acts"] as Array).is_empty() and String(d["shape"]).is_empty() and int(d["emph"]) == 0 \
		and (d.get("secs", {}) as Dictionary).is_empty()


## [param text] (a mark's terms) read: `{axes, ramps, acts, shape, emph, unknown, aside}`, axes in their inner units (a
## multiplier's log), ramps `{axis: {points: [[x, inner]], q}}` (x 0 to 1 along the stretch). [param defs] are the
## deliveries the note says its own way ([method defs_for]: its own names, what it tuned, what it sets aside), each a
## parse, read before the bank's. A word that is none of these is in `unknown`, as written. An act the note draws its own
## way is drawn so wherever it is said, inside another delivery too, and one it sets aside is said nowhere.
static func parse(text: String, defs: Dictionary = {}) -> Dictionary:
	var out := empty()
	for piece in text.to_lower().split(","):
		var term := " ".join(String(piece).strip_edges().split(" ", false))
		if term.is_empty():
			continue
		_add(out, _term(term, defs), 1.0)
	if not defs.is_empty():
		var kept: Array = []
		for act in out["acts"]:
			var own: Variant = defs.get(String(act[0]))
			if not (own is Dictionary):
				kept.append(act)
				continue
			if (own["aside"] as Array).has(String(act[0])):
				continue
			var drawn := _own_act(own, String(act[0]))
			kept.append(act if drawn.size() < 3 or (act as Array).size() >= 3 else [act[0], act[1], drawn[2]])
		out["acts"] = kept
	return out


## Act [param name] as delivery [param d] draws it (`[name, degree, points?]`), [] where it has none.
static func _own_act(d: Dictionary, name: String) -> Array:
	for a in d.get("acts", []):
		if String(a[0]) == name:
			return a
	return []


## One term read, or an empty delivery with the term in `unknown`.
static func _term(term: String, defs: Dictionary) -> Dictionary:
	var out := empty()
	var m := _re(NUMBER_TERM).search(term)
	if m != null and m.get_string(3) in ["s", "sec", "secs", "seconds"]:
		# a rest in seconds: exact, whatever the dial says - a kind of rest, or all of them for `pauses`
		var axis_s := m.get_string(1)
		if not (RESTS.has(axis_s) or axis_s == "pauses") or not m.get_string(4).is_empty():
			(out["unknown"] as Array).append(term)
			return out
		for kind in (RESTS if axis_s == "pauses" else [axis_s]):
			(out["secs"] as Dictionary)[kind] = clampf(float(m.get_string(2)), 0.0, 10.0)
		return out
	if m != null:
		var axis := m.get_string(1)
		var a := _inner(axis, float(m.get_string(2)), m.get_string(3))
		if m.get_string(4).is_empty():
			(out["axes"] as Dictionary)[axis] = a
		else:
			(out["ramps"] as Dictionary)[axis] = {"points": [[0.0, a], [1.0, _inner(axis, float(m.get_string(4)), m.get_string(5))]],
				"q": 2 if axis == "rate" else 0}
		return out
	var dm := _re(DRAWN_TERM).search(term)
	if dm != null:
		(out["acts"] as Array).append(["drawn", float(dm.get_string(1)) / DRAWN_SECONDS])
		return out
	var deg := 1.0
	var name := term
	# words of degree, before and after
	var changed := true
	while changed:
		changed = false
		for w in DEGREES:
			if name.begins_with(String(w) + " "):
				deg *= float(DEGREES[w]["value"])
				name = name.substr(String(w).length() + 1).strip_edges()
				changed = true
			elif name.ends_with(" " + String(w)):
				deg *= float(DEGREES[w]["value"])
				name = name.substr(0, name.length() - String(w).length() - 1).strip_edges()
				changed = true
	var bm := _re(BARE_NUMBER).search(name)
	if bm != null and _known(bm.get_string(1), defs):
		deg *= float(bm.get_string(2))
		name = bm.get_string(1)
	# said again is said more (`faster faster`)
	var parts := name.split(" ", false)
	if parts.size() > 1 and not _known(name, defs):
		var same := true
		for p in parts:
			same = same and p == parts[0]
		if same and _known(parts[0], defs):
			deg *= float(parts.size())
			name = parts[0]
	if defs.has(name):
		_add(out, defs[name], deg)
		return out
	var found: Variant = names().get(name)
	if found == null:
		(out["unknown"] as Array).append(term)
		return out
	# a synonym of a delivery the note says its own way is said that way
	if defs.has(String(found[1])):
		_add(out, defs[String(found[1])], deg)
		return out
	match String(found[0]):
		"bank":
			_add(out, row(String(found[1])), deg)
		"act":
			var key := String(found[1])
			if key == "hit":
				out["emph"] = 1
			elif key == "hit hard":
				out["emph"] = 2
			else:
				(out["acts"] as Array).append([key, deg])
		"shape":
			out["shape"] = String(found[1])
	return out


static func _known(name: String, defs: Dictionary) -> bool:
	return defs.has(name) or names().has(name)


## A bank row's parse, its ramps braking as the row says.
static func row(key: String) -> Dictionary:
	if not _rows.has(key):
		_rows[key] = empty()      # a row naming itself reads as nothing
		var r: Dictionary = BANK[key]
		var d := parse(String(r["terms"]))
		var q := int(r.get("curve", 0))
		if q > 0:
			for axis in d["ramps"]:
				(d["ramps"][axis] as Dictionary)["q"] = q
		_rows[key] = d
	return _rows[key]


## [param value] of [param axis] in its inner units: a multiplier's natural log, else as it is.
static func _inner(axis: String, value: float, unit: String) -> float:
	if unit == "%":
		value = value / 100.0 if axis in ["rate", "pauses", "range"] else value
	if String(AXES[axis]["kind"]) == "mult":
		return log(maxf(value, 0.001))
	return value


## [param from] added into [param into], [param deg] times.
static func _add(into: Dictionary, from: Dictionary, deg: float) -> void:
	for axis in from["axes"]:
		into["axes"][axis] = float(into["axes"].get(axis, 0.0)) + float(from["axes"][axis]) * deg
	for axis in from["ramps"]:
		var r: Dictionary = from["ramps"][axis]
		var pts: Array = []
		for p in r["points"]:
			pts.append([p[0], float(p[1]) * deg])
		into["ramps"][axis] = {"points": pts, "q": int(r.get("q", 0))}
	for act in from["acts"]:
		var a := [String(act[0]), float(act[1]) * deg]
		if (act as Array).size() >= 3:
			a.append(act[2])
		into["acts"].append(a)
	if not String(from["shape"]).is_empty():
		into["shape"] = String(from["shape"])
	into["emph"] = maxi(int(into["emph"]), int(from["emph"]))
	(into["unknown"] as Array).append_array(from["unknown"])
	(into["aside"] as Array).append_array(from.get("aside", []))
	# seconds are exact: said again, the later stands, never scaled by a degree
	var secs: Dictionary = from.get("secs", {})
	for kind in secs:
		into["secs"][kind] = float(secs[kind])


## A ramp of [param axis] at [param x] (0 to 1 along its stretch), in inner units: held before its first point and after its
## last, straight between two - a multiplier given `q` braking between them as Friberg and Sundberg's runner does.
static func ramp_at(axis: String, ramp: Dictionary, x: float) -> float:
	var pts: Array = ramp["points"]
	if pts.is_empty():
		return 0.0
	x = clampf(x, 0.0, 1.0)
	if pts.size() == 1 or x <= float(pts[0][0]):
		return float(pts[0][1])
	var q := int(ramp.get("q", 0))
	for i in range(pts.size() - 1):
		var x0 := float(pts[i][0])
		var x1 := float(pts[i + 1][0])
		if x > x1 and i < pts.size() - 2:
			continue
		var u := clampf((x - x0) / (x1 - x0), 0.0, 1.0) if x1 > x0 else 1.0
		var a := float(pts[i][1])
		var b := float(pts[i + 1][1])
		if q > 0 and String(AXES[axis]["kind"]) == "mult":
			# Friberg & Sundberg: tempo v(x) = [1 + (w^q - 1) x]^(1/q), w the end's tempo over the start's
			var w := exp(b - a)
			return a + log(pow(maxf(1.0 + (pow(w, q) - 1.0) * u, 1e-6), 1.0 / float(q)))
		return a + (b - a) * u
	return float(pts[pts.size() - 1][1])


## The share of a stretch's delivery at [param x] along it, by its shape: [param eased] (a stretch to its
## paragraph's end, [param total] syllables long) eases in over its first [constant EASE_SYLLABLES] (at [param at],
## syllables into it), or [constant EASE_SHARE] of it where that is fewer.
static func share(shape: String, x: float, at: float, eased: bool, total := 1e9) -> float:
	match shape:
		"building":
			return smoothstep(0.0, 1.0, x)
		"fading":
			return smoothstep(0.0, 1.0, 1.0 - x)
		"swelling":
			return smoothstep(0.0, 1.0, x / 0.6) if x < 0.6 else smoothstep(0.0, 1.0, (1.0 - x) / 0.4)
		"sudden":
			return 1.0
	return smoothstep(0.0, 1.0, at / clampf(total * EASE_SHARE, 0.5, EASE_SYLLABLES)) if eased else 1.0


## The syllables a token says (at least one): its ARPAbet's vowels.
static func syllables(tok: Dictionary) -> float:
	var n := 0
	for p in tok.get("fallback", []):
		if String(p).rstrip("012") in VOWELS:
			n += 1
	return float(maxi(1, n))


## A passage's stretches laid over its tokens: each token of [param tokens] (in order, each with `_dv`, the stretches
## it is in by sentinel id, and `_dvn`, those it opens) given its axis values (`x`, the host's units), its acts
## (`acts`, `[name, degree]`) and its stress (`emph`), and `_dv` and `_dvn` taken off. [param spans] are the
## passage's stretches in the order they open: `{id, d (a parse), closed}`.
static func resolve(tokens: Array, spans: Array) -> void:
	var queue := {}               # id -> the stretches with that id still to open, in order
	for i in spans.size():
		var id := int((spans[i] as Dictionary)["id"])
		if not queue.has(id):
			queue[id] = []
		(queue[id] as Array).append(i)
	var live := {}                # id -> the stretch now open under it
	var members := {}             # stretch -> [token index]
	for ti in tokens.size():
		var t: Dictionary = tokens[ti]
		for id in t.get("_dvn", []):
			if queue.has(int(id)) and not (queue[int(id)] as Array).is_empty():
				live[int(id)] = (queue[int(id)] as Array).pop_front()
		for id in t.get("_dv", []):
			if live.has(int(id)):
				var s := int(live[int(id)])
				if not members.has(s):
					members[s] = []
				(members[s] as Array).append(ti)
		t.erase("_dv")
		t.erase("_dvn")
	if members.is_empty():
		return
	var syl: Array = []
	for t in tokens:
		syl.append(syllables(t))
	var sum := []                 # per token: {axis: inner}
	var acts := []
	var emph := []
	var secs := []                # per token: {rest kind: seconds}, exact over a stretch
	for _t in tokens:
		sum.append({})
		acts.append([])
		emph.append(0)
		secs.append({})
	for s in members:
		var span: Dictionary = spans[int(s)]
		var d: Dictionary = span["d"]
		var idx: Array = members[s]
		var eased := not bool(span["closed"])
		var total := 0.0
		for k in idx:
			total += float(syl[int(k)])
		var at := 0.0
		for k in idx:
			var mid := at + float(syl[int(k)]) * 0.5
			var x := mid / maxf(total, 1e-6)
			var w := share(String(d["shape"]), x, mid, eased, total)
			var own: Dictionary = sum[int(k)]
			for axis in d["axes"]:
				own[axis] = float(own.get(axis, 0.0)) + float(d["axes"][axis]) * w
			for axis in d["ramps"]:
				own[axis] = float(own.get(axis, 0.0)) + ramp_at(axis, d["ramps"][axis], x) * (w if eased and String(d["shape"]).is_empty() else 1.0)
			if int(d["emph"]) > 0:
				emph[int(k)] = maxi(int(emph[int(k)]), int(d["emph"]))
			(secs[int(k)] as Dictionary).merge(d.get("secs", {}), true)
			at += float(syl[int(k)])
		# a word's acts: on the stretch's last word, or on every word for those that say so
		var last := int(idx[idx.size() - 1])
		for act in d["acts"]:
			if bool(Registry.field(ACTS, String(act[0]), "every", false)):
				for k in idx:
					(acts[int(k)] as Array).append(act)
			else:
				(acts[last] as Array).append(act)
		# ...and a stretch to its paragraph's end lets go over the syllables after it, as it came in
		if eased and String(d["shape"]) != "sudden":
			var held: Dictionary = {}
			for axis in d["axes"]:
				held[axis] = float(d["axes"][axis])
			for axis in d["ramps"]:
				held[axis] = ramp_at(axis, d["ramps"][axis], 1.0)
			if String(d["shape"]) == "fading":
				held.clear()
			var after := 0.0
			for k in range(last + 1, tokens.size()):
				var mid := after + float(syl[k]) * 0.5
				if mid >= RELEASE_SYLLABLES:
					break
				var w := 1.0 - smoothstep(0.0, 1.0, mid / RELEASE_SYLLABLES)
				for axis in held:
					sum[k][axis] = float(sum[k].get(axis, 0.0)) + float(held[axis]) * w
				after += float(syl[k])
	for ti in tokens.size():
		var t: Dictionary = tokens[ti]
		var x := outer(sum[ti])
		for kind in secs[ti]:
			x[String(kind) + "_s"] = snappedf(float(secs[ti][kind]), 0.001)
		if not x.is_empty():
			t["x"] = x
		if not (acts[ti] as Array).is_empty():
			t["acts"] = acts[ti]
		if int(emph[ti]) > 0:
			t["emph"] = maxi(int(t.get("emph", 0)), int(emph[ti]))


## Axis values in inner units as the voice host reads them: each clamped to its limits, a multiplier as itself, and
## only those that move.
static func outer(inner: Dictionary) -> Dictionary:
	var out := {}
	for axis in inner:
		var row_: Dictionary = AXES[axis]
		var v := float(inner[axis])
		if String(row_["kind"]) == "mult":
			v = clampf(exp(v), float(row_["lo"]), float(row_["hi"]))
			if absf(v - 1.0) > 0.002:
				out[axis] = snappedf(v, 0.001)
		else:
			v = clampf(v, float(row_["lo"]), float(row_["hi"]))
			if absf(v) > 0.002:
				out[axis] = snappedf(v, 0.001)
	return out


## The pause multiplier a token carries (`x.pauses`), 1 where it has none.
static func pauses_of(tok: Dictionary) -> float:
	var x: Variant = tok.get("x")
	return float((x as Dictionary).get("pauses", 1.0)) if x is Dictionary else 1.0


## The rest of kind [param kind] ([constant RESTS]) after token [param tok], [param base] seconds as the voice's dial makes it:
## the seconds its delivery gives that kind (`<kind>_s`), else [param base] times its `pauses` and its own multiplier for the kind.
static func rest_of(tok: Dictionary, kind: String, base: float) -> float:
	var x: Dictionary = tok.get("x", {}) if tok.get("x") is Dictionary else {}
	if x.has(kind + "_s"):
		return float(x[kind + "_s"])
	return base * float(x.get("pauses", 1.0)) * float(x.get(kind, 1.0))


# --- a delivery as its Lab shows it, and as a note or the library keeps it -------------------------------------------------


## Every name a delivery may be kept or tuned under in a note ([method defs_for]): a bank row's or an act's ("drawn"); a note's
## own new one is any other name of words alone.
static func is_named(name: String) -> bool:
	return BANK.has(name) or ACTS.has(name)


## What [param name] says now, for its Lab and a note's list: the bank row's or the act's blurb, "" for a name of the note's own.
static func blurb_of(name: String) -> String:
	if BANK.has(name):
		return String(BANK[name]["blurb"])
	if ACTS.has(name):
		return String(ACTS[name]["blurb"])
	return ""


## A delivery as its Lab shows it and a note or the library keeps it, every number in its axis's own units ([constant AXES]'
## `unit`: a multiplier as itself, semitones, dB): `{axes: {axis: [[x, value]]}, brake: {axis: q}, shape, acts: {act: degree},
## contours: {act: [[at, semitones]]}, emph}`. An axis of one point holds its value over the stretch, eased in and out as
## the stretch is; of more, it moves through them from the stretch's start (x 0) to its end (x 1), straight between two, a
## multiplier given a `brake` braking between them ([method ramp_at]). An act's contour is the pitch it draws over its word at
## degree 1 (its row's `contour` where the spec has none). [param terms] read as a mark reads them ([method parse]).
static func spec_of(terms: String, defs: Dictionary = {}) -> Dictionary:
	return spec_from(parse(terms, defs))


## Bank row or act [param name] as a spec ([method spec_of]): a row's terms, an act said once. {} for neither.
static func spec_of_name(name: String) -> Dictionary:
	if BANK.has(name):
		return spec_from(row(name))
	if ACTS.has(name):
		return spec_of(name)
	return {}


## A parse ([method parse]) as a spec ([method spec_of]).
static func spec_from(d: Dictionary) -> Dictionary:
	var axes := {}
	var brake := {}
	for axis in d["axes"]:
		axes[axis] = [[0.0, _shown(axis, float(d["axes"][axis]))]]
	for axis in d["ramps"]:
		var r: Dictionary = d["ramps"][axis]
		var pts: Array = []
		var held: Array = axes.get(axis, [])
		var under := float(held[0][1]) if not held.is_empty() else (1.0 if _mult(axis) else 0.0)
		for p in r["points"]:
			var v := float(p[1]) + (log(under) if _mult(axis) else under) if not held.is_empty() else float(p[1])
			pts.append([float(p[0]), _shown(axis, v)])
		axes[axis] = pts
		if int(r.get("q", 0)) > 0:
			brake[axis] = int(r["q"])
	var acts := {}
	var contours := {}
	for a in d["acts"]:
		acts[String(a[0])] = snappedf(float(a[1]), 0.001)
		if (a as Array).size() >= 3:
			contours[String(a[0])] = (a[2] as Array).duplicate(true)
	var out := {"axes": axes, "brake": brake, "shape": String(d["shape"]), "acts": acts, "contours": contours, "emph": int(d["emph"])}
	if not (d.get("secs", {}) as Dictionary).is_empty():
		out["secs"] = (d["secs"] as Dictionary).duplicate()
	return out


## A spec ([method spec_of]) as a parse, ready to be laid over words ([method resolve]): what it cannot say (an axis or an act
## no row knows) left out, every value held to its axis's limits.
static func from_spec(spec: Dictionary) -> Dictionary:
	var out := empty()
	var axes: Dictionary = spec.get("axes", {}) if spec.get("axes") is Dictionary else {}
	var brake: Dictionary = spec.get("brake", {}) if spec.get("brake") is Dictionary else {}
	for axis in axes:
		if not AXES.has(String(axis)) or not (axes[axis] is Array):
			continue
		var pts: Array = []
		for p in axes[axis]:
			if p is Array and (p as Array).size() >= 2:
				pts.append([clampf(float(p[0]), 0.0, 1.0), _inner(String(axis), _held(String(axis), float(p[1])), "")])
		pts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		if pts.size() == 1:
			out["axes"][String(axis)] = float(pts[0][1])
		elif pts.size() > 1:
			out["ramps"][String(axis)] = {"points": pts, "q": int(brake.get(axis, 0))}
	var contours: Dictionary = spec.get("contours", {}) if spec.get("contours") is Dictionary else {}
	var acts: Dictionary = spec.get("acts", {}) if spec.get("acts") is Dictionary else {}
	for name in acts:
		if not ACTS.has(String(name)):
			continue
		var key := String(name)
		if key == "hit" or key == "hit hard":
			out["emph"] = maxi(int(out["emph"]), 1 if key == "hit" else 2)
			continue
		var a := [key, clampf(float(acts[name]), 0.0, 4.0)]
		if contours.get(key) is Array and not (contours[key] as Array).is_empty():
			a.append(_contour_clean(contours[key]))
		out["acts"].append(a)
	if SHAPES.has(String(spec.get("shape", ""))):
		out["shape"] = String(spec["shape"])
	var secs: Dictionary = spec.get("secs", {}) if spec.get("secs") is Dictionary else {}
	for kind in secs:
		if RESTS.has(String(kind)) and typeof(secs[kind]) in [TYPE_INT, TYPE_FLOAT]:
			out["secs"][String(kind)] = clampf(float(secs[kind]), 0.0, 10.0)
	out["emph"] = maxi(int(out["emph"]), clampi(int(spec.get("emph", 0)), 0, 2))
	return out


## A contour's points as the host takes them: each `[at, semitones]`, `at` held to 0-1 or one of the anchors, in order.
static func _contour_clean(points: Array) -> Array:
	var out: Array = []
	for p in points:
		if not (p is Array) or (p as Array).size() < 2:
			continue
		var at: Variant = p[0]
		if at is String and String(at) in ["stress<", "stress", "stress>"]:
			out.append([String(at), clampf(float(p[1]), -12.0, 12.0)])
		elif typeof(at) in [TYPE_INT, TYPE_FLOAT]:
			out.append([clampf(float(at), 0.0, 1.0), clampf(float(p[1]), -12.0, 12.0)])
	return out


## The default contour an act draws (its row's), [] for an act that draws none.
static func contour_of(act: String) -> Array:
	return (Registry.field(ACTS, act, "contour", []) as Array).duplicate(true)


## Spec [param spec] in a few words, as a list shows it: each axis it moves (where it ends, for one that moves), its shape and its
## acts ("rate 1.15x · pitch +2 → +4 st · building · drawn"). "" for one that moves nothing.
static func line_of(spec: Dictionary) -> String:
	var parts := PackedStringArray()
	var axes: Dictionary = spec.get("axes", {}) if spec.get("axes") is Dictionary else {}
	for axis in AXES:
		if not (axes.get(axis) is Array) or (axes[axis] as Array).is_empty():
			continue
		var pts: Array = axes[axis]
		var unit := String(AXES[axis]["unit"])
		var f := func(v: float) -> String:
			var t := ("%.2f" % v).trim_suffix("0").trim_suffix("0").trim_suffix(".")
			return (t + unit) if unit == "x" else (("+" if v > 0.0 and unit != "" else "") + t + (" " + unit if not unit.is_empty() else ""))
		if pts.size() == 1:
			parts.append("%s %s" % [axis, f.call(float(pts[0][1]))])
		else:
			parts.append("%s %s → %s" % [axis, f.call(float(pts[0][1])), f.call(float(pts[pts.size() - 1][1]))])
	if not String(spec.get("shape", "")).is_empty():
		parts.append(String(spec["shape"]))
	var acts: Dictionary = spec.get("acts", {}) if spec.get("acts") is Dictionary else {}
	for a in acts:
		parts.append(String(a) if is_equal_approx(float(acts[a]), 1.0) else "%s %.2g" % [a, float(acts[a])])
	if int(spec.get("emph", 0)) > 0:
		parts.append("hit" if int(spec["emph"]) == 1 else "hit hard")
	var secs: Dictionary = spec.get("secs", {}) if spec.get("secs") is Dictionary else {}
	for kind in secs:
		parts.append("%s %.2g s" % [kind, float(secs[kind])])
	return "  ·  ".join(parts)


## Whether [param axis] is a multiplier.
static func _mult(axis: String) -> bool:
	return String(AXES[axis]["kind"]) == "mult"


## [param inner] of [param axis] in its own units, as a spec shows it.
static func _shown(axis: String, inner: float) -> float:
	return snappedf(exp(inner) if _mult(axis) else inner, 0.001)


## [param v] of [param axis] held to its limits.
static func _held(axis: String, v: float) -> float:
	return clampf(v, float(AXES[axis]["lo"]), float(AXES[axis]["hi"]))


## What a note says of its deliveries, as parses a mark reads before the bank's ([method parse]): [param tuning] is `{tuned:
## {name: spec}, strength: {name: k}, off: [name]}` - a delivery tuned (the note's own, or kept in the library), one said
## stronger or weaker (its degree times k), and one set aside (said, it moves nothing and is named in `aside`).
static func defs_for(tuning: Dictionary) -> Dictionary:
	var defs := {}
	var tuned: Dictionary = tuning.get("tuned", {}) if tuning.get("tuned") is Dictionary else {}
	for name in tuned:
		if tuned[name] is Dictionary:
			defs[String(name)] = from_spec(tuned[name])
	var strength: Dictionary = tuning.get("strength", {}) if tuning.get("strength") is Dictionary else {}
	for name in strength:
		var k := float(strength[name])
		if is_equal_approx(k, 1.0):
			continue
		var base: Dictionary = defs.get(String(name), {})
		if base.is_empty():
			if BANK.has(String(name)):
				base = row(String(name))
			elif ACTS.has(String(name)):
				base = parse(String(name))
			else:
				continue
		var d := empty()
		_add(d, base, k)
		defs[String(name)] = d
	for name in (tuning.get("off", []) if tuning.get("off") is Array else []):
		var d := empty()
		(d["aside"] as Array).append(String(name))
		defs[String(name)] = d
	return defs


## The names a mark of [param text] says, as written and found ([method parse]'s words, each found as a bank row, an act or a
## name in [param own]): what a note's list of deliveries shows ([DeliverySection]). A degree, a number or an axis says none.
static func names_in(text: String, own: Dictionary = {}) -> PackedStringArray:
	var out := PackedStringArray()
	for piece in text.to_lower().split(","):
		var term := " ".join(String(piece).strip_edges().split(" ", false))
		if term.is_empty() or _re(NUMBER_TERM).search(term) != null:
			continue
		if _re(DRAWN_TERM).search(term) != null:
			if not out.has("drawn"):
				out.append("drawn")
			continue
		var name := term
		var changed := true
		while changed:
			changed = false
			for w in DEGREES:
				if name.begins_with(String(w) + " "):
					name = name.substr(String(w).length() + 1).strip_edges()
					changed = true
				elif name.ends_with(" " + String(w)):
					name = name.substr(0, name.length() - String(w).length() - 1).strip_edges()
					changed = true
		var bm := _re(BARE_NUMBER).search(name)
		if bm != null:
			name = bm.get_string(1)
		var key := name
		if not own.has(name):
			var found: Variant = names().get(name)
			if found == null or String(found[0]) == "shape":
				continue
			key = String(found[1])
		if not out.has(key):
			out.append(key)
	return out


## What the terms [param terms] of a mark do, term by term, as an agent checking a line before it writes it is told: each
## term's moves ([method line_of]) and what it is, each word no delivery knows, and each one [param off] sets aside.
static func explained(terms: String, off: Array = []) -> String:
	var lines := PackedStringArray()
	for piece in terms.to_lower().split(","):
		var term := " ".join(String(piece).strip_edges().split(" ", false))
		if term.is_empty():
			continue
		var names_ := names_in(term)
		if not names_.is_empty() and off.has(names_[0]):
			lines.append("%s: set aside here - do not write it" % term)
			continue
		var d := parse(term)
		if not (d["unknown"] as Array).is_empty():
			lines.append("%s: no delivery knows it - use the bank's words" % term)
			continue
		var what := line_of(spec_from(d))
		var about := blurb_of(names_[0]) if not names_.is_empty() else ""
		if SHAPES.has(term) or names().get(term, ["", ""])[0] == "shape":
			what = "a shape over the stretch"
			about = String(SHAPES[String(names()[term][1])]["blurb"])
		lines.append("%s: %s%s" % [term, what if not what.is_empty() else "moves nothing", (" (%s)" % about) if not about.is_empty() else ""])
	return "\n".join(lines) if not lines.is_empty() else "No terms."


## The bank's names by family, for what tells an agent which words it may use: one line a family - and, from what a note says of its
## deliveries ([param tuning], [method defs_for]; `about` each own name's words), those it set aside left out, its own names and
## those kept in the library listed with what each is.
static func listed(tuning: Dictionary = {}) -> String:
	var off: Array = tuning.get("off", []) if tuning.get("off") is Array else []
	var lines := PackedStringArray()
	for fam in FAMILIES:
		var keys := PackedStringArray()
		for k in BANK:
			if String(BANK[k]["family"]) == fam and not off.has(k):
				keys.append(String(k))
		if not keys.is_empty():
			lines.append("%s: %s" % [String(FAMILIES[fam]["label"]), ", ".join(keys)])
	var acts_ := PackedStringArray()
	for k in ACTS:
		if not off.has(k):
			acts_.append("%s (%s)" % [k, String(ACTS[k]["told"])])
	lines.append("On a word: %s" % ", ".join(acts_))
	var shapes_ := PackedStringArray()
	for k in SHAPES:
		shapes_.append(String(k))
	lines.append("Over a stretch: %s" % ", ".join(shapes_))
	lines.append("Rests, as a word with a number after it: commas (inside a sentence), ends (after a sentence), paragraphs (after "
		+ "a paragraph), hesitations (the hesitation marks inside it) - each times the voice's own, so ends 1.5 is half again as "
		+ "long, commas 0.6 shorter, hesitations 0 none; pauses scales all four. Exact seconds only for a silence you need "
		+ "exactly: paragraphs 2s.")
	lines.append("Any axis takes a number the same way: rate 1.2, pitch +2st, volume -4dB.")
	var about: Dictionary = tuning.get("about", {}) if tuning.get("about") is Dictionary else {}
	var own := PackedStringArray()
	for name in about:
		if not is_named(String(name)) and not off.has(name):
			own.append("%s (%s)" % [name, String(about[name])] if not String(about[name]).is_empty() else String(name))
	if not own.is_empty():
		lines.append("Made for this show or kept in its library: %s" % ", ".join(own))
	if not off.is_empty():
		var names_ := PackedStringArray()
		for n in off:
			names_.append(String(n))
		lines.append("Set aside here, never to be written: %s" % ", ".join(names_))
	return "\n".join(lines)
