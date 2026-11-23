extends RefCounted
class_name ExportSpace

## ExportSpace - how much disk an export needs, and whether the disk it is saved to has that much.
##
## An export writes the MP4 and, beside it, Movie Maker's MJPEG scratch. Where the scratch is given back behind the encoder
## (Linux with fallocate, [method Exporter._punch_behind_encoder]) only the encoder's lag stays on disk; elsewhere the scratch
## grows to the whole film before it is encoded. x264 holds quality, not size, so an MP4's size is what is shown: before the
## render the estimate is the busiest rate an export of that quality has had ([method remember], kept per quality tag), and
## while it renders, the MP4 so far over the video it holds ([method need_more]).
##
## Pure: the exporter reads the free space and the kept rates and hands them in. Never stops an export - it only says.

## Video bits per pixel of each frame for a quality never measured: busy, grainy 4K60 at crf 20 near 60 Mbps.
const PRIOR_BPP := 0.12
## MJPEG scratch bytes per rendered pixel (Godot's writer fills 4 GiB in about 3.1 min of 2880x1620 at 60 fps).
const MJPEG_BYTES_PER_PX := 0.08
## The audio track (aac at 192k), bytes a second.
const AUDIO_BYTES_S := 24000
## The scratch kept on disk while it is given back: the encoder's lag, seconds of video.
const LAG_S := 60.0
## Headroom on every estimate: a share of it, at least FLOOR bytes.
const MARGIN := 0.15
const FLOOR := 1 << 30
## Measured rates kept per quality.
const KEEP := 8
## Video an in-flight forecast waits for before it projects (seconds encoded): the first seconds are a title and a fade.
const WARM_S := 20.0
## Where the measured rates live in ghost.cfg: {quality tag: [bits per pixel, ...]}.
const SECTION := "export"
const KEY := "bits_per_pixel"


## Free bytes on the disk that holds [param path]'s folder, -1 when it cannot be read.
static func free_at(path: String) -> int:
	var d := DirAccess.open(path.get_base_dir())
	return d.get_space_left() if d != null else -1


## The rate an export of quality [param tag] is planned at: the busiest measured in [param kept], else [constant PRIOR_BPP].
static func rate_for(tag: String, kept: Dictionary) -> float:
	var best := 0.0
	for v in kept.get(tag, []):
		best = maxf(best, float(v))
	return best if best > 0.0 else PRIOR_BPP


## [param kept] with an export's measured rate added under [param tag], the oldest dropped past [constant KEEP].
static func remember(kept: Dictionary, tag: String, bpp: float) -> Dictionary:
	var out := kept.duplicate(true)
	var list: Array = out.get(tag, [])
	list.append(snappedf(bpp, 0.0001))
	while list.size() > KEEP:
		list.pop_front()
	out[tag] = list
	return out


## The video bits per pixel a finished MP4 of [param bytes] took: [param px_s] pixels a second (w x h x fps) for
## [param seconds]. 0 when too short to say.
static func measured(bytes: int, seconds: float, px_s: float) -> float:
	if seconds < WARM_S or px_s <= 0.0:
		return 0.0
	return maxf(0.0, bytes - AUDIO_BYTES_S * seconds) * 8.0 / (px_s * seconds)


## The bytes an MP4 of [param seconds] at [param px_s] output pixels a second takes at [param bpp].
static func mp4_bytes(seconds: float, px_s: float, bpp: float) -> int:
	return int(seconds * (px_s * bpp / 8.0 + AUDIO_BYTES_S))


## The most scratch on disk at once for [param seconds] rendered at [param render_px_s] pixels a second: the encoder's lag
## where it is given back ([param gives_back]), the whole film where not.
static func scratch_bytes(seconds: float, render_px_s: float, gives_back: bool) -> int:
	var held := minf(seconds, LAG_S) if gives_back else seconds
	return int(held * render_px_s * MJPEG_BYTES_PER_PX)


## [param bytes] with the headroom every estimate carries.
static func padded(bytes: int) -> int:
	return bytes + maxi(int(bytes * MARGIN), FLOOR)


## What an export needs before it starts: the MP4, the scratch and [param extra] (a stretch's copies of the earlier export),
## padded.
static func need_before(seconds: float, px_s: float, render_px_s: float, bpp: float, gives_back: bool, extra := 0) -> int:
	return padded(mp4_bytes(seconds, px_s, bpp) + scratch_bytes(seconds, render_px_s, gives_back) + extra)


## What a running export still needs, padded, from the MP4 so far ([param mp4_now] bytes holding [param encoded_s] of
## [param seconds]) and the scratch still to grow ([param scratch_more]); -1 before [constant WARM_S] is encoded.
static func need_more(seconds: float, encoded_s: float, mp4_now: int, scratch_more: int) -> int:
	if encoded_s < WARM_S or mp4_now <= 0:
		return -1
	var final := float(mp4_now) / encoded_s * seconds
	return padded(maxi(0, int(final) - mp4_now) + maxi(0, scratch_more))


## [param bytes] as a person reads it.
static func size_text(bytes: int) -> String:
	if bytes >= 1 << 30:
		return "%.1f GB" % (bytes / float(1 << 30))
	return "%d MB" % maxi(1, roundi(bytes / float(1 << 20)))
