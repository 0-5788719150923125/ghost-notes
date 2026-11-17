extends RefCounted
class_name StillClock

## StillClock - whether a show stands still, from the show time a sound's player is handed each tick ([WorkSounds],
## [DispatchSounds]): still once that time has not moved for [constant STILL] seconds of the machine's own clock. A live
## show's time is the voice player's position, which moves once a mix, so a few frames in a row can be handed the same time
## while the show plays on: held on a count of ticks, a player stops and starts several times a second.
##
## [member clock] is the machine's milliseconds, a seam a gate hands its own.

## How long the show's time must stand still (seconds) before it is.
const STILL := 0.25

var clock: Callable = func() -> int: return Time.get_ticks_msec()
var _last := NAN
var _since := 0


## Whether the show stands still, handed its time [param t] this tick.
func still(t: float) -> bool:
	var now := int(clock.call())
	if t != _last:
		_last = t
		_since = now
		return false
	return now - _since >= int(STILL * 1000.0)
