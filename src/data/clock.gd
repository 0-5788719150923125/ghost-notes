extends RefCounted
class_name Clock

## Clock - how the app tells the time: m:ss, h:mm:ss past an hour, whole seconds. The transport's
## rail, every timeline's ruler and playhead ([TimelineView]), an episode's chapters and an agent's
## progress all say it this one way, where each had kept a copy of its own. Plain, and naming no
## autoload, so a gate run without the app reads it too.


## [param t] seconds as the clock says it (a negative time is 0:00).
static func text(t: float) -> String:
	var s := maxi(int(t), 0)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]
