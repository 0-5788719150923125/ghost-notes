extends RefCounted
class_name PipelineRow

## PipelineRow - one thing made for a note, as one line of its Pipeline card ([PipelineSection], [PipelineCard];
## next/pipeline.md): its name, where it stands, what it says, and what its ⟳ does.
##
## One row, one action: a thing with two ways to be made again is two rows, so there is no menu to fill in.
##
## What a ⟳ throws away is said before it is pressed ([member asks]): the row goes amber, its tooltip says so, and it
## asks once, a yes or a no. Empty when it throws away nothing but what it remakes, and then it starts at once.

## Where a row stands, whoever made it.
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
## The group it stands in (a card's rows, the table's), "" for none. Rows of one group stay together under its name.
var group := ""
## A key of [constant STATES].
var state := "missing"
## What it says of itself beside its name.
var said := ""
## It says all of that, wrapped, not clipped: what is being done comes first and whole.
var wraps := false
## What its name's and its words' tooltips say, "" for what it says.
var tip := ""
## What its ⟳ does, in words: its tooltip. "" for a row with no ⟳ (nothing of it can be made again by itself).
var again := ""
## Whether its ⟳ is offered now.
var open := true
## What its ⟳ throws away besides what it remakes, a sentence: "" starts at once, otherwise it asks first.
var asks := ""
## Its ⟳.
var redo := Callable()
## Whether it is kept ([member lockable] rows; next/editing.md step 1): locked, Generate passes it by, stale or not;
## its ⟳ still makes it again, throwing nothing away (TableEpisode.kept). A part a hand changed is kept until unlocked.
var lockable := false
var locked := false
## ...and how it is locked or unlocked: (on: bool) -> void, true locked.
var lock := Callable()
## What its ✎ does, "" for a row with none (next/editing.md step 4): what it made opened to be changed by hand (its
## words, its data, a picture of one's own) and written back as a hand's version, kept.
var edit_tip := ""
## Its ✎.
var edit := Callable()
## WHAT ITS ▶ DOES, "" for a row with none: what is made without throwing anything away (an actor's step and what it needs).
var go := ""
## The action's visible text: normally ▶, or Resume for an interrupted draft.
var go_text := "▶"
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
