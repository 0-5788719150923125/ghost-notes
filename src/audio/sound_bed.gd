extends RefCounted
class_name SoundBed

## SoundBed - a sound laid under a voice: what a reading asks of whatever makes one.
##
## A reading mixes the place it is in under the voice - live, a buffer at a time, and into the
## take an export renders. It does not know what a place is: it is handed something that answers
## these five questions ([method ReadingPanel._environment] hands it the maker), and the card
## table's [Soundscape] is the one thing that does today. The questions are here, under both, so
## the reading names no table.

## Whether there is anything to hear.
func active() -> bool:
	return false


## The level it is mixed at, 0-1.
func set_level(_d: float) -> void:
	pass


## [param voice] with the bed under it, frame for frame.
func mix(voice: PackedVector2Array) -> PackedVector2Array:
	return voice


## Render ahead on a worker, so [method mix] finds its frames made.
func prefetch(_seconds := 1.5) -> void:
	pass


## Wait for the worker, if one is running - before this is let go.
func finish() -> void:
	pass
