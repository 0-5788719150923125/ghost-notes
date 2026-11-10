extends RefCounted
class_name PipelineRow

## PipelineRow - one thing made for a note, as one line of its Pipeline card ([PipelineSection], [PipelineCard];
## next/pipeline.md): its name, where it stands, what it says, and what its ⟳ does.
##
## ONE ROW, ONE ACTION (the user, 2026-11-02: "every distinct regeneration action should just be a part of the pipeline
## list ... when we click the regenerate button - we will KNOW that it's going to regenerate that one thing, without a
## maybe second list appearing"). There is no menu to fill in: a thing with two ways to be made again is two rows.
##
## WHAT A ⟳ THROWS AWAY IS SAID BEFORE IT IS PRESSED ([member asks]): the row goes amber, its tooltip says so, and it asks
## once, a yes or a no. Empty when it throws away nothing but what it remakes, and then it starts at once.

## WHERE A ROW STANDS, whoever made it.
const STATES := {
	"made": {"label": "Made", "glyph": "✓", "blurb": "Made, from what it is made from as that stands."},
	"running": {"label": "Being made", "glyph": "◌", "blurb": "Its agent or tool is at work."},
	"queued": {"label": "Waiting its turn", "glyph": "◌", "blurb": "Asked for, behind the work ahead of it."},
	"failed": {"label": "Failed", "glyph": "✗", "blurb": "Its last run stopped on an error, which the row says."},
	"stale": {"label": "Stale", "glyph": "⚠", "blurb": "Made, from something that has changed since."},
	"missing": {"label": "Not made", "glyph": "·", "blurb": "Nothing made yet."},
	"none": {"label": "Nothing to make", "glyph": "–", "blurb": "This note has nothing here to make: left out of the count."},
}

## Its name in its section: what a gate and a press find it by, unchanged while it is the same thing.
var key := ""
## What it is called.
var label := ""
## THE GROUP IT STANDS IN (a card's rows, the table's), "" for none. Rows of one group stay together under its name.
var group := ""
## A key of [constant STATES].
var state := "missing"
## What it says of itself beside its name.
var said := ""
## It says all of that, wrapped, not clipped: what is being done comes first and whole.
var wraps := false
## What its name's and its words' tooltips say, "" for what it says.
var tip := ""
## WHAT ITS ⟳ DOES, in words: its tooltip. "" for a row with no ⟳ - nothing of it can be made again by itself.
var again := ""
## Whether its ⟳ is offered now.
var open := true
## WHAT ITS ⟳ THROWS AWAY besides what it remakes, a sentence: "" starts at once, otherwise it asks first.
var asks := ""
## Its ⟳.
var redo := Callable()
## WHETHER ITS ⟳ ALSO THROWS AWAY WHAT WAS MADE FROM IT ([member lockable] rows): locked (the default), it does, and [member asks]
## says what; unlocked, it makes this row again alone and keeps the rest (TableEpisode.unlocked).
var lockable := false
var locked := true
## ...and how it is locked or unlocked: (on: bool) -> void, true locked.
var lock := Callable()
## WHAT ITS ▶ DOES, "" for a row with none: what is made without throwing anything away (an actor's step and what it needs).
var go := ""
## Whether its ▶ is offered now.
var go_open := true
## Its ▶.
var make := Callable()


func _init(p_key := "", p_label := "", p_group := "") -> void:
	key = p_key
	label = p_label
	group = p_group


## The glyph of [param of_state].
static func glyph(of_state: String) -> String:
	return String(Registry.field(STATES, of_state, "glyph", "·"))


## Whether a row in [param of_state] counts towards the card's tally: it is something to make.
static func counted(of_state: String) -> bool:
	return of_state != "none"
