extends RefCounted
class_name Openings

## Openings - what the picture does while the intro holds, for a medium that draws an opening of its own (its
## [constant Medium.REGISTRY] row `uses` "opening": the card table's, the desk's, the letter's; [ShowOpening] says
## how each is drawn). A choice, not a given: the Intro & outro card picks it ([BookendsCard]), the Director keeps it
## beside the holds ([member ShowFeed.opening]), and a note that names none opens on the picture itself, sharp
## ([constant DEFAULT]).
##
## What a take opened with is its own: the reading writes the opening it was rendered with into the take's sidecar,
## beside its holds, and whatever asks of a take later (a thumbnail of its title screen) reads it there
## ([method of_take]), never the Director's as it stands by then.

## One row a way of opening: `blur` - the picture thrown far out of focus, the focus pulled as the show
## opens; `title` - the show's name and byline over it ([TitleCard]).
const ROWS := {
	"none": {"label": "None", "blur": false, "title": false,
		"blurb": "The picture fades up from black, sharp, and the show begins on it."},
	"blur": {"label": "Out of focus", "blur": true, "title": false,
		"blurb": "The picture fades up thrown far out of focus, only its colors to be made out, and the focus pulls as the show begins."},
	"title": {"label": "Title", "blur": true, "title": true,
		"blurb": "The show's name and its byline over the picture thrown out of focus; the name goes and the focus pulls as the show begins."},
}
## A note that names no opening: none.
const DEFAULT := "none"
## The scene seen before anything begins: the name gone and the focus pulled this long (seconds) before the show
## opens (its first word, a deck's shuffle), inside the intro hold, which is still the seconds before the voice. Never
## so early that the name has not stood [constant TITLE_LEAST] seconds into the intro: a short intro keeps what it can
## of both. Every medium that draws an opening takes it ([ShowOpening]'s callers: the table, the desk, the dispatch
## desk); a letter's page lies blank longer ([constant LetterScript.BLANK_PAGE]). One with none has the picture up as
## long before the first sound ([method Director._bookend_fade]).
const SETTLE := 3.0
const TITLE_LEAST := 3.5


## [param key] if it is a way of opening, else [constant DEFAULT].
static func known(key: String) -> String:
	return key if ROWS.has(key) else DEFAULT


## Is the picture out of focus through [param key]'s intro?
static func blurred(key: String) -> bool:
	return bool(Registry.field(ROWS, known(key), "blur", false))


## Is the show's name up through [param key]'s intro?
static func titled(key: String) -> bool:
	return bool(Registry.field(ROWS, known(key), "title", false))


## How long before the show opens at [param opening] (seconds into it) the intro is over ([constant SETTLE]): as long
## as the name has stood [constant TITLE_LEAST] first, else less.
static func settle(opening: float) -> float:
	return clampf(opening - TITLE_LEAST, 0.0, SETTLE)


## Where the title screen stands whole, seconds into a take: the name fully up over the blur - after it
## fades in (by 1.4 s, [method ShowOpening.title_alpha]) and before the focus pull, which starts
## [constant ShowOpening.FOCUS_PULL]`.x` before the intro is over, a [method settle] before the show opens
## at the end of the [param intro] hold.
static func title_moment(intro: float) -> float:
	return clampf(intro * 0.4, 1.5, maxf(1.5, intro - settle(intro) - 1.6))


## What the take at [param take] opened with, from its sidecar: `{opening, intro}` - the way it opened and its intro
## hold - each [param fallback]'s where the sidecar does not say it (a song, no take).
static func of_take(take: String, fallback: Dictionary) -> Dictionary:
	var out := {"opening": known(String(fallback.get("opening", DEFAULT))), "intro": float(fallback.get("intro", 0.0))}
	var side := take.get_basename() + ".json"
	if take.is_empty() or not FileAccess.file_exists(side):
		return out
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(side)) != OK or not (j.data is Dictionary):
		return out
	var d: Dictionary = j.data
	if d.get("opening") is String:
		out["opening"] = known(String(d["opening"]))
	var b: Variant = d.get("bookend", {})
	if b is Dictionary and (b as Dictionary).has("in"):
		out["intro"] = float((b as Dictionary)["in"])
	return out
