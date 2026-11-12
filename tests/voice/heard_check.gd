extends SceneTree

## Gate for A voice heard through something ([constant Manuscript.HEARD], [constant VoiceFX.HEARD]; next/dispatch.md,
## the user's dispatch desk: every voice but the room's "comes through a phone"):
##
## - THE BAND: through a phone a 100 Hz tone (a man's fundamental) is taken far down and a 1 kHz tone passes; a phone
##   lying on the desk is quieter than one at the ear, and a voice through somebody else's phone quieter still;
## - THE CONTROL: heard through nothing, a chain gives back exactly what one that never heard of phones gives;
## - THE PLAN: a turn marked `<!-- heard: phone -->` has every chunk heard through it, the turn before it none, and a
##   key nobody knows is a note and nothing more; the mark is never said;
## - THE JOIN: a voice heard through one thing, then another, is a change of room each time - a mark where it changes;
## - the static rides the voice: over a radio, static is heard in the gap between two words and not before the voice
##   begins, the squelch's tail is heard as the channel closes, and the rest after it is clean (THE CONTROL: heard through
##   nothing, the gap is silent); a phone's line hisses there too, far under a radio's; the same take is the same
##   static, sample for sample.
##
## Run: godot --headless --path . --script tests/voice/heard_check.gd

const SR := 22050
## A voice's settings as a cast's slot holds them ([constant ReadingPanel.SLOT_DEFAULTS], written out: that panel names autoloads).
const SLOT := {"voice": "", "speaker": 0, "tone": 0, "pace": 1.0, "pause": 1.0, "dynamics": 0.5, "arc": 0.4, "effort": 0.35,
	"echo": 0.0, "room": 0.0, "resonance": 0.0, "presence": 1.0, "ambience": 0.0, "lean": 0.0, "near": 0.0, "seat": 0.0, "ink": ""}

var _fails: Array = []


func _init() -> void:
	_band()
	_static()
	_plan_and_join()
	if _fails.is_empty():
		print("heard_check: ALL OK")
		quit(0)
	else:
		for f in _fails:
			print("heard_check: FAIL  " + f)
		quit(1)


func _band() -> void:
	var low := _tone(100.0, 0.05)
	var mid := _tone(1000.0, 0.05)
	# each tone's own amplitude, read at its frequency: the line's hiss is not the band
	var phone_low := _at(_through("phone", low), 100.0)
	var phone_mid := _at(_through("phone", mid), 1000.0)
	var desk_mid := _at(_through("desk", mid), 1000.0)
	var far_mid := _at(_through("far", mid), 1000.0)
	var in_low := _at(low, 100.0)
	var in_mid := _at(mid, 1000.0)
	var drop_low := 20.0 * log(phone_low / in_low) / log(10.0)
	var drop_mid := 20.0 * log(phone_mid / in_mid) / log(10.0)
	_ok(drop_low < -18.0, "through a phone a 100 Hz tone is taken far down (%.1f dB)" % drop_low)
	_ok(drop_mid > -2.0, "through a phone a 1 kHz tone passes (%.1f dB)" % drop_mid)
	_ok(desk_mid < phone_mid * 0.6, "a phone on the desk is quieter than one at the ear (%.4f against %.4f)" % [desk_mid, phone_mid])
	_ok(far_mid < desk_mid, "a voice through somebody else's phone is quieter still (%.4f against %.4f)" % [far_mid, desk_mid])
	# THE CONTROL: heard through nothing is the chain as it was, sample for sample
	var plain := _through("", mid)
	var never := VoiceFX.new()
	never.sample_rate = SR
	never.setup(SR)
	var was := never.process(mid.duplicate())
	var same := plain.size() == was.size()
	for i in mini(plain.size(), was.size()):
		if plain[i] != was[i]:
			same = false
			break
	_ok(same, "the control: heard through nothing, the chain gives back what it always did")
	print("heard_check: 100 Hz %.1f dB, 1 kHz %.1f dB through a phone; 1 kHz at %.4f / %.4f / %.4f (phone, desk, far)"
		% [drop_low, drop_mid, phone_mid, desk_mid, far_mid])


