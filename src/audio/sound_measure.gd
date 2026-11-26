extends RefCounted
class_name SoundMeasure

## SoundMeasure - what a stretch of sound is like, as numbers an agent reads instead of listening ([EnvironmentSoundTools]): its
## loudness over time and how much it swings, how bright it is, how its power is shared between the low, the middle and the high,
## which side it leans to, and how many sudden rises it has (a drop, a crackle, a chirp, a slap). Pure and plain arithmetic over the
## samples, one pass, so a worker runs it ([method measure]); [method text] says it in lines.
##
## Brightness is the power-weighted typical frequency of a frame, read from how fast the wave moves against how big it is (a sine's
## own pitch exactly; white noise a quarter of the rate): a darker sound reads lower, a hissing one higher.

## The frames loudness, brightness and events are told by (seconds).
const FRAME := 0.5
## Where the low ends and the high begins (Hz): one-pole splits, gentle as an ear's bands are.
const LOW := 250.0
const HIGH := 4000.0
## An event: the loudness over a short window (seconds) this many dB above the window's mean over the moment before it (seconds),
## louder than [constant EVENT_FLOOR] dB, and at least [constant EVENT_GAP] seconds after the last.
const EVENT_WINDOW := 0.005
const EVENT_BEFORE := 0.1
const EVENT_DB := 6.0
const EVENT_FLOOR := -70.0
const EVENT_GAP := 0.03
## The quietest a frame is told as (dB): silence.
const SILENT := -120.0


## Samples [param x] at [param rate], measured from [param from] seconds in (what comes before, a fade in, is passed over):
## `{seconds, peak_db, db, quiet_db, loud_db, bright, low, mid, high, balance, events, frames}` - `db` the loudness of the whole
## (dBFS), `quiet_db` and `loud_db` its quietest and loudest tenth of frames, `bright` the middle frame's brightness (Hz), `low`
## `mid` `high` shares of its power (0-1), `balance` dB louder on the right (below 0 the left), `events` a second; each frame
## `{t, db, bright, events}`.
static func measure(x: PackedVector2Array, rate: int, from := 0.0) -> Dictionary:
	var sr := float(maxi(1, rate))
	var start := clampi(int(from * sr), 0, x.size())
	var n := x.size() - start
	if n <= 0:
		return {"seconds": 0.0, "peak_db": SILENT, "db": SILENT, "quiet_db": SILENT, "loud_db": SILENT, "bright": 0.0,
			"low": 0.0, "mid": 0.0, "high": 0.0, "balance": 0.0, "events": 0.0, "frames": []}
	var hop := maxi(1, int(FRAME * sr))
	var win := maxi(1, int(EVENT_WINDOW * sr))
	var before := maxi(1, int(round(EVENT_BEFORE / EVENT_WINDOW)))
	var gap := maxi(1, int(round(EVENT_GAP / EVENT_WINDOW)))
	var kl := 1.0 - exp(-TAU * LOW / sr)
	var kh := 1.0 - exp(-TAU * HIGH / sr)
	var lp_low := 0.0
	var lp_high := 0.0
	var prev := 0.0
	var peak := 0.0
	var sum_l := 0.0
	var sum_r := 0.0
	var pow_low := 0.0
	var pow_mid := 0.0
	var pow_high := 0.0
	var fp := 0.0            # this frame's power, its moving power, its events
	var fd := 0.0
	var fe := 0
	var wp := 0.0            # this event window's power
	var wins := PackedFloat64Array()
	var last_event := -gap
	var frames: Array = []
	var events := 0
	for i in n:
		var v := x[start + i]
		var m := (v.x + v.y) * 0.5
		peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
		sum_l += v.x * v.x
		sum_r += v.y * v.y
		lp_low += kl * (m - lp_low)
		lp_high += kh * (m - lp_high)
		pow_low += lp_low * lp_low
		var mid := lp_high - lp_low
		pow_mid += mid * mid
		var hi := m - lp_high
		pow_high += hi * hi
		var d := m - prev
		prev = m
		fp += m * m
		fd += d * d
		wp += m * m
		if (i + 1) % win == 0:
			var p := wp / float(win)
			wp = 0.0
			var k := wins.size()
			if k >= before:
				var mean := 0.0
				for j in range(k - before, k):
					mean += wins[j]
				mean /= float(before)
				if _db(p) > EVENT_FLOOR and _db(p) - _db(mean) >= EVENT_DB and k - last_event >= gap:
					last_event = k
					fe += 1
					events += 1
			wins.append(p)
		if (i + 1) % hop == 0 or i == n - 1:
			var len := float((i % hop) + 1)
			frames.append({"t": snappedf(float(i + 1 - int(len)) / sr, 0.01), "db": snappedf(_db(fp / len), 0.1),
				"bright": roundf(_bright(fp, fd, sr)) if _db(fp / len) > EVENT_FLOOR else 0.0, "events": fe})
			fp = 0.0
			fd = 0.0
			fe = 0
	var loud: Array = frames.map(func(f: Dictionary) -> float: return float(f["db"]))
	loud.sort()
	var lit: Array = frames.filter(func(f: Dictionary) -> bool: return float(f["bright"]) > 0.0).map(func(f: Dictionary) -> float: return float(f["bright"]))
	lit.sort()
	var total := pow_low + pow_mid + pow_high
	var secs := float(n) / sr
	return {"seconds": snappedf(secs, 0.01), "peak_db": snappedf(_db(peak * peak), 0.1),
		"db": snappedf(_db((sum_l + sum_r) * 0.5 / float(n)), 0.1),
		"quiet_db": float(loud[int(floor(0.1 * float(loud.size() - 1)))]) if not loud.is_empty() else SILENT,
		"loud_db": float(loud[int(ceil(0.9 * float(loud.size() - 1)))]) if not loud.is_empty() else SILENT,
		"bright": float(lit[lit.size() / 2]) if not lit.is_empty() else 0.0,
		"low": snappedf(pow_low / total, 0.01) if total > 0.0 else 0.0, "mid": snappedf(pow_mid / total, 0.01) if total > 0.0 else 0.0,
		"high": snappedf(pow_high / total, 0.01) if total > 0.0 else 0.0,
		"balance": snappedf(_db(sum_r / float(n)) - _db(sum_l / float(n)), 0.1) if sum_l > 0.0 and sum_r > 0.0 else 0.0,
		"events": snappedf(float(events) / secs, 0.1), "frames": frames}


