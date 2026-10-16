extends RefCounted
class_name TextWalk

## TextWalk - what a reading reads of its note: the words the voice says, the title it announces,
## the text its cast of speakers and its fingerprint come from, and the passage a voice is
## auditioned with. This one is the note's own words (a tablet chapter read off its screen); a
## component that rewrites what the voice reads hands the reading another - Cards' [EpisodeWalk],
## which reads the episode it produced and never the brief.
##
## A WALK IS HANDED, NOT OVERRIDDEN (next/structure.md, step 8). These were five methods every
## mode built on [ReadingPanel] overrode; a walk is an object the mode gives the panel instead, so
## what is read is a thing of its own - the first piece of "the voice as a card that reads what the
## note's components hand it" (next/notes.md, "One place where order matters: text walks").

## The words to read, fresh - what Play, a scrub and an export read. [param pulled] is the note as
## the panel has just pulled it from its file (a pull also flushes a voice change into the file).
func body(pulled: String) -> String:
	return pulled


## What the VOICE reads of [param text] and the title it announces first: `{body, title}`.
## [param title] is the note's own. A tablet chapter is read off the screen and nothing else - no
## title announced, skipped text out, link targets out, a rest for every run of taps.
func spoken(text: String, title: String) -> Dictionary:
	if TabletScript.is_tablet(text):
		return {"body": TabletScript.speakable(text), "title": ""}
	return {"body": text, "title": title}


## The text the cast is derived from (its speaker cues are the tabs) and the live session is
## fingerprinted by. [param written] is the note's text as the editor holds it now.
func cast_text(written: String) -> String:
	return written


## The passage every voice is auditioned with by Test; [param fallback] is the panel's own.
func test_passage(fallback: String) -> String:
	return fallback


## Whether the words read are the note's as written - so an edit by hand leaves a reading already
## on the stream out of date. Not for an episode: its brief is what the NEXT one is made from.
func reads_source() -> bool:
	return true
