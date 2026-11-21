extends RefCounted
class_name AudioFeatures

## One frame of audio, typed: the only thing a [GhostScene] reads from the audio engine. [Spectrum] fills one
## every frame and hands it to the active scene.

## Overall loudness this frame, roughly 0..1 (smoothed, soft-clipped).
var energy: float = 0.0

## Named band energies, each roughly 0..1: views into [member bands] at musically useful split points.
var bass: float = 0.0
var low_mid: float = 0.0
var mid: float = 0.0
var high: float = 0.0
var treble: float = 0.0

## A short pulse near 1.0 right after an energy onset, decaying toward 0. A cheap stand-in for beat detection.
var beat: float = 0.0

## Smoothed seconds between beat onsets (small = fast music). ~0.5 (120 BPM) until enough onsets are seen.
## The Director paces scene changes off this.
var beat_period: float = 0.5

## Spectral flux this frame: the sum of positive per-band deltas. High when new frequency content arrives.
var flux: float = 0.0

## 0..1 "we just moved into a new part of the song" score, from a sliding window over [member flux]. The
## [Director] cuts scenes on this rather than a timer. Stays low through a steady passage.
var movement: float = 0.0

## How many bands [member bands] holds, as [Spectrum] analyzes them: log-spaced from [constant FREQ_MIN] to
## [constant FREQ_MAX] Hz, each its decibels over a window of [constant DB_FLOOR] mapped onto 0..1.
const BAND_COUNT := 64
const FREQ_MIN := 30.0
const FREQ_MAX := 16000.0
const DB_FLOOR := 60.0

## The full spectrum this frame: N band magnitudes, low to high, each ~0..1.
var bands: PackedFloat32Array = PackedFloat32Array()

## Seconds of audio elapsed (playback position), or an idle clock when no audio is loaded.
var time: float = 0.0

## The heard audio's waveform ([method wave]): its rate (Hz) and how many samples a window holds (about 93 ms).
const WAVE_RATE := 11025
const WAVE_SAMPLES := 1024
var _wave_of := Callable()
var _wave := PackedFloat32Array()
var _waved := false
var _wave_lock := Mutex.new()


## Where [method wave] reads from ([HeardWave], set by [Spectrum]): a Callable taking nothing and answering the window, safe
## on any thread.
func hear_from(source: Callable) -> void:
	_wave_of = source


## The heard audio's waveform up to [member time], mono: [constant WAVE_SAMPLES] samples at [constant WAVE_RATE], newest
## last - what a scope draws; empty where nothing is heard. Read only when first asked (a file read exactly at this moment, or
## what a stream played), then kept; safe from a worker.
func wave() -> PackedFloat32Array:
	_wave_lock.lock()
	if not _waved:
		_waved = true
		_wave = _wave_of.call() if _wave_of.is_valid() else PackedFloat32Array()
	var out := _wave
	_wave_lock.unlock()
	return out


## Linear sample of the band spectrum at [param t] in 0..1, interpolated.
func sample(t: float) -> float:
	var n := bands.size()
	if n == 0:
		return 0.0
	var x := clampf(t, 0.0, 1.0) * float(n - 1)
	var i := int(x)
	if i >= n - 1:
		return bands[n - 1]
	return lerpf(bands[i], bands[i + 1], x - float(i))