## Measure [param m] told in lines, as an agent reads it: the whole first, then at most [param lines] frames.
static func text(m: Dictionary, lines := 60) -> String:
	var out := PackedStringArray()
	if float(m.get("seconds", 0.0)) <= 0.0 or float(m.get("db", SILENT)) <= EVENT_FLOOR:
		return "%.1f s heard: silent." % float(m.get("seconds", 0.0))
	out.append("%.1f s heard; its peak %.1f dB" % [float(m["seconds"]), float(m["peak_db"])])
	out.append("loudness %.1f dB on the whole, from %.1f (its quietest tenth) to %.1f (its loudest tenth): it swings %.1f dB"
		% [float(m["db"]), float(m["quiet_db"]), float(m["loud_db"]), float(m["loud_db"]) - float(m["quiet_db"])])
	out.append("brightness about %d Hz (the typical frequency of its power: higher is brighter, lower darker)" % int(m["bright"]))
	out.append("its power: %d%% low (under %d Hz), %d%% middle, %d%% high (over %d Hz)" % [roundi(float(m["low"]) * 100.0), int(LOW),
		roundi(float(m["mid"]) * 100.0), roundi(float(m["high"]) * 100.0), int(HIGH)])
	var b := float(m["balance"])
	out.append("balance: %s" % ("even" if absf(b) < 0.5 else "%.1f dB louder on the %s" % [absf(b), "right" if b > 0.0 else "left"]))
	out.append("sudden rises (a drop, a crackle, a chirp, a slap): %.1f a second" % float(m["events"]))
	var frames: Array = m.get("frames", [])
	var step := maxi(1, ceili(float(frames.size()) / float(maxi(1, lines))))
	out.append("over time (s: loudness dB, brightness Hz, sudden rises):")
	for i in range(0, frames.size(), step):
		var f: Dictionary = frames[i]
		out.append("%.1f: %.0f dB, %s, %d" % [float(f["t"]), float(f["db"]), "-" if float(f["bright"]) <= 0.0 else "%d Hz" % int(f["bright"]),
			int(f["events"])])
	return "\n".join(out)


static func _db(power: float) -> float:
	return 10.0 * log(power) / log(10.0) if power > 1e-12 else SILENT


## A frame's typical frequency from its power [param p] and the power of its first difference [param d] (Hz).
static func _bright(p: float, d: float, sr: float) -> float:
	if p <= 1e-18:
		return 0.0
	return acos(clampf(1.0 - d / (2.0 * p), -1.0, 1.0)) * sr / TAU
