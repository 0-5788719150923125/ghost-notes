extends RefCounted
class_name ReadingBed

## ReadingBed - what a reading lays under its voice: the place it is in, heard.
##
## Handed, not overridden (next/structure.md, step 12). A [ReadingPanel] knows the sample rate and the moment;
## the component that knows the place (a table's wind and sea, the room a scene is set in) hands the reading one
## of these, and the panel asks it, live and for the export take. This one is no place: a chapter read on its own
## is heard over silence. The table show hands the episode's table, heard.

## The bed this one gives way to where it has no place of its own ([method of] `{}`): the Environment card's, under a table show's
## episode shown at the desk, whose table is a pad and a pen. Handed by whichever of the two cards comes second.
var under: ReadingBed = null


## Where the reading is now: `{make, key}` (`{key}` alone while it has none yet) - `make` is
## `(sample_rate: int, t0: float) -> SoundBed`, the bed from show time [code]t0[/code], and `key`
## changes when the place does (the panel asks again every couple of seconds while a reading
## plays). `{}` for none. [param export]: for the take an export is rendering, which may be of
## another episode than the one on screen.
func of(_export := false) -> Dictionary:
	return {}


## How far up the bed sits under the voice, 0-1 (see [method SoundBed.set_level]).
func level() -> float:
	return 0.0


## Its gain over that (dB, [member SoundBed.gain_db]): the Environment's Level, where a card hands one.
func gain_db() -> float:
	return 0.0
