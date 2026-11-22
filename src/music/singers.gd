extends RefCounted
class_name Singers

## Singers - who a composed Sound's voices may be (next/music.md, "The chorus"): the voices kept in the library that can
## sing - a Kokoro voice or the formant voice ([FormantSinging]) designed on any note's Voice card and kept: its reader,
## blend or bred voice, its Tone, and how it sings ([constant VoiceLibrary.SINGING]) - and Kokoro's own readers. The Sound
## card hands the kept ones to the composer ([method kept], `voices` in its context; the composer reads no library). A
## singer a part names is `{kept: name}` or a reader `{voice, speaker, name}`.
##
## WHERE A VOICE SITS: a Kokoro woman's around F_CENTER, a man's around M_CENTER, its Tone's shift moving it (a larger
## voice sits lower); a formant voice [constant ABOVE_SPEAKING] over the pitch it speaks at - what a melody is moved by
## octaves to be nearest, and what a chorus's roles are matched against.

const F_CENTER := 66
const M_CENTER := 55
## How far over the pitch a formant voice speaks at it sits singing (semitones): a voice speaking at a man's 120 Hz sits
## near M_CENTER, at a woman's 220 Hz near F_CENTER.
const ABOVE_SPEAKING := 8
## The models a kept voice may sing in.
const MODELS := ["kokoro", FormantVoice.ID]


## Whether kept voice [param v] can sing.
static func sings(v: Dictionary) -> bool:
	var model := String(v.get("voice", ""))
	for m in MODELS:
		if model.begins_with(String(m)):
			return true
	return false


## Every kept voice that can sing, by name ([method summary]).
static func kept() -> Dictionary:
	var out := {}
	for e in VoiceLibrary.entries():
		var v: Dictionary = (e as Dictionary).get("voice", {})
		if sings(v):
			out[String(e["name"])] = summary(v)
	return out


## Kept voice [param v] as a singer: `{voice, speaker, blend, tone, semis, center, vibrato, vibrato_rate, drift}`, and a
## formant voice's `formant`.
static func summary(v: Dictionary) -> Dictionary:
	var semis := Delivery.tone_semis(int(v.get("tone", 0)))
	var out := {"voice": String(v.get("voice", "kokoro")), "speaker": int(v.get("speaker", 0)), "blend": String(v.get("blend", "")),
		"tone": int(v.get("tone", 0)), "semis": semis,
		"center": (M_CENTER if Delivery.sings_low(v) else F_CENTER) + int(roundf(semis))}
	if String(out["voice"]) == FormantVoice.ID:
		out["formant"] = v.get("formant", {}) if v.get("formant") is Dictionary else {}
		out["center"] = formant_center(out["formant"])
	for k in VoiceLibrary.SINGING:
		out[k] = float(v.get(k, VoiceLibrary.DEFAULTS[k]))
	return out


## Where formant voice [param formant] ([method FormantVoice.voice_of]'s shape, as kept) sits: [constant ABOVE_SPEAKING]
## over the pitch it speaks at.
static func formant_center(formant: Dictionary) -> int:
	var hz := FormantVoice.spec_of(FormantVoice.voice_of(formant)).f0_base * 1.06
	return int(roundf(69.0 + 12.0 * log(hz / 440.0) / log(2.0))) + ABOVE_SPEAKING


## Where singer [param singer] sits ([member F_CENTER], [member M_CENTER]), a kept one by [param voices] ([method kept]).
static func center_of(singer: Dictionary, voices: Dictionary) -> int:
	var name := String(singer.get("kept", ""))
	if not name.is_empty() and voices.has(name):
		return int((voices[name] as Dictionary)["center"])
	var reader := String(singer.get("name", ""))
	if reader.length() >= 2 and reader[1] in ["f", "m"]:
		return M_CENTER if reader[1] == "m" else F_CENTER
	return M_CENTER if Delivery.sings_low(singer) else F_CENTER


## A singer's name as the card shows it.
static func name_of(singer: Dictionary) -> String:
	return String(singer.get("kept", singer.get("name", "a voice")))