func _static() -> void:
	# a word, a gap inside a sentence, a word, then a long rest
	var w := _tone(700.0, 0.12, 0.25)
	var buf := PackedFloat32Array()
	buf.resize(int(0.4 * SR))
	buf.append_array(w)
	var gap := PackedFloat32Array()
	gap.resize(int(0.15 * SR))
	buf.append_array(gap)
	buf.append_array(w)
	var end := buf.size()
	var rest := PackedFloat32Array()
	rest.resize(int(1.5 * SR))
	buf.append_array(rest)
	var radio := _through("radio", buf)
	var phone := _through("phone", buf)
	var room := _through("", buf)
	var g0 := int(0.4 * SR) + w.size() + int(0.04 * SR)
	var g1 := int(0.4 * SR) + w.size() + int(0.13 * SR)
	var hold := int(VoiceFX.STATIC_HOLD * SR)
	var radio_gap := _rms_in(radio, g0, g1)
	_ok(radio_gap > 0.004, "over a radio, static is heard between two words (%.4f)" % radio_gap)
	_ok(_rms_in(room, g0, g1) < 1e-4, "the control: heard through nothing, the gap is silent (%.5f)" % _rms_in(room, g0, g1))
	_ok(_rms_in(radio, 0, int(0.35 * SR)) < 1e-4, "no static before the voice begins (%.5f)" % _rms_in(radio, 0, int(0.35 * SR)))
	var tail := _rms_in(radio, end + hold + int(0.01 * SR), end + hold + int(0.08 * SR))
	_ok(tail > radio_gap * 1.2, "the squelch's tail is heard as the channel closes (%.4f against %.4f)" % [tail, radio_gap])
	var after := end + hold + int((VoiceFX.STATIC_TAIL + 0.15) * SR)
	_ok(_rms_in(radio, after, after + int(0.5 * SR)) < 1e-4, "the rest after it is clean (%.5f)" % _rms_in(radio, after, after + int(0.5 * SR)))
	var phone_gap := _rms_in(phone, g0, g1)
	_ok(phone_gap > 1e-4 and phone_gap < radio_gap * 0.3, "a phone's line hisses there too, far under a radio's (%.4f against %.4f)" % [phone_gap, radio_gap])
	var again := _through("radio", buf)
	var same := again.size() == radio.size()
	for i in mini(again.size(), radio.size()):
		if again[i] != radio[i]:
			same = false
			break
	_ok(same, "the same take is the same static, sample for sample")
	print("heard_check: static between words %.4f (radio), %.4f (phone); the squelch's tail %.4f" % [radio_gap, phone_gap, tail])


static func _rms_in(buf: PackedFloat32Array, a: int, b: int) -> float:
	var s := 0.0
	var n := 0
	for i in range(maxi(0, a), mini(b, buf.size())):
		s += buf[i] * buf[i]
		n += 1
	return sqrt(s / maxf(1.0, float(n)))


func _plan_and_join() -> void:
	var script := ("<!-- speaker: Control -->\n\nHe is at the store.\n\n<!-- speaker: Aisle -->\n<!-- heard: phone -->\n\n"
		+ "Which store? The big one.\n\n<!-- speaker: Van -->\n<!-- heard: desk -->\n\nThe door will not open.\n\n"
		+ "<!-- speaker: Cough -->\n<!-- heard: tincan -->\n\nI am sick.\n")
	var plan := ReadingPlan.make(script, "", {"reader": "Control", "hesitate": true, "bare": 1.5, "outro": 0.0})
	var by := {}
	var said := PackedStringArray()
	for c in plan["chunks"]:
		var ch: Dictionary = c
		var who := String(ch["speaker"])
		if not by.has(who):
			by[who] = []
		(by[who] as Array).append(String(ch.get("heard", "")))
		for w in ch.get("words", []):
			said.append(String((w as Dictionary).get("text", "")).to_lower())
	_ok(by.get("Control", []) == [""], "the room's turn is heard in the room (%s)" % str(by.get("Control")))
	_ok(by.get("Aisle", []) == ["phone", "phone"], "every chunk of a turn marked phone is heard through one (%s)" % str(by.get("Aisle")))
	_ok(by.get("Van", []) == ["desk"], "a turn marked desk is heard from the desk (%s)" % str(by.get("Van")))
	_ok(by.get("Cough", []) == [""], "the control: a key nobody knows is a note, heard in the room (%s)" % str(by.get("Cough")))
	_ok(not "heard" in " ".join(said) and not "phone" in " ".join(said), "the mark is never said (%s)" % " ".join(said))
	# THE JOIN: a change of what a voice is heard through is a change of room
	var join := ReadingJoin.new(SR)
	var chunks: Array = plan["chunks"]
	for i in chunks.size():
		join.add(chunks, i, _tone(220.0, 0.05, 0.4), [], SLOT, 0.0)
	var heard: Array = []
	for m in join.marks:
		if (m as Dictionary).has("speaker"):
			heard.append("%s:%s" % [String(m["speaker"]), String(m.get("heard", ""))])
	_ok(heard == ["Control:", "Aisle:phone", "Van:desk", "Cough:"],
		"the join marks each change of voice with what it is heard through (%s)" % str(heard))


func _through(key: String, buf: PackedFloat32Array) -> PackedFloat32Array:
	var fx := VoiceFX.new()
	fx.sample_rate = SR
	fx.setup(SR)
	fx.heard = key
	return fx.process(buf.duplicate())


static func _tone(hz: float, amp: float, secs := 1.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(secs * SR))
	for i in out.size():
		out[i] = amp * sin(TAU * hz * float(i) / SR)
	return out


## The amplitude of [param hz] in [param buf] past the first tenth of a second (where a filter is still ringing up): its
## projection on a sine and a cosine there, so noise at other frequencies averages away.
static func _at(buf: PackedFloat32Array, hz: float) -> float:
	var c := 0.0
	var q := 0.0
	var n := 0
	for i in range(int(0.1 * SR), buf.size()):
		var ph := TAU * hz * float(i) / SR
		c += buf[i] * cos(ph)
		q += buf[i] * sin(ph)
		n += 1
	return 2.0 * sqrt(c * c + q * q) / maxf(1.0, float(n))


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
