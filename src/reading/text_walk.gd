extends RefCounted
class_name TextWalk

## TextWalk - what a reading reads of its note: the words the voice says, the title it announces, and the text its
## cast of speakers and its fingerprint come from (a voice's Test reads the one shared passage in every kind of note,
## [constant ReadingAudition.PASSAGE]). This one is the
## note's own words (a tablet chapter read off its screen); a component that rewrites what the voice reads hands
## the reading another (a table show's [EpisodeWalk] reads the episode it produced, never the brief).
##
## A walk is handed, not overridden (next/structure.md, step 8): an object the mode gives the panel, so what is
## read is a thing of its own (next/notes.md, "One place where order matters: text walks").

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


## Whether the words read are the note's as written - so an edit by hand leaves a reading already
## on the stream out of date. Not for an episode: its brief is what the NEXT one is made from.
func reads_source() -> bool:
	return true


## Why speaker [param old] may not be called [param new], "" where it may ([param words], the note's words as they stand). Only a
## walk that reads the note's words, or one that renames where its speakers come from, takes a rename.
func rename_refused(_old: String, _new: String, _words: String) -> String:
	return "" if reads_source() else "these speakers are named by the episode's script, not the note's words"


## Speaker [param old] called [param new] in what this walk reads beyond the note's words. "" done, else why not.
func rename_read(_old: String, _new: String) -> String:
	return ""


## The note's words [param words] with speaker [param old] called [param new]: every cue naming it, and no prose
## ([method Manuscript.rename_speaker]).
func renamed_words(words: String, old: String, new: String) -> String:
	return Manuscript.rename_speaker(words, old, new)
