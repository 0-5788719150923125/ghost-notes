extends RefCounted

## WorkClock - what a piece of code COSTS, for a gate that holds a cost to a budget, measured so a
## busy machine does not decide the answer.
##
##   const WorkClock := preload("res://tests/work_clock.gd")
##   var ms := WorkClock.cost_ms(func() -> void: medium._shuffles._wash_plan(7777, 30.0))
##   _ok(ms < 700.0, "a plan is cheap enough (%.0f ms)" % ms)
##
## THE WALL CLOCK TIMES THE MACHINE, NOT THE CODE. table_wash_check held a step of rest to 25 ms by
## the wall clock and failed with no code changed the day three gates ran beside it and an encode:
## 59.6 ms, most of it spent waiting for a core (2026-10-12). CI runs four gates at once on four
## cores, which is the same thing.
##
## SO THE CLOCK IS THE THREAD'S OWN: the time this thread has had a processor
## (`/proc/thread-self/schedstat` on Linux), which does not run while it waits for one. Where there
## is no such clock (Windows, macOS) it is the wall clock, and the rest below still holds.
##
## AND THE COST IS THE LEAST OF SEVERAL TIMINGS: what else a machine is doing only ever ADDS to a
## timing - a core shared with its twin, a cache emptied by a neighbor - so the least is the nearest
## to the work itself, and a burst that lands on one timing does not land on all of them. Code that
## keeps what it made (a cache) is handed a `reset` to run before each timing, or the second timing
## measures the keeping.
##
## WHAT IT DOES NOT DO, measured before it was left out: count the cost in units of a reference
## piece of work timed beside it. The same work costed ten times on a loaded desk spread 63% by the
## wall clock, 55% as a ratio to the reference, 35% as that ratio in processor time - and 28% in
## processor time alone. The reference and the work slow down by different amounts, so dividing
## one by the other adds a second noise rather than removing the first. A budget therefore needs
## real room over the cost it holds (twice is enough; a third more is not), and
## [method cost_ms] is what tells a gate how much room it has.
##
## THE CONTROL IS THE CALLER'S: a budget is worth having only if more work breaks it, so a gate
## costs the same work done twice over and holds that to be about twice as much.

## How many timings a cost is the least of.
const RUNS := 3


## The cost of [param work] in milliseconds of this thread's processor: the least of [param runs]
## timings. [param reset], when given, runs before each timing and is not counted.
static func cost_ms(work: Callable, reset := Callable(), runs := RUNS) -> float:
	var best := INF
	for r in maxi(runs, 1):
		if reset.is_valid():
			reset.call()
		var t0 := usec()
		work.call()
		best = minf(best, float(usec() - t0) / 1000.0)
	return best


## The processor time this thread has had, in microseconds - or the wall clock's, where the
## system keeps no such count. Only differences between two readings mean anything.
static func usec() -> int:
	var f := FileAccess.open("/proc/thread-self/schedstat", FileAccess.READ)
	if f == null:
		return Time.get_ticks_usec()
	# "<nanoseconds on a processor> <nanoseconds waiting for one> <timeslices>" (a /proc file has
	# no length to read by: a line is asked for)
	var ran := f.get_line().get_slice(" ", 0)
	return int(ran) / 1000 if ran.is_valid_int() else Time.get_ticks_usec()


## Whether [method usec] is the thread's processor time here, for a gate's own report.
static func is_thread_clock() -> bool:
	return FileAccess.file_exists("/proc/thread-self/schedstat")
