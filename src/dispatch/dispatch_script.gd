extends RefCounted
class_name DispatchScript

## DispatchScript - a note as the dispatch desk plays it (next/dispatch.md): what the voice reads, the words it says, and
## everything the desk does between and alongside them.
##
## The note is the script, word for word. An ordinary paragraph is said by whoever the last speaker cue names; the first
## name cued is the room's voice (the man at the desk, never seen), every other voice is heard through a phone. The
## desk's marks, each on a line of its own:
##
##     <!-- call: AISLE -->            the phone labeled AISLE lifts out of its row, flips open and is held to the ear:
##                                     dialed and ringing twice in the earpiece before anyone answers; answered at once if
##                                     it was ringing, picked back up if it lay open on the desk. Another in hand is laid
##                                     down open first (on hold).
##     <!-- /call -->, <!-- /call: VAN -->   the phone in hand (or the one named, lying open) snaps shut and goes home.
##     <!-- ring: LIGHTS -->           that phone buzzes and rattles against its neighbors; a call to it straight after
##                                     answers it, and with none it rings out.
##     <!-- text: AISLE | words -->    a chime and a buzz, and the phone comes up out of its row, flips open and is held up
##                                     to be read: the words on its screen, never said or captioned. It goes home after,
##                                     unless it texts again in a moment.
##     <!-- reply -->, <!-- reply: AISLE -->   the room's next words are typed into that phone (the last to text) as they are
##                                     said, a key at a time, under the message, and sent. `reply: tablet` types them into
##                                     the message box at the foot of the tablet's page as they are said, and sends them.
##     <!-- ping: a place | 110, 2.9 -->   the target comes to that place on the radar: a ping, the place written beside
##                                     the blip (the first: the radar finds him there). The numbers place it as a radar
##                                     reports a contact: bearing in degrees clockwise from the scope's top, range in range
##                                     rings out from the desk (`bearing 110, range 2.9` too). He goes there along a track
##                                     while the voice goes on, the sweep painting him a step further each round, from where
##                                     a `moving` mark says he set off, else over the moments before. A place named again
##                                     bare is the same spot; one with no numbers ever is laid out from the words, and warned
##                                     of.
##     <!-- moving -->                 the target sets off from where he is, toward the next ping's place: the radar sounds
##                                     its alarm and the camera turns to it. Straight after a ping he passes through it (a
##                                     place on the way: `driving south`) with no alarm.
##     <!-- sound: jet, ... -->        a sound of [constant DispatchSounds.SOUNDS], named by its key among the words.
##     <!-- static: 5 -->, <!-- static: 5, surf -->   the receiver opens up for that many seconds: Io-B's crackle, or surf.
##                                     `<!-- static: 5, surf, unwatched -->`: heard with the camera left where it is.
##     <!-- print -->                  the printer prints what was typed since it last printed (struck blocks aside).
##     <!-- sleep -->                  the terminal's screen goes dark.
##     <!-- off: tv -->                a screen goes dark (tv, feed, satellite).
##     <!-- look: radar -->            the camera turns to that thing ([constant DispatchMedium.SPOTS]) until something
##                                     else is active.
##     <!-- lift: mug -->              a thing on the desk is lifted toward the chair, held for a sip and set back down.
##     <!-- switch: BAD -->            the switch box's toggle is thrown to that side.
##     <!-- live: tv -->               that screen shows this desk, live, seen from just behind the empty chair (words
##                                     after a comma say so for a reader: `live: tv, this desk from behind the chair`);
##                                     `live: tablet` plays it into the player on the tablet's page.
##     <!-- tablet --> ... <!-- /tablet -->   the tablet is picked up and held before the eye, its screen waking, and laid
##                                     back down unhurried, its screen left lit until it locks itself half a minute on, to
##                                     come back up on the page it was left on. Each ```page fence
##                                     while it is up is a page, in the tablet medium's own markdown ([TabletScript]), its
##                                     first line `url: address` or `search: words`, then any `nav: A | B` (the site's menu);
##                                     set with no placeholders ([member TabletPage.placeholders]). It is browsed as the tablet medium
##                                     browses ([method browsing]): a page the one up links to is tapped, any other address
##                                     typed into the bar; a search is typed into the box of a search engine's page (a page
##                                     that is little but its name), else into the bar; the address of the page up again
##                                     is that page reloaded. Shown and never said; it follows the room's words, scrolling
##                                     what is read off it into view, else easing slowly down to where its writing ends. `<!-- player -->` on a page is a
##                                     video player. `<!-- said: words -->` on a line of a page, over a picture or a
##                                     paragraph: the page is brought there as the room says those words, and stays;
##                                     a page with one goes only where they say, its top until the first (what is said
##                                     over it is narration, never read off it).
##     <!-- back -->                   the tablet's back arrow is tapped: the page before in this tab, scrolled where it
##                                     was left (with none behind it, warned of).
##     <!-- new tab -->                a blank tab is opened on the tablet; the next page is typed into its bar.
##     <!-- replay: tablet | words --> the room's own earlier words said again through the tablet's speaker, as the
##                                     video's soundtrack (found among what was said, else warned of); `replay: tv`
##                                     through the television's, as the soundtrack of what it shows (`live: tv`).
##     <!-- image (feed): words -->    a picture on that screen (feed, satellite, tv) until the next there or `off`, the
##                                     camera turning to it; `image (feed, unwatched): words` lands it with the camera left
##                                     on what it was on.
##     <!-- video (tv): clip.webm | words -->   a moving picture on that screen, looping under its snow, until the next
##                                     there or `off`: the clip imported on the Pictures card for those words (the file
##                                     name a hint for the author); the screen's static until one is. `(tv, unwatched)` as
##                                     a picture's.
##     <!-- image (full): words --> ... <!-- /image -->   a picture over the whole screen for the passage, one straight
##                                     after another dissolving into it.
##     <!-- strike -->                 after a typed line: the writer stops to decide, then backspaces it off the screen.
##     <!-- gain: 9 -->                the radar's gain knob is turned to that number (1 to 10; it starts at 3), a click a
##                                     step. Above 3 the scope paints clutter round the target, more the higher it is;
##                                     from 9, one more on the desk itself, the chair's.
##     <!-- bell -->                   the terminal's bell, one short beep as the block after it goes up.
##     <!-- lamp: off -->, <!-- lamp: on -->   the gooseneck lamp is switched off (or on), with a click.
##     <!-- power: off -->, <!-- power: on -->   the grid goes down (or comes back): every thing on the desk that runs on it
##                                     goes dark at once - the lamp, the terminal and every screen (a tube collapsing to its
##                                     dot), the radar, the receiver and its glows, every little light - with a thunk; the
##                                     phones and the tablet run on their batteries. A film played after it lights its screen
##                                     all the same.
##     <!-- environment: shafts off, beams on -->   the Environment's elements, each named by its kind or the name it was
##                                     kept under, switched on or off there (a bare number: the seconds it takes, 0.4 bare).
##                                     An element a mark names is, before its first mark, the other way: `beams on` keeps the
##                                     beams off until then. `shafts` with no shafts on the Environment is the hollow's own.
##     <!-- play (terminal): ERROR ME FOUND -->   a film on that screen (terminal, feed, satellite, tv): a note's own show by
##                                     its title, made once at the screen's shape (the Pipeline card), or a video file by its
##                                     path - its picture on the glass and its sound in the room. Marks written after it in
##                                     the same silence happen while it plays; the voice waits for the rest of it where the
##                                     silence ends. `(terminal, mono)` shows it in the screen's own phosphor; `unwatched`
##                                     leaves the camera where it is; `loop` plays it round and round under all that follows,
##                                     the voice never waiting for it, until something else is put on its screen (`off: tv`),
##                                     the camera on it as a `look:` holds, until something else turns it.
##     <!-- fade: to-black, 4 -->      the picture goes down to black over that many seconds (2 bare), the voice waiting.
##                                     In the black the desk is still heard; what is marked there happens unseen and at
##                                     once (a hesitation holds the black, a sound plays in it, a voice may speak in it).
##     <!-- fade: from-black, 01:14, 3 -->   the picture comes back up (2 seconds bare) on the clock, its cards turning over
##                                     to that time, held a beat, before the camera eases to the desk; the clock runs on a
##                                     minute a minute. The first mark of a note may be one: the night opens on the clock.
##                                     The first ping after it puts the target where it says, with no track across the
##                                     black. A said line opening on a time (`22:54.`) more than five minutes off the
##                                     clock, by a steady voice's estimate, is warned of.
##
## The terminal is one program on a fixed screen, worked through ```terminal blocks ([DispatchTerminal] says every line
## kind): commands typed on the command line, panels kept by id that come back as they last stood, lines typed into
## them, rows changed in place, waits and alerts, the desk's marks at their points. A block is silent and the voice waits
## for it, except a `type:` line, typed and said behind the keys as the room's words; `type (Name):` says it in that voice.
## A block's last `key:` lines that the paragraph straight after it opens by saying are typed ahead of its words the same
## way ([method said_keys]): the typing is never all done before the voice that reads it begins. A `read:` line is typed
## by the other side of the glass (the target, live on the mirror) and read aloud by the room the same way; it is not the room's typing, so a print or a strike passes it over. Said lines of one kind one straight after
## another in one voice are one passage: the keys run on over each line's end, one to three words ahead of the voice at an
## even pace ([constant AHEAD_MOST]), and the voice reads it through as a page is read, never stopping for a line.
## The glass is simulated through the whole note, so each action at the terminal carries the glass it starts from.
##
## A voice with no phone on the desk comes in on the receiver ([constant RECEIVER]): its paragraphs (unless a phone is at
## the ear: then it is somebody in the caller's room) and the lines typed in its name are heard through it, the receiver opening under them on the storm it last opened on (Io-B's crackle when it
## has not). `<!-- heard: tablet -->` on the line after a cue says what that turn is heard through, over what the desk
## works out from its phones.
##
## Redacted words, on any line of a terminal block but a said one: `NAME ........ <!-- redact: DOE, JANE -->`. The words are
## put up as any others and hidden over the camera's finished picture ([DispatchCensor]), never replaced by a word. A
## redacted character travels as itself moved into a private plane of Unicode ([constant REDACT_BASE]), so typing,
## wrapping, scrolling and a strike count it as the one character it is; the screens take it back out ([method
## unredacted]). A `type:` line is said, and the voice cannot say what is hidden: there the mark is warned of and its words
## left out.
##
## The voice opens on [constant OPENING] seconds of the desk at rest, the camera home, before any action or word. What
## moves on the radar moves under the voice: a walk is the words between a `moving` and a `ping`, and the camera turns
## to the radar at its sounds (the alarm as he sets off, the ping as he arrives). `<!-- act: ... -->` is plain words for
## a puppeteer that is not built here, and stays a note; every other comment is a note too.
##
## The desk acts in the rests the voice leaves for it: every action the voice waits for writes a rest into what it reads
## (`<!-- action-hold: S -->`), and the medium places each action in its rest ([method DispatchMedium._place]), from the
## next word back by what is written after it in the same silence.
##
## A voice through a phone is heard through one ([constant Manuscript.HEARD]): a turn of a voice whose phone is in hand
## is marked `phone`; one whose phone lies open on the desk, `desk`; a voice with no phone of its own open, `far`. Worked
## out here from the calls.

## Own-line desk marks: group 1 the verb, 2 its argument.
const MARK := "^\\s*<!--\\s*(call|/\\s*call|ring|text|reply|ping|moving|sound|static|print|sleep|off|look|lift|switch|live|strike|gain|bell|lamp|power|environment|fade|tablet|/\\s*tablet|back|new\\s+tab|replay|/\\s*image)\\s*(?::\\s*([\\s\\S]*?))?\\s*-->\\s*$"
## A moving picture: group 1 its screen and what it is told ([method _pinned]), 2 the clip's file name, 3 its words.
const VIDEO := "^\\s*<!--\\s*video\\s*\\(\\s*([a-z]+(?:\\s*,\\s*[a-z]+)*)\\s*\\)\\s*:\\s*([^|]*?)\\s*\\|\\s*([\\s\\S]*?)\\s*-->\\s*$"
## A film on a screen: group 1 its screen and what it is told ([method _pinned]), 2 what plays - a note's title, or a video file.
const PLAY := "^\\s*<!--\\s*play\\s*\\(\\s*([a-z]+(?:\\s*,\\s*[a-z]+)*)\\s*\\)\\s*:\\s*([\\s\\S]*?)\\s*-->\\s*$"
## What a film is told, after its screen and a comma (`play (terminal, mono)`): shown in the screen's own phosphor, not its colors.
const MONO := "mono"
## A picture: group 1 where (full, feed, satellite, tv; none is full) and what it is told ([method _pinned]), 2 its words.
const IMAGE := "^\\s*<!--\\s*image\\s*(?:\\(\\s*([a-z]+(?:\\s*,\\s*[a-z]+)*)\\s*\\))?\\s*:\\s*([\\s\\S]*?)\\s*-->\\s*$"
## What a picture pinned to a screen is told, after the screen and a comma (`image (feed, unwatched)`): it lands with the
## camera left on what it was on.
const UNWATCHED := "unwatched"
## ...and a film told `loop` (`play (tv, loop)`): round and round under what follows, the voice never waiting, until its screen is put
## to something else; watched as a `look:` holds, having no end to let the camera go at.
const LOOP := "loop"
## In a page fence, on a line of its own: the room's words the page is brought to that place for. Group 1 the words.
const SAID := "(?m)^[ \\t]*<!--\\s*said\\s*:\\s*([^>]*?)\\s*-->[ \\t]*$"
const FENCE_OPEN := "^\\s*```\\s*(terminal|page)\\s*$"
const FENCE_CLOSE := "^\\s*```\\s*$"
## Words redacted inside a shown block or a session: group 1 the words.
const REDACT := "<!--\\s*redact\\s*:\\s*([\\s\\S]*?)\\s*-->"
## A redacted character is itself moved up by this much (Supplementary Private Use Area-A, U+F0000-U+FFFFD).
const REDACT_BASE := 0xF0000
## Own-line marks the voice reads: a hesitation, a delivery.
const VOICE_LINE := "^\\s*(?:<!--\\s*(?:hesitation|delivery)\\b[\\s\\S]*?-->\\s*)+$"
const HESITATION := Manuscript.HESITATION
const COMMENT := Manuscript.COMMENT
## What makes a note a dispatch script: nothing is rewritten for any other.
const IS_DISPATCH := "(?m)^\\s*(?:<!--\\s*(?:call|ring|ping)\\s*:|```\\s*terminal\\s*$)"
## What a turn is heard through, said outright on the line after its cue: group 1 the band ([constant VoiceFX.HEARD]).
const HEARD_LINE := "^\\s*<!--\\s*heard\\s*:\\s*([A-Za-z_]+)\\s*-->\\s*$"

## The screens a picture may be pinned to, each a thing on the desk ([DispatchSet]); a film plays on them or on the terminal.
const SCREENS := ["feed", "satellite", "tv"]
const FILM_SCREENS := ["terminal", "feed", "satellite", "tv"]
## What a voice with no phone of its own is heard through when the room types its words: the receiver
## ([constant VoiceFX.HEARD]).
const RECEIVER := "receiver"

## The tablet (seconds): picked up and its screen woken; laid back down; a key of an address typed, then the page loading; a link
## looked at before it is tapped; a page come up looked at before anything else, or one come back to (reloaded, or by the
## back arrow). A search typed into a page's own box: the box found and tapped, the hand over the keys, its words at the
## tablet medium's pace ([method TabletScript.char_times]), then looked over before they are entered. A new tab: its plus
## tapped and the blank tab looked at. A reply typed into a page's message box: the box found and tapped before its words,
## and after them its Send pressed and the box seen empty (an action `sent`, nothing but the voice's rest for it).
const TABLET_UP := 1.2
const TABLET_DOWN := 1.8
const TABLET_KEY := 0.11
const TABLET_GO := 0.6
const TABLET_TAP := 1.4
const TABLET_LOOK := 2.5
const TABLET_AGAIN := 1.0
const TABLET_BOX := 1.2
const TABLET_HAND := 0.4
const TABLET_ENTER := 0.7
const TABLET_TAB := 1.2
const TABLET_POST := 1.8
const TABLET_SENT := REPLY_SEND + 0.6
## What stands in a page for its video player (`<!-- player -->`): a picture by this name.
const PLAYER := "\uE0F7 the video player"
## `reply:`'s word for the tablet's page, and what the walk keeps for it (no phone's label: those are in capitals).
const TABLET_REPLY := "tablet"
## What a `replay:` can play the room's earlier words through: each a band of [constant VoiceFX.HEARD] of the same name.
const REPLAY_THROUGH := ["tablet", "tv"]
## The timing of each action (seconds). `rest` is what the voice waits for it; an action may move on past its rest,
## under the next words (`len`). A phone: out of its row, opened and to the ear; dialed; the two rings in the earpiece,
## each a pair of short rings on a cycle, answered as the second's pair ends; answered at once when it was ringing;
## picked back up off the desk; the one in hand laid down open on the desk first; snapped shut and home.
const LIFT := 1.2
const DIAL := 1.3
## Speed dial, inside the dialing ([constant DIAL]): every phone's one contact is on 1 - held, then Send, and up to the ear.
const SPEED_PRESS := 0.15
const SPEED_HOLD := 0.45
const SEND_AT := 0.72
const TO_EAR := 0.5
const RING_CYCLE := 2.6
const RING_ON := 1.0
const RINGS := 2
const ANSWER := 0.35
const PICK_UP := 1.0
const LAY_DOWN := 1.0
const HANG_UP := 1.3
const HANG_UP_REST := 0.7
## An incoming ring: a buzz this long, then quiet this long, rung this many times before a call answers it, and this
## many when nobody does.
const BUZZ_ON := 0.8
const BUZZ_OFF := 0.6
const BUZZES := 2
const BUZZES_OUT := 4
## A text: its chime and buzz; the phone up out of its row and open, held to be read; long enough to read it (seconds a
## word, and a beat); and back down to its row, unless it texts again within [constant TEXT_AGAIN], when it stays up.
const TEXT_BUZZ := 0.5
const TEXT_CHIME := 0.6
const READ_LIFT := 0.9
const READ_WORD := 0.32
const READ_BEAT := 0.9
const READ_DOWN := 1.2
const TEXT_AGAIN := 9.0
## A reply, typed into the phone in hand on its keypad before it is said: a beat before its first key, its keys at a practiced
## thumb's pace on a phone's keys (characters a second, on the whole: each letter takes as long as its presses, and a hand's
## unevenness, [method key_times]), at most this long in all, and its sending once it is typed and said. An answer to it comes back no sooner than the other end could have read it,
## thought a moment and typed it back at the same pace (at most this long).
const REPLY_LEAD := 0.4
const REPLY_SEND := 0.7
const T9_RATE := 3.5
const REPLY_MOST := 18.0
const THEIRS_THINK := 2.5
## A phone's keypad: each letter, and how many presses it takes there.
const T9_KEYS := "abcdefghijklmnopqrstuvwxyz"
const T9_PRESSES := [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 4, 1, 2, 3, 1, 2, 3, 4]
const THEIRS_MOST := 16.0
## The radar's ping: the voice's rest, and its ring's length. Its alarm as the target sets off: the voice's rest, and how
## long it sounds.
const PING := 1.2
const PING_LEN := 2.6
const MOVING := 0.7
const MOVING_LEN := 1.6
## The desk at rest, seen whole before anything moves (seconds): the breath the voice opens on, every opening's settle
## ([constant Openings.SETTLE]).
const OPENING := Openings.SETTLE
## Static: a bare mark's seconds.
const STATIC_BARE := 4.0
## The printer: before its first line, a line, the feed after it; and its least and most.
const PRINT_LEAD := 0.5
const PRINT_LINE := 0.42
const PRINT_FEED := 0.8
const PRINT_LEAST := 2.4
const PRINT_MOST := 9.0
## The printer's paper is this many characters across.
const PRINT_COLUMNS := 80
## The terminal: before a said line, the camera there and the cursor waiting; the screen saver coming on.
const TYPE_LEAD := 1.0
const SLEEP := 1.2
## A said line is typed ahead of its voice, as a letter is written ahead of its reading: its first AHEAD_WORDS words in
## the rest before the voice at a typist's pace ([constant DispatchTerminal.KEY_EACH]); then the keys at least
## AHEAD_LEAST and at most AHEAD_MOST words ahead of the word being said, at the evenest pace that band allows
## ([method PenPace.taut]), so the voice reads what is already on the glass and the keys neither rush a short word nor
## crawl through a pause. A reply on a phone is typed as it is said, its keys this long before each word.
const AHEAD_WORDS := 2
const AHEAD_LEAST := 1
const AHEAD_MOST := 3
const REPLY_AHEAD := 0.35
## A block's last `key:` lines that the paragraph straight after it says are typed ahead of its words ([method said_keys]):
## said where at least SAID_LEAST of their words are, in order, the first within SAID_OPENS words of the line's start and the
## paragraph's, no more than SAID_GAP words parting two on either side (a word left out, a clause put in).
const SAID_LEAST := 3
const SAID_OPENS := 3
const SAID_GAP := 8
## What such a line types past the words said is typed on at the pace it was typed at, no quicker than this a key (s).
const KEY_LEAST := 0.04
## A strike: the writer decides (the letter's), then backspaces at this many characters a second, held to at most.
const DECIDE := 3.0
const DECIDE_MOST := 30.0
const BACKSPACE := 28.0
const BACKSPACE_MOST := 4.0
## The others: a screen going dark, a look, the switch thrown, a picture landing on a screen.
const OFF := 0.5
const LOOK := 1.0
## A thing lifted (the mug drunk from): brought up gently, carefully, as a full mug is, held at the mouth for a sip, and set back
## down as gently; the voice goes on this far into its way down.
const LIFT_UP := 2.8
const LIFT_HOLD := 3.0
const LIFT_DOWN := 2.4
const LIFT_SAID := 0.5
const SWITCH := 1.3
const SWITCH_AT := 0.65
const PICTURE := 1.6
## The letter's pictures over the whole screen: the fade (seconds), every one; the voice rests for the last to clear.
const IMAGE_FADE := 2.5
## The radar's range rings when the `desk:` block gives none (`rings:`): a ping's range is in rings, the scope's edge the
## last.
const SCOPE_RINGS := 4
## The radar's gain knob: its least and most, where it stands when the night begins; the hand reaching it, each step
## turned (a click), and the beat the voice waits after, as the sweep comes round.
const GAIN_LEAST := 1
const GAIN_MOST := 10
const GAIN_REST := 3
const GAIN_REACH := 0.25
const GAIN_STEP := 0.14
const GAIN_BEAT := 0.6
## A fade (seconds): how long the picture takes to go down or come up, bare; on the clock, the cards turning over after it
## comes up, and the beat they are held before the camera eases to the desk. A said line's time this many minutes off the
## clock is warned of, the clock's time estimated at a steady voice's pace (seconds a word).
const FADE := 2.0
const FADE_MOST := 20.0
const CLOCK_TURN := CLOCK_FLAP + 3.0 * CLOCK_STAGGER
const CLOCK_BEAT := 1.4
## A flip clock's card turning over, as a split-flap's does ([method flap_angle]): one flap's whole turn (seconds), the share
## of it at which it slaps down - falling faster all the way, as a flap let go does - and the bounce it gives (radians); each
## digit to the left trips this long after the one on its right, so four turn in [constant CLOCK_TURN].
const CLOCK_FLAP := 0.16
const CLOCK_LAND := 0.8
const CLOCK_BOUNCE := 0.2
const CLOCK_STAGGER := 0.06
const CLOCK_OFF := 5
const CLOCK_WORD := 0.42
## The terminal's bell: the half beat the voice waits for it.
const BELL := 0.35
## The lamp: the hand reaching its switch (the click), and the voice's rest.
const LAMP_AT := 0.3
const LAMP := 0.8
## The power going off (or coming back): the voice's rest - the breaker's thunk, every glass collapsing to its dot and gone.
const POWER := 1.6
## An Environment element switched on or off (`environment: beams on`): the voice's rest, and how long it takes to come up or go
## down when the mark says no seconds.
const ENVIRONMENT := 0.3
const ENVIRONMENT_FADE := 0.4
## A film coming up on its screen (`play (terminal): ...`): the glass waking (its dot opening to a line, then the picture), the
## voice's rest before the next mark; the voice waits for the rest of the film where its silence ends ([method _hold_films]).
const PLAY_LEAD := 1.2
## A sound with no row of its own: a rest this long, and nothing heard.
const SOUND_BARE := 3.0
## A hesitation that names no length, as the voice's Hesitate dial has it by default ([constant
## ReadingCast.HESITATE_DEFAULT]): what the desk counts it as between two of its own actions.
const HESITATE := 1.5
## A margin the voice's rest has past the action's own time: a breath before the next word.
const REST_PAD := 0.3

static var _re := {}


static func _rx(pattern: String) -> RegEx:
	if not _re.has(pattern):
		var r := RegEx.new()
		r.compile(pattern)
		_re[pattern] = r
	return _re[pattern]


## Does [param body] use the desk's marks at all?
static func is_dispatch(body: String) -> bool:
	return _rx(IS_DISPATCH).search(Manuscript.strip_frontmatter(body)) != null


## [param body] as the voice should read it (see the class note).
static func speakable(body: String, films := {}) -> String:
	return String(parse(body, films)["speakable"])


## How long each thing played runs, as [param films] has them (`what` -> [method ScreenPlays.record_of]): what the voice waits for,
## 0 for one whose length is not known.
static func lengths_of(films: Dictionary) -> Dictionary:
	var out := {}
	for k in films:
		out[k] = float((films[k] as Dictionary).get("secs", 0.0))
	return out


## What each `play` mark of [param body] plays (a note's title, a video file's path), once each, in order.
static func films_in(body: String) -> PackedStringArray:
	var out := PackedStringArray()
	for b in blocks(body):
		if String((b as Dictionary)["kind"]) == "play":
			var what := String((b as Dictionary)["what"])
			if not what.is_empty() and not out.has(what):
				out.append(what)
	return out


## The pictures of [param body] as the painter is handed them: every image mark pinned to the screen (painted wide;
## a desk's screen shows the middle of it), so the painting is found by its words whatever it was pinned to.
static func pictures_only(body: String) -> String:
	var src := Manuscript.strip_frontmatter(body)
	return _rx("<!--\\s*image\\s*(?:\\([^)]*\\))?\\s*:").sub(src, "<!-- image (screen):", true)


## The phones' labels, in order along the rows: the note's `desk:` block's `phones`, else every label its marks name, in
## the order they first do.
static func phones_of(body: String) -> PackedStringArray:
	var out := PackedStringArray()
	var block := FrontMatter.read_block(body, "desk")
	var listed: Variant = (block.get("data", {}) as Dictionary).get("phones", null)
	if listed is Array:
		for v in listed as Array:
			var s := String(v).strip_edges().to_upper()
			if not s.is_empty() and not out.has(s):
				out.append(s)
	if out.is_empty():
		for m in _rx("<!--\\s*(?:call|ring|text|/\\s*call)\\s*:\\s*([^|>]*?)\\s*(?:\\|[^>]*)?-->").search_all(body):
			var s := m.get_string(1).strip_edges().to_upper()
			if not s.is_empty() and not out.has(s):
				out.append(s)
	return out


## The note's `desk:` block, as written ({} for none).
static func desk_of(body: String) -> Dictionary:
	return FrontMatter.read_block(body, "desk").get("data", {})


## [param src]'s lines, a comment that runs over several lines joined into one - outside a fenced block, whose lines are
## kept as they are.
static func _logical_lines(src: String) -> PackedStringArray:
	var out := PackedStringArray()
	var held := ""
	var fenced := false
	for line in src.split("\n"):
		var s := String(line)
		if not held.is_empty():
			held += " " + s.strip_edges()
			if s.contains("-->"):
				out.append(held)
				held = ""
			continue
		if _rx(FENCE_OPEN).search(s) != null and not fenced:
			fenced = true
			out.append(s)
			continue
		if fenced:
			if _rx(FENCE_CLOSE).search(s) != null:
				fenced = false
			out.append(s)
			continue
		var open := s.rfind("<!--")
		if open >= 0 and s.find("-->", open) < 0:
			held = s
			continue
		out.append(s)
	if not held.is_empty():
		out.append(held)
	return out


## The note as blocks, in order: `{kind: "para", text}`, `{kind: "speaker", name}`, `{kind: "heard", band}`, `{kind:
## "voice", text}` (an own-line hesitation or delivery), `{kind: "mark", verb, arg}`, `{kind: "image", where, prompt}`; and
## from a terminal block `{kind: "run", lines}` (its silent steps) and `{kind: "type", text, voice, theirs}` (a said
## passage, `theirs` a `read:` one), its marks as marks. Notes are dropped.
static func blocks(body: String) -> Array:
	var src := Manuscript.strip_frontmatter(body)
	var out: Array = []
	var para := PackedStringArray()
	var fence := ""
	var fenced := PackedStringArray()
	for line in _logical_lines(src):
		var s := String(line)
		if not fence.is_empty():
			if _rx(FENCE_CLOSE).search(s) != null:
				_end_fence(out, fence, fenced)
				fence = ""
				fenced = PackedStringArray()
			else:
				fenced.append(s)
			continue
		var fo := _rx(FENCE_OPEN).search(s)
		if fo != null:
			_end_para(out, para)
			fence = fo.get_string(1)
			continue
		var b := _classify(s)
		if b.is_empty():
			para.append(s)
			continue
		_end_para(out, para)
		if not String(b["kind"]) in ["blank", "note"]:
			out.append(b)
	_end_para(out, para)
	if not fence.is_empty():
		_end_fence(out, fence, fenced)
	return out


## A fenced block's blocks: a page as one (`{kind: page, text}`); a terminal block's runs, said lines and marks
## ([method DispatchTerminal.split]).
static func _end_fence(out: Array, fence: String, lines: PackedStringArray) -> void:
	if fence == "page":
		out.append({"kind": "page", "text": "\n".join(lines)})
		return
	for item in DispatchTerminal.split("\n".join(lines)):
		var it: Dictionary = item
		if String(it["kind"]) == "line":
			var b := _classify(String(it["text"]))
			if not b.is_empty() and not String(b["kind"]) in ["blank", "note"]:
				out.append(b)
		else:
			out.append(it)


## What one line of the note is: a block ({} for a line of a paragraph; `blank` and `note` for what ends one and is
## dropped).
static func _classify(s: String) -> Dictionary:
	if s.strip_edges().is_empty():
		return {"kind": "blank"}
	var who := Manuscript.speaker_of_line(s)
	if not who.is_empty():
		return {"kind": "speaker", "name": who}
	var hd := _rx(HEARD_LINE).search(s)
	if hd != null:
		return {"kind": "heard", "band": hd.get_string(1).to_lower()}
	var m := _rx(MARK).search(s)
	if m != null:
		return {"kind": "mark", "verb": m.get_string(1).replace(" ", "").to_lower(), "arg": m.get_string(2).strip_edges()}
	var pl := _rx(PLAY).search(s)
	if pl != null:
		var on := _pinned(pl.get_string(1))
		return {"kind": "play", "where": on["where"], "told": on["told"], "what": pl.get_string(2).strip_edges()}
	var vd := _rx(VIDEO).search(s)
	if vd != null:
		var on := _pinned(vd.get_string(1))
		return {"kind": "video", "where": on["where"], "told": on["told"], "file": vd.get_string(2).strip_edges(),
			"prompt": vd.get_string(3).strip_edges()}
	var im := _rx(IMAGE).search(s)
	if im != null:
		var on := _pinned(im.get_string(1))
		var where := String(on["where"])
		return {"kind": "image", "where": where if (where in SCREENS) else "full", "told": on["told"],
			"prompt": im.get_string(2).strip_edges()}
	if _rx(VOICE_LINE).search(s) != null:
		return {"kind": "voice", "text": s.strip_edges()}
	if _rx("^\\s*<!--[\\s\\S]*?-->\\s*$").search(s) != null:
		return {"kind": "note"}
	return {}


## What a picture's parentheses say ([param said]: `feed`, `feed, unwatched`): `{where, told}` - where it is pinned, and
## each word after it.
static func _pinned(said: String) -> Dictionary:
	var parts := said.split(",", false)
	var told := PackedStringArray()
	for k in range(1, parts.size()):
		told.append(String(parts[k]).strip_edges())
	return {"where": String(parts[0]).strip_edges() if not parts.is_empty() else "", "told": told}


## Picture action [param pic] as its mark's parentheses tell it ([param told], [method _pinned]): [constant UNWATCHED]
## kept on it; any other word warned of, [param mark] saying where.
static func _tell(pic: Dictionary, told: PackedStringArray, mark: String, warnings: PackedStringArray) -> Dictionary:
	for w in told:
		if String(w) == UNWATCHED:
			pic[UNWATCHED] = true
		else:
			warnings.append("%s, %s): a picture on a screen is told %s, or nothing" % [mark, w, UNWATCHED])
	return pic


static func _end_para(out: Array, para: PackedStringArray) -> void:
	if para.is_empty():
		return
	out.append({"kind": "para", "text": "\n".join(para)})
	para.clear()


## A paragraph's spoken words, normalized - what the voice says of it ([method DeskScript._words]).
static func words_of(text: String) -> PackedStringArray:
	return DeskScript._words(text)


## A typed block as shown: its marks out and the spaces they leave closed up, line by line.
static func shown_of(text: String) -> String:
	var lines := PackedStringArray()
	for line in text.split("\n"):
		var s := _rx(COMMENT).sub(String(line), " ", true)
		lines.append(_rx(" {2,}").sub(s, " ", true).strip_edges())
	return "\n".join(lines)


## [param text] with its redact marks as the terminal holds them: each mark's words in its place, every character of them
## moved up into the private plane ([constant REDACT_BASE]) - the same length, so it is typed, wrapped and scrolled as
## written (a redacted space is no place to wrap, so a short redacted span stays on one line).
static func redacted(text: String) -> String:
	var out := ""
	var at := 0
	for m in _rx(REDACT).search_all(text):
		out += text.substr(at, m.get_start() - at)
		var words := m.get_string(1)
		for i in words.length():
			var c := words.unicode_at(i)
			out += char(REDACT_BASE + c) if c < 0xFFFE else words[i]
		at = m.get_end()
	return out + text.substr(at)


## Is character [param c] a redacted one ([method redacted])?
static func is_redacted(c: int) -> bool:
	return c >= REDACT_BASE and c < REDACT_BASE + 0xFFFE


## A line as drawn: `{text, spans: [Vector2i(c0, c1)]}` - every redacted character back as itself, and the runs of them,
## by column ([method redacted]).
static func unredacted(line: String) -> Dictionary:
	var out := ""
	var spans: Array = []
	var open := -1
	for i in line.length():
		var c := line.unicode_at(i)
		var hidden := is_redacted(c)
		if hidden and open < 0:
			open = i
		elif not hidden and open >= 0:
			spans.append(Vector2i(open, i))
			open = -1
		out += char(c - REDACT_BASE) if hidden else line[i]
	if open >= 0:
		spans.append(Vector2i(open, line.length()))
	return {"text": out, "spans": spans}


## What the voice says of a typed block [param shown], and so what its captions show: its lines run together, and a block
## set all in capitals said in sentence case (every word of two capitals or more lowered, a sentence's first raised again),
## because the voice reads a short word in capitals as an initialism ([constant TextNorm.INITIALISMS]). A block with no
## capital at all (typed as a person types to themselves) has each sentence's first letter raised and `i` made `I`: a
## small letter after a full stop continues the sentence ([method Phonemes._ends_sentence]), so as typed it would be one
## sentence to the voice and one caption too long to show. A block of both is said as written, its capitals kept (an
## initialism in a log line is one); a named letter, `[D]`, stays the letter.
static func said_of(shown: String) -> String:
	var text := " ".join(shown.split("\n", false))
	var small := text == text.to_lower()
	if not small and text != text.to_upper():
		return text
	var out := PackedStringArray()
	var opens := true
	for tok in text.split(" ", false):
		var t := String(tok)
		if small:
			if _rx("^i(?:'[a-z]+)?[.,!?;:]*$").search(t) != null:
				t = "I" + t.substr(1)
			if opens:
				t = _raised(t)
		elif _rx("[A-Z]").search_all(t).size() >= 2 and not t.begins_with("["):
			t = t.to_lower()
			if opens:
				t = _raised(t)
		out.append(t)
		opens = t.ends_with(".") or t.ends_with("!") or t.ends_with("?") or t.ends_with("]") or t.ends_with(":")
	return " ".join(out)


## [param t] with its first letter raised.
static func _raised(t: String) -> String:
	var first := _rx("[A-Za-z]").search(t)
	if first == null:
		return t
	return t.substr(0, first.get_start()) + t[first.get_start()].to_upper() + t.substr(first.get_start() + 1)


## [param glass] with the other side's typing [param shown] added under the panel up: never the room's line a strike takes off.
static func _typed_theirs(glass: Dictionary, shown: String) -> Dictionary:
	var kept: Variant = glass.get("last_typed", {})
	var g := DispatchTerminal.typed(glass, shown, shown.length())
	g["last_typed"] = kept
	return g


## A block's last `key:` lines (from [param lines], run [param bi] of [param all]) that the paragraph straight after it -
## past a voice's cue - opens by saying ([method said_after]), read on into the paragraphs after it that only a voice's cue
## parts from it (a delivery, a hesitation: their words follow on in what is said): `{at, text, spans, said}`, the line they
## begin on, the text as the glass types it (each line wrapped at [param width], parted by line breaks), each word said with
## its characters (`{c0, c1, word}`, `word` its place in those words, the first from the text's start, a word's spaces after
## it with it), and how many of those words that runs through. {} where it says none of them or anything else comes between
## (a picture: the typing stays where it is written, before it).
static func said_keys(lines: PackedStringArray, all: Array, bi: int, width: int) -> Dictionary:
	var at := lines.size()
	while at > 0:
		var m := _rx(DispatchTerminal.LINE_KIND).search(String(lines[at - 1]))
		if m == null or m.get_string(1) != "key" or not m.get_string(2).is_empty():
			break
		at -= 1
	if at == lines.size():
		return {}
	var j := bi + 1
	while j < all.size() and String((all[j] as Dictionary)["kind"]) in ["speaker", "heard"]:
		j += 1
	if j >= all.size() or String((all[j] as Dictionary)["kind"]) != "para":
		return {}
	var typed := PackedStringArray()
	for k in range(at, lines.size()):
		var said := redacted(String(_rx(DispatchTerminal.LINE_KIND).search(String(lines[k])).get_string(3)).strip_edges())
		typed.append("\n".join(DispatchTerminal.wrapped(said, width)))
	var shown := "\n".join(typed)
	var spans := typed_spans(shown)
	var tokens := PackedStringArray()
	for sp in spans:
		tokens.append(TabletScript.norm(shown.substr(int(sp["c0"]), int(sp["c1"]) - int(sp["c0"])).strip_edges()))
	var words := words_of(String((all[j] as Dictionary)["text"]))
	var q := j + 1
	while q < all.size() and words.size() < tokens.size() * 2 + SAID_GAP * 2 and String((all[q] as Dictionary)["kind"]) in ["voice", "para"]:
		if String((all[q] as Dictionary)["kind"]) == "para":
			words.append_array(words_of(String((all[q] as Dictionary)["text"])))
		q += 1
	var pairs := said_after(tokens, words)
	if pairs.is_empty():
		return {}
	var out: Array = []
	var c0 := 0
	for pr in pairs:
		var c1 := int((spans[(pr as Vector2i).x] as Dictionary)["c1"])
		out.append({"c0": c0, "c1": c1, "word": (pr as Vector2i).y})
		c0 = c1
	return {"at": at, "text": shown, "spans": out, "said": (pairs.back() as Vector2i).y + 1}


## Where typed words [param tokens] (normalized, [method TabletScript.norm]) are said in [param words] as they open:
## `[Vector2i(token, word)]`, the longest match in order, kept from its start while no more than [constant SAID_GAP] words
## part two matches on either side, and opening within [constant SAID_OPENS] words of both. [] for fewer than
## [constant SAID_LEAST]: the words say something else.
static func said_after(tokens: PackedStringArray, words: PackedStringArray) -> Array:
	var n := tokens.size()
	var m := mini(words.size(), n * 2 + SAID_GAP * 2)
	if n == 0 or m == 0:
		return []
	var dp := PackedInt32Array()
	dp.resize((n + 1) * (m + 1))
	for i in range(n - 1, -1, -1):
		for k in range(m - 1, -1, -1):
			var here := i * (m + 1) + k
			if tokens[i] == words[k]:
				dp[here] = dp[(i + 1) * (m + 1) + k + 1] + 1
			else:
				dp[here] = maxi(dp[(i + 1) * (m + 1) + k], dp[i * (m + 1) + k + 1])
	var pairs: Array = []
	var i := 0
	var k := 0
	while i < n and k < m:
		if tokens[i] == words[k] and dp[i * (m + 1) + k] == dp[(i + 1) * (m + 1) + k + 1] + 1:
			pairs.append(Vector2i(i, k))
			i += 1
			k += 1
		elif dp[(i + 1) * (m + 1) + k] >= dp[i * (m + 1) + k + 1]:
			i += 1
		else:
			k += 1
	if pairs.is_empty() or (pairs[0] as Vector2i).x > SAID_OPENS or (pairs[0] as Vector2i).y > SAID_OPENS:
		return []
	var kept: Array = [pairs[0]]
	for q in range(1, pairs.size()):
		var a: Vector2i = kept.back()
		var b: Vector2i = pairs[q]
		if b.x - a.x - 1 > SAID_GAP or b.y - a.y - 1 > SAID_GAP:
			break
		kept.append(b)
	return kept if kept.size() >= SAID_LEAST else []


## Where each spoken word of a typed block is on the screen: `[{c0, c1}]`, one a word the voice says, the characters of
## [param shown] it types - a word's spaces and line breaks after it with it, so the keys stop at a word's end.
static func typed_spans(shown: String) -> Array:
	var out: Array = []
	var toks := _rx("\\S+").search_all(shown)
	for i in toks.size():
		var m: RegExMatch = toks[i]
		if TabletScript.norm(m.get_string()).is_empty():
			if not out.is_empty():
				(out.back() as Dictionary)["c1"] = m.get_end()
			continue
		out.append({"c0": m.get_start(), "c1": m.get_end()})
	for i in out.size():
		var next := shown.length() if i == out.size() - 1 else int((out[i + 1] as Dictionary)["c0"])
		(out[i] as Dictionary)["c1"] = next
	if not out.is_empty():
		(out[0] as Dictionary)["c0"] = 0
	return out


## A typed block as the printer prints it: its lines, each cut to the paper's width.
static func printed_lines(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line in text.split("\n"):
		var s := String(line)
		if s.is_empty():
			out.append("")
		while not s.is_empty():
			out.append(s.substr(0, PRINT_COLUMNS))
			s = s.substr(PRINT_COLUMNS)
	return out


## The length of a strike's or a `decide`'s pause: the mark's number (seconds), else [constant DECIDE].
static func decide_of(arg: String) -> float:
	var a := arg.strip_edges()
	return clampf(float(a), 0.0, DECIDE_MOST) if a.is_valid_float() else DECIDE


## How long the voice waits for a static of [param arg] (`5`, `5, surf`, `5, surf, unwatched`), which storm it is, and
## whether it is [constant UNWATCHED]: heard with the camera left where it is.
static func static_of(arg: String) -> Dictionary:
	var parts := arg.split(",", false)
	var secs := STATIC_BARE
	var kind := "popcorn"
	var unwatched := false
	for p in parts:
		var s := String(p).strip_edges().to_lower()
		if s.is_valid_float():
			secs = clampf(float(s), 0.5, 60.0)
		elif DispatchSounds.STORMS.has(s):
			kind = s
		elif s == UNWATCHED:
			unwatched = true
	return {"secs": secs, "kind": kind, UNWATCHED: unwatched}


## Where a `gain:` mark turns the knob: its number, held to [constant GAIN_LEAST]-[constant GAIN_MOST]; -1 for no number.
static func gain_of(arg: String) -> int:
	var a := arg.strip_edges()
	return clampi(roundi(float(a)), GAIN_LEAST, GAIN_MOST) if a.is_valid_float() else -1


## How long the gain knob takes to turn from [param from] to [param to]: [constant GAIN_STEP] a step.
static func gain_turn(from: int, to: int) -> float:
	return GAIN_STEP * float(absi(to - from))


## Which sound a `sound:` mark's words name: its first part if that is a key of [constant DispatchSounds.SOUNDS], else
## the first key the words say; "" for none.
static func sound_of(arg: String) -> String:
	var head := arg.get_slice(",", 0).strip_edges().to_lower()
	if DispatchSounds.SOUNDS.has(head):
		return head
	var words := " " + _rx("[^a-z]+").sub(arg.to_lower(), " ", true) + " "
	for k in DispatchSounds.SOUNDS:
		if words.contains(" %s " % String(k)):
			return String(k)
	return ""


## A label as the phones are labeled: capitals, trimmed.
static func label_of(s: String) -> String:
	return s.strip_edges().to_upper()


## The whole note, walked: `{speakable, spoken, actions, spans, phones, room, warnings, terminal (its config), pages (the
## tablet's fences), tablet (those pages as the tablet medium reads them, [method browsing]), dark (it opens in the black),
## rings, heard (each run of words heard through something: `{band, from, to}` in spoken words)}`.
##
## `actions`, in order, are each `{kind, after, rest, len, fwd, back, ...}`: `after` the spoken word it comes before (its
## count of words before it), `rest` what the voice waits for it, `len` how long it moves, and where it falls in its
## silence - `fwd` the seconds written into the silence before it (hesitations and the rests of the actions before it),
## `back` after it. A said line is an action too (its `rest` the lead before its words), with `from` and `to` its
## spoken words and `spans` where each is on the screen ([method typed_spans]); every action at the terminal carries the
## `glass` it starts from. `spans` are the pictures over the whole
## screen: `{key, prompt, from, to, blend}` in spoken words.
static func parse(body: String, films := {}) -> Dictionary:
	var phones := phones_of(body)
	var spoken := PackedStringArray()
	var speak := PackedStringArray()      # the voice's text, a block a line apart
	var actions: Array = []
	var spans: Array = []
	var heard_runs: Array = []            # the runs of words heard through something: {band, from, to}
	var warnings := PackedStringArray()
	var room := ""
	var speaker := ""                     # whose turn the next words are
	var said_as := ""                     # the speaker cue last written into the voice's text
	var heard_as := ""                    # ...and what it was heard through
	var said_any := false
	var in_hand := ""                     # the phone held to the ear
	var held: Array = []                  # the phones lying open on the desk, in the order they were laid down
	var ringing := ""                     # the phone that rang last, until a call answers it or words go by
	var gap: Array = []                   # this silence's rests in order: [seconds, action index or -1]
	var pending := PackedStringArray()    # voice marks and rests waiting for the next words
	var typed: Array = []                 # typed block action indices since the last print
	var last_typed := -1
	var open_image := -1                  # the picture over the whole screen still up (an index into spans)
	var last_text := ""                   # the phone that texted last
	var reply_to := ""                    # the phone the room's next words are typed into
	var replied := {}                     # a phone the room has just sent a reply to, whose next text answers it
	var gain := GAIN_REST                 # where the radar's gain knob stands
	var storm := "popcorn"                # the storm the receiver last opened on
	var term := DispatchTerminal.config_of(body)
	var glass := DispatchTerminal.blank() # the terminal's glass as the script has left it
	var told := ""                        # what this turn is heard through, said outright (`heard:`)
	var placed := {}                      # the places a ping has given a bearing and range
	var all := blocks(body)
	var dark := _opens_dark(all)          # in the black (before a fade up, or between two fades): what is marked happens at once
	var hush_from := -1                   # ...the first action made in the black not yet hushed
	var jump := false                     # come back up from the black: the next ping has no track
	var tablet_up := false                # the tablet held up
	var pages: Array = []                 # the tablet's pages, in order: {url, search, text}
	var on_page := -1                     # the page up on the tablet (-1 a blank tab)
	var tabs: Array = [-1]                # the page up in each of the tablet's tabs
	var shown_by := {}                    # a page -> the action that last had it up
	var posted := {}                      # the addresses whose page takes a reply
	var tablet := browsing(all)           # the tablet's pages as the tablet medium reads them, each block given its step
	if not dark:
		gap.append([OPENING, -1])
		pending.append("<!-- action-hold: %s -->" % String.num(OPENING, 2))
	var bi := -1
	for b in all:
		var blk: Dictionary = b
		bi += 1
		if hush_from >= 0:
			_hush(actions, gap, pending, hush_from)
			hush_from = actions.size()
		match String(blk["kind"]):
			"speaker":
				speaker = String(blk["name"])
				told = ""
				if room.is_empty():
					room = speaker
			"heard":
				told = String(blk["band"])
				if not VoiceFX.HEARD.has(told):
					warnings.append("heard: %s is no band (%s)" % [told, ", ".join(PackedStringArray(VoiceFX.HEARD.keys()))])
					told = ""
			"voice":
				var t := String(blk["text"])
				pending.append(t)
				for m in _rx(HESITATION).search_all(t):
					var v := m.get_string(1) if not m.get_string(1).is_empty() else m.get_string(2)
					gap.append([float(v) if not v.is_empty() else HESITATE, -1])
			"image":
				var where := String(blk["where"])
				var prompt := String(blk["prompt"])
				if where == "full":
					for w in blk["told"]:
						warnings.append("image (full, %s): only a picture on a screen of the desk (%s) is told anything" % [w, ", ".join(PackedStringArray(SCREENS))])
					var blend := open_image >= 0
					if open_image >= 0:
						(spans[open_image] as Dictionary)["to"] = spoken.size()
					spans.append({"kind": "image", "key": Manuscript.image_key(prompt), "prompt": prompt,
						"from": spoken.size(), "to": -1, "blend": blend or _ends_at(spans, spoken.size()), "acts": actions.size()})
					open_image = spans.size() - 1
				else:
					_act(actions, gap, pending, spoken.size(), _tell({"kind": "picture", "screen": where,
						"key": Manuscript.image_key(prompt), "prompt": prompt}, blk["told"], "image (%s" % where, warnings), PICTURE, PICTURE)
			"video":
				var where := String(blk["where"])
				if not where in SCREENS:
					warnings.append("video (%s): a clip plays on a screen of the desk (%s)" % [where, ", ".join(PackedStringArray(SCREENS))])
					continue
				var prompt := String(blk["prompt"])
				_act(actions, gap, pending, spoken.size(), _tell({"kind": "picture", "screen": where, "key": Manuscript.image_key(prompt),
					"prompt": prompt, "clip": String(blk["file"])}, blk["told"], "video (%s" % where, warnings), PICTURE, PICTURE)
			"play":
				var where := String(blk["where"])
				var what := String(blk["what"])
				if not where in FILM_SCREENS:
					warnings.append("play (%s): a film plays on a screen of the desk (%s)" % [where, ", ".join(PackedStringArray(FILM_SCREENS))])
					continue
				if what.is_empty():
					warnings.append("play (%s): a note's title or a video file to play" % where)
					continue
				var film: Dictionary = films.get(what, {})
				var secs := float(film.get("secs", 0.0))
				if not bool(film.get("ready", false)):
					var why := String(film.get("why", ""))
					warnings.append("play (%s): %s - %s%s" % [where, what, why if not why.is_empty() else "nothing found by that name",
						"" if secs > 0.0 else ", so the voice does not wait for it"])
				var playing := {"kind": "play", "screen": where, "what": what, "secs": secs}
				for w in blk["told"]:
					if String(w) == MONO:
						playing[MONO] = true
					elif String(w) == UNWATCHED:
						playing[UNWATCHED] = true
					elif String(w) == LOOP:
						playing[LOOP] = true
					else:
						warnings.append("play (%s, %s): a film is told %s, %s or %s, or nothing" % [where, w, MONO, UNWATCHED, LOOP])
				_act(actions, gap, pending, spoken.size(), playing, PLAY_LEAD, PLAY_LEAD if bool(playing.get(LOOP, false)) else maxf(secs, PLAY_LEAD))
			"page":
				var pg := page_of(String(blk["text"]))
				if String(pg["url"]).is_empty():
					warnings.append("page: its first line is url: or search: (%s)" % String(blk["text"]).get_slice("\n", 0))
					continue
				if not tablet_up:
					warnings.append("page: %s with the tablet down (<!-- tablet --> picks it up)" % String(pg["url"]))
				var step: Dictionary = blk.get("step", {})
				var p := int(step.get("page", pages.size()))
				pg["url"] = String(((tablet["pages"] as Array)[p] as Dictionary)["url"]) if p < (tablet["pages"] as Array).size() else String(pg["url"])
				var how := "type"
				var entered := String(pg["url"])
				match String(step.get("kind", "")):
					"link":
						how = "tap"
					"search":
						how = "search"
						entered = String(pg["search"])
				if bool(step.get("again", false)):
					how = "again"
				var bar := how == "type" or (how == "search" and bool(step.get("bar", true)))
				var rest := page_rest(how, entered, bar)
				var tab := int(step.get("tab", tabs.size() - 1))
				while tabs.size() <= tab:
					tabs.append(-1)
				tabs[tab] = p
				shown_by[p] = _act(actions, gap, pending, spoken.size(), {"kind": "page", "page": p, "url": String(pg["url"]), "how": how,
					"text": entered, "bar": bar, "tab": tab, "tabs": tabs.duplicate(), "behind": int(step.get("behind", 0)),
					"said": blk.get("said", [])}, rest, rest)
				on_page = p
				pages.append(pg)
			"run":
				# its last key: lines, where the paragraph straight after says them, are typed ahead of those words instead
				var keys := said_keys(blk["lines"], all, bi, int(term["width"]))
				var lines: PackedStringArray = blk["lines"]
				if not keys.is_empty():
					lines = lines.slice(0, int(keys["at"]))
				var run := DispatchTerminal.compile(lines, glass, term, warnings)
				if not (run["ops"] as Array).is_empty():
					# a line typed straight after it is typed once the panel is read: the voice waits for the read too, and for a
					# while longer where that line chooses one of the panel's options - it is thought over
					var then_typed := not keys.is_empty() or (bi + 1 < all.size() and String((all[bi + 1] as Dictionary).get("kind", "")) == "type")
					var waits := float(run["len"]) if then_typed else float(run["rest"])
					if keys.is_empty() and then_typed and DispatchTerminal.choice_row(run["glass"], shown_of(String((all[bi + 1] as Dictionary)["text"]))) >= 0:
						waits += DispatchTerminal.CHOICE_THINK
					_act(actions, gap, pending, spoken.size(), {"kind": "session", "ops": run["ops"], "glass": glass}, waits,
						maxf(float(run["len"]), waits))
					glass = run["glass"]
					ringing = ""
				if not keys.is_empty():
					var shown := String(keys["text"])
					var from := spoken.size()
					var kspans: Array = keys["spans"]
					for sp in kspans:
						(sp as Dictionary)["word"] = from + int((sp as Dictionary)["word"])
					var lead_c := int((kspans[mini(AHEAD_WORDS, kspans.size()) - 1] as Dictionary)["c1"])
					var lead := TYPE_LEAD + DispatchTerminal.KEY_EACH * float(lead_c)
					_act(actions, gap, pending, from, {"kind": "type", "text": shown, "from": from, "to": from + int(keys["said"]),
						"spans": kspans, "glass": glass, "theirs": true}, lead, lead)
					glass = _typed_theirs(glass, shown)
					ringing = ""
			"crash":
				# the program dies on its words (silently as a step of a block; here in a voice that says them over it)
				var text := String(blk["text"])
				var run := DispatchTerminal.compile(PackedStringArray(["crash: " + text]), glass, term, warnings)
				var voice := String(blk["voice"])
				var who := voice if voice != room and not room.is_empty() else (room if not room.is_empty() else speaker)
				var heard := ""
				if who != room:
					heard = RECEIVER if on_receiver(voice, room, phones) else _heard(voice, room, in_hand, held)
				var said := said_of(shown_of(text))
				var words := words_of(said)
				var crashed := {"kind": "session", "ops": run["ops"], "glass": glass}
				if heard == RECEIVER:
					# the receiver opens under the words, the camera kept on the glass
					crashed.merge({"heard": RECEIVER, "storm": storm, "from": spoken.size(), "to": spoken.size() + words.size()})
				_act(actions, gap, pending, spoken.size(), crashed, float(run["rest"]), float(run["len"]))
				glass = run["glass"]
				_hold_films(actions, gap, pending)
				_flush(speak, pending, who, heard, said_as, heard_as)
				said_as = who
				heard_as = heard
				speak.append(said)
				spoken.append_array(words)
				said_any = said_any or not words.is_empty()
				gap = []
				ringing = ""
			"type":
				var raw := String(blk["text"])
				var voice := String(blk.get("voice", ""))
				if _rx(REDACT).search(raw) != null:
					warnings.append("redact: a type: line is said, so its redacted words are left out (redact on a line that is not said)")
				var shown := "\n".join(DispatchTerminal.wrapped(shown_of(raw), int(term["width"])))
				var who := room if not room.is_empty() else speaker
				var heard := ""
				if not voice.is_empty() and voice != room:
					who = voice
					heard = RECEIVER if on_receiver(voice, room, phones) else _heard(voice, room, in_hand, held)
				_hold_films(actions, gap, pending)
				_flush(speak, pending, who, heard, said_as, heard_as)
				said_as = who
				heard_as = heard
				var voice_text := said_of(shown)
				var words := words_of(voice_text)
				var keyed := typed_spans(shown)
				var from := spoken.size()
				var ahead := TYPE_LEAD + DispatchTerminal.KEY_EACH * float(int((keyed[mini(AHEAD_WORDS, keyed.size()) - 1] as Dictionary)["c1"])) \
					if not keyed.is_empty() else TYPE_LEAD
				var theirs := bool(blk.get("theirs", false))
				var typed_as := {"kind": "type", "text": shown, "from": from, "to": from + words.size(), "spans": keyed, "glass": glass,
					"theirs": theirs}
				if heard == RECEIVER:
					typed_as["heard"] = RECEIVER
					typed_as["storm"] = storm
				var chose := DispatchTerminal.choice_row(glass, shown) >= 0
				glass = _typed_theirs(glass, shown) if theirs else DispatchTerminal.typed(glass, shown, shown.length())
				var i := _act(actions, gap, pending, from, typed_as, ahead, ahead)
				_hold_films(actions, gap, pending)
				_flush(speak, pending, who, heard, said_as, heard_as)
				speak.append(voice_text)
				spoken.append_array(words)
				said_any = said_any or not words.is_empty()
				gap = []
				# a read line is the other side's typing: the printer and a strike are the room's own
				if not theirs:
					typed.append(i)
					last_typed = i
				ringing = ""
				# a choice stays in sight a while once it is made: the camera holds on the terminal before what follows
				if chose:
					_act(actions, gap, pending, spoken.size(), {"kind": "look", "at": "terminal"}, DispatchTerminal.CHOICE_HOLD,
						DispatchTerminal.CHOICE_HOLD)
			"para":
				var text := String(blk["text"])
				var who := speaker if not speaker.is_empty() else Manuscript.NARRATOR
				if room.is_empty():
					room = who
				var heard := told
				if heard.is_empty():
					# a voice with no phone of its own: somebody in the caller's room while a phone is at the ear, else the
					# receiver
					heard = RECEIVER if on_receiver(who, room, phones) and in_hand.is_empty() else _heard(who, room, in_hand, held)
				if who != room and heard.is_empty():
					warnings.append("%s speaks with no phone open: heard in the room" % who)
				if heard == RECEIVER:
					var wn := words_of(text).size()
					_act(actions, gap, pending, spoken.size(), {"kind": "receiver", "heard": RECEIVER, "storm": storm,
						"from": spoken.size(), "to": spoken.size() + wn}, 0.0, 0.0)
				var posting := reply_to == TABLET_REPLY and who == room
				if posting and on_page < 0:
					warnings.append("reply: tablet with no page up on it")
					posting = false
					reply_to = ""
				if posting:
					var shown := " ".join(text.split("\n", false))
					var wn := words_of(text).size()
					_act(actions, gap, pending, spoken.size(), {"kind": "post", "page": on_page, "text": shown, "from": spoken.size(),
						"to": spoken.size() + wn, "spans": typed_spans(shown)}, TABLET_POST, TABLET_POST)
					posted[TabletScript.url_key(String((pages[on_page] as Dictionary)["url"]))] = true
					reply_to = ""
				elif not reply_to.is_empty() and who == room:
					var shown := " ".join(text.split("\n", false))
					var wn := words_of(text).size()
					var typing := reply_typing(shown)
					_act(actions, gap, pending, spoken.size(), {"kind": "reply", "label": reply_to, "text": shown, "from": spoken.size(),
						"to": spoken.size() + wn, "spans": typed_spans(shown)}, REPLY_LEAD + typing, REPLY_LEAD + typing)
					replied[reply_to] = true
					reply_to = ""
				_hold_films(actions, gap, pending)
				_flush(speak, pending, who, heard, said_as, heard_as)
				said_as = who
				heard_as = heard
				speak.append(text)
				var words := words_of(text)
				spoken.append_array(words)
				said_any = said_any or not words.is_empty()
				if not heard.is_empty() and not words.is_empty():
					var run: Dictionary = heard_runs.back() if not heard_runs.is_empty() else {}
					if String(run.get("band", "")) == heard and int(run["to"]) == spoken.size() - words.size():
						run["to"] = spoken.size()
					else:
						heard_runs.append({"band": heard, "from": spoken.size() - words.size(), "to": spoken.size()})
				if not words.is_empty():
					gap = []
					ringing = ""
				if posting:
					# said and typed, it is sent: the voice waits for that before anything else happens on the page
					_act(actions, gap, pending, spoken.size(), {"kind": "sent"}, TABLET_SENT, TABLET_SENT)
			"mark":
				var verb := String(blk["verb"])
				var arg := String(blk["arg"])
				var at := spoken.size()
				match verb:
					"call":
						var label := label_of(arg)
						if not phones.has(label):
							warnings.append("call: %s is no phone on the desk" % label)
							phones.append(label)
						if label == in_hand:
							continue
						var rest := 0.0
						var parts: Array = []
						if not in_hand.is_empty():
							parts.append({"label": in_hand, "move": "lay_down", "at": 0.0})
							held.append(in_hand)
							rest += LAY_DOWN
						var how := "dial"
						if held.has(label):
							how = "pick_up"
							held.erase(label)
						elif ringing == label:
							how = "answer"
						var own := float({"pick_up": PICK_UP, "answer": LIFT + ANSWER}.get(how, LIFT + DIAL + _rung()))
						parts.append({"label": label, "move": how, "at": rest})
						rest += float(own)
						in_hand = label
						ringing = ""
						_act(actions, gap, pending, at, {"kind": "call", "label": label, "how": how, "parts": parts}, rest, rest)
					"/call":
						var label := label_of(arg) if not arg.is_empty() else in_hand
						if label.is_empty():
							warnings.append("/call with no phone in hand")
							continue
						if label == in_hand:
							in_hand = ""
						elif held.has(label):
							held.erase(label)
						else:
							warnings.append("/call: %s is not open" % label)
							continue
						_act(actions, gap, pending, at, {"kind": "hang_up", "label": label}, HANG_UP_REST, HANG_UP)
					"ring":
						var label := label_of(arg)
						if not phones.has(label):
							warnings.append("ring: %s is no phone on the desk" % label)
							phones.append(label)
						ringing = label
						var cycle := BUZZ_ON + BUZZ_OFF
						_act(actions, gap, pending, at, {"kind": "ring", "label": label}, cycle * BUZZES, cycle * BUZZES_OUT)
					"text":
						var label := label_of(arg.get_slice("|", 0))
						var words := arg.get_slice("|", 1).strip_edges() if arg.contains("|") else ""
						if not phones.has(label):
							warnings.append("text: %s is no phone on the desk" % label)
							phones.append(label)
						var rest := TEXT_CHIME + READ_LIFT + READ_WORD * float(words.split(" ", false).size()) + READ_BEAT
						# an answer to what was just sent: not before the other end could have typed it back
						if replied.has(label):
							var theirs := answer_wait(words)
							gap.append([theirs, -1])
							pending.append("<!-- action-hold: %s -->" % String.num(theirs, 2))
							replied.erase(label)
						_act(actions, gap, pending, at, {"kind": "text", "label": label, "words": words}, rest, rest + READ_DOWN)
						last_text = label
					"reply":
						if arg.strip_edges().to_lower() == TABLET_REPLY and not phones.has(label_of(arg)):
							if not tablet_up or on_page < 0:
								warnings.append("reply: tablet with no page up on it")
								continue
							reply_to = TABLET_REPLY
							continue
						var label := label_of(arg) if not arg.is_empty() else last_text
						if label.is_empty():
							warnings.append("reply with no text to answer")
							continue
						reply_to = label
					"ping":
						var stop := ping_of(arg)
						if float(stop["travel"]) > 0.0:
							warnings.append("ping: %s - seconds are not read; mark where he sets off with <!-- moving -->" % arg)
						if bool(stop.get("bad", false)):
							warnings.append("ping: %s - after the bar, a bearing in degrees and a range in rings: | 110, 2.9" % arg)
						var key := String(stop["place"]).to_lower()
						if float(stop["range"]) < INF:
							placed[key] = true
						elif not placed.has(key) and not placed.has(key.get_slice(",", 0).strip_edges()):
							warnings.append("ping: %s has no bearing and range (| 110, 2.9): laid out from its words" % String(stop["place"]))
							placed[key] = true
						_act(actions, gap, pending, at, {"kind": "ping", "place": String(stop["place"]), "bearing": float(stop["bearing"]),
							"range": float(stop["range"]), "jump": jump}, PING, PING_LEN)
						jump = false
					"moving":
						# straight after a ping, in the same silence: he passes through it and goes on - no alarm, no wait
						var passing := not gap.is_empty() and int((gap.back() as Array)[1]) >= 0 \
							and String((actions[int((gap.back() as Array)[1])] as Dictionary)["kind"]) == "ping"
						_act(actions, gap, pending, at, {"kind": "moving", "passing": passing}, 0.0 if passing else MOVING, MOVING_LEN)
					"sound":
						var key := sound_of(arg)
						var secs := float(DispatchSounds.SOUNDS[key]["secs"]) if not key.is_empty() else SOUND_BARE
						_act(actions, gap, pending, at, {"kind": "sound", "sound": key, "words": arg}, secs, secs)
					"static":
						var st := static_of(arg)
						storm = String(st["kind"])
						_act(actions, gap, pending, at, {"kind": "static", "storm": st["kind"], UNWATCHED: bool(st[UNWATCHED])},
							float(st["secs"]), float(st["secs"]))
					"print":
						var text := PackedStringArray()
						for k in typed:
							var a: Dictionary = actions[int(k)]
							if not bool(a.get("struck", false)):
								text.append(String(a["text"]))
						typed = []
						if text.is_empty():
							text.append(plain("\n".join(DispatchTerminal.up(glass).get("body", PackedStringArray()))))
						var lines := printed_lines("\n\n".join(text))
						var secs := clampf(PRINT_LEAD + PRINT_LINE * float(lines.size()) + PRINT_FEED, PRINT_LEAST, PRINT_MOST)
						_act(actions, gap, pending, at, {"kind": "print", "lines": lines}, secs, secs)
					"sleep":
						_act(actions, gap, pending, at, {"kind": "sleep", "glass": glass}, SLEEP, SLEEP)
						glass = glass.duplicate()
						glass["awake"] = false
					"off":
						var screen := arg.strip_edges().to_lower()
						if not screen in SCREENS:
							warnings.append("off: %s is no screen" % screen)
							continue
						_act(actions, gap, pending, at, {"kind": "off", "screen": screen}, OFF, OFF)
					"look":
						_act(actions, gap, pending, at, {"kind": "look", "at": arg.strip_edges().to_lower()}, LOOK, LOOK)
					"lift":
						_act(actions, gap, pending, at, {"kind": "lift", "thing": arg.strip_edges().to_lower()},
							LIFT_UP + LIFT_HOLD + LIFT_DOWN * LIFT_SAID, LIFT_UP + LIFT_HOLD + LIFT_DOWN)
					"switch":
						_act(actions, gap, pending, at, {"kind": "switch", "side": arg.strip_edges().to_upper()}, SWITCH, SWITCH)
					"live":
						var screen := arg.get_slice(",", 0).strip_edges().to_lower()
						if not screen in SCREENS and screen != "tablet":
							warnings.append("live: %s is no screen" % screen)
							continue
						if screen == "tablet" and not tablet_up:
							warnings.append("live: tablet with the tablet down")
						_act(actions, gap, pending, at, {"kind": "live", "screen": screen}, PICTURE, PICTURE)
					"strike":
						if last_typed < 0:
							warnings.append("strike with nothing typed")
							continue
						var a: Dictionary = actions[last_typed]
						a["struck"] = true
						var wait := decide_of(arg)
						var back := minf(float(String(a["text"]).length()) / BACKSPACE, BACKSPACE_MOST)
						_act(actions, gap, pending, at, {"kind": "strike", "block": last_typed, "decide": wait, "glass": glass},
							wait + back, wait + back)
						glass = DispatchTerminal.struck(glass, 1.0)
						last_typed = -1
					"gain":
						var to := gain_of(arg)
						if to < 0:
							warnings.append("gain: %s is no number from %d to %d" % [arg, GAIN_LEAST, GAIN_MOST])
							continue
						var turned := GAIN_REACH + gain_turn(gain, to)
						_act(actions, gap, pending, at, {"kind": "gain", "from": gain, "to": to}, turned + GAIN_BEAT, turned + GAIN_BEAT)
						gain = to
					"bell":
						_act(actions, gap, pending, at, {"kind": "bell"}, BELL, BELL)
					"tablet":
						if tablet_up:
							warnings.append("tablet: it is already up")
							continue
						tablet_up = true
						_act(actions, gap, pending, at, {"kind": "tablet", "up": true}, TABLET_UP, TABLET_UP)
					"/tablet":
						if not tablet_up:
							warnings.append("/tablet: it is not up")
							continue
						tablet_up = false
						_act(actions, gap, pending, at, {"kind": "tablet", "up": false}, TABLET_DOWN, TABLET_DOWN)
					"back", "newtab":
						var said := "back" if verb == "back" else "new tab"
						if not tablet_up:
							warnings.append("%s: the tablet is down (<!-- tablet --> picks it up)" % said)
							continue
						var step: Dictionary = blk.get("step", {})
						if step.is_empty():
							# a new tab on a tablet with nothing open yet is the blank tab it wakes on
							if verb == "back":
								warnings.append("back: nothing behind the page up in this tab")
							continue
						var tab := int(step.get("tab", tabs.size() - 1))
						while tabs.size() <= tab:
							tabs.append(-1)
						if verb == "back":
							var p := int(step["page"])
							tabs[tab] = p
							var resume := int(shown_by.get(p, -1))
							shown_by[p] = _act(actions, gap, pending, at, {"kind": "page", "page": p, "url": String((pages[p] as Dictionary)["url"]),
								"how": "back", "text": "", "bar": false, "tab": tab, "tabs": tabs.duplicate(), "behind": int(step.get("behind", 0)),
								"resume": resume}, TABLET_AGAIN, TABLET_AGAIN)
							on_page = p
						else:
							tabs[tab] = -1
							_act(actions, gap, pending, at, {"kind": "page", "page": -1, "url": "", "how": "tab", "text": "", "bar": true,
								"tab": tab, "tabs": tabs.duplicate(), "behind": 0}, TABLET_TAB, TABLET_TAB)
							on_page = -1
					"replay":
						var where := arg.get_slice("|", 0).strip_edges().to_lower()
						var said := arg.get_slice("|", 1).strip_edges() if arg.contains("|") else ""
						var words := words_of(said)
						if not where in REPLAY_THROUGH or words.is_empty():
							warnings.append("replay: %s - what plays them (%s) and the words: replay: tablet | words" % [arg, ", ".join(PackedStringArray(REPLAY_THROUGH))])
							continue
						if TabletScript.find_run(spoken, words) < 0:
							warnings.append("replay: \"%s\" was not said before it" % said)
						var who := room if not room.is_empty() else speaker
						_act(actions, gap, pending, at, {"kind": "replay", "from": spoken.size(), "to": spoken.size() + words.size()}, 0.0, 0.0)
						_hold_films(actions, gap, pending)
						_flush(speak, pending, who, where, said_as, heard_as)
						said_as = who
						heard_as = where
						speak.append(said)
						spoken.append_array(words)
						said_any = true
						gap = []
					"fade":
						var f := fade_of(arg)
						if f.is_empty():
							warnings.append("fade: %s - to-black or from-black, a time and seconds after it" % arg)
							continue
						var down := bool(f["to"])
						if down == dark:
							warnings.append("fade: %s while the picture is %s" % [arg, "black" if dark else "up"])
						if not down and hush_from >= 0:
							_hush(actions, gap, pending, hush_from)
							hush_from = -1
						var secs := float(f["secs"])
						var turned := CLOCK_TURN + CLOCK_BEAT if int(f["clock"]) >= 0 else 0.0
						if down and int(f["clock"]) >= 0:
							warnings.append("fade: %s - the clock is shown coming up from black" % arg)
						_act(actions, gap, pending, at, {"kind": "fade", "to": down, "secs": secs, "clock": int(f["clock"]) if not down else -1},
							secs + (0.0 if down else turned), secs + (0.0 if down else turned))
						dark = down
						jump = jump or not down
						hush_from = actions.size() if down else -1
					"lamp":
						var said := arg.strip_edges().to_lower()
						if not said in ["on", "off"]:
							warnings.append("lamp: %s - the lamp is on or off" % said)
							continue
						_act(actions, gap, pending, at, {"kind": "lamp", "on": said == "on"}, LAMP, LAMP)
					"power":
						var said := arg.strip_edges().to_lower()
						if not said in ["on", "off"]:
							warnings.append("power: %s - the power is on or off" % said)
							continue
						_act(actions, gap, pending, at, {"kind": "power", "on": said == "on"}, POWER, POWER)
					"environment":
						var env := environment_of(arg)
						if (env["set"] as Dictionary).is_empty():
							warnings.append("environment: %s - elements to switch, each on or off (beams on, shafts off), and seconds" % arg)
							continue
						for bad in env["bad"]:
							warnings.append("environment: %s - an element's kind or name, then on or off" % bad)
						_act(actions, gap, pending, at, {"kind": "environment", "set": env["set"], "secs": env["secs"]}, ENVIRONMENT,
							maxf(ENVIRONMENT, float(env["secs"])))
					"/image":
						if open_image >= 0:
							(spans[open_image] as Dictionary)["to"] = at
							open_image = -1
							_act(actions, gap, pending, at, {"kind": "clear"}, IMAGE_FADE + 0.1, IMAGE_FADE + 0.1)
	if hush_from >= 0:
		_hush(actions, gap, pending, hush_from)
	if dark:
		warnings.append("fade: the note ends in the black")
	if tablet_up:
		warnings.append("tablet: still up at the end (<!-- /tablet --> puts it down)")
	if open_image >= 0:
		(spans[open_image] as Dictionary)["to"] = spoken.size()
	if in_hand != "" or not held.is_empty():
		warnings.append("left open at the end: %s" % ", ".join(PackedStringArray(([in_hand] if not in_hand.is_empty() else []) + held)))
	_hold_films(actions, gap, pending)
	if not pending.is_empty():
		if speak.is_empty() or not said_any:
			speak.append(" ".join(pending))
		else:
			speak[speak.size() - 1] = String(speak[speak.size() - 1]) + " " + " ".join(pending)
	_silences(actions)
	warnings.append_array(_clock_check(actions, spoken.size()))
	if not reply_to.is_empty():
		warnings.append("reply: no words of the room's after it to type")
	# a page that takes a reply has its message box, each time it comes up
	for pg in tablet["pages"]:
		if posted.has(TabletScript.url_key(String((pg as Dictionary)["url"]))):
			(pg as Dictionary)["reply"] = true
	var rings: Variant = desk_of(body).get("rings", SCOPE_RINGS)
	return {"speakable": "\n\n".join(speak), "spoken": spoken, "actions": actions, "spans": spans,
		"phones": phones, "room": room, "warnings": warnings, "terminal": term, "pages": pages, "tablet": tablet, "dark": _opens_dark(all), "heard": heard_runs,
		"rings": maxf(float(rings), 1.0) if str(rings).is_valid_float() else float(SCOPE_RINGS)}


## How long a dialed phone rings in the earpiece before it is answered: [constant RINGS] rings' cycles, answered as the
## last one's pair of rings ends.
static func _rung() -> float:
	return RING_CYCLE * float(RINGS - 1) + RING_ON + ANSWER


## A ping's words: `{place, bearing, range, travel, bad?}` - a comma inside the place kept (`the store, aisle seven`); after
## a bar, its bearing (degrees clockwise from the scope's top) and range (range rings from the desk), INF without (`bad` for
## a bar with no such numbers); a number after its place's last comma is taken off it (`travel`) and not read - where he
## sets off is a `moving` mark - so the parse can say so.
static func ping_of(arg: String) -> Dictionary:
	var place := arg.strip_edges()
	var out := {"bearing": INF, "range": INF, "travel": 0.0}
	if place.contains("|"):
		var m := _rx("^\\s*(?:bearing\\s+)?(-?[0-9]+(?:\\.[0-9]+)?)\\s*,\\s*(?:range\\s+)?([0-9]+(?:\\.[0-9]+)?)\\s*$") \
			.search(place.get_slice("|", 1).to_lower())
		if m != null:
			out["bearing"] = fposmod(float(m.get_string(1)), 360.0)
			out["range"] = float(m.get_string(2))
		else:
			out["bad"] = true
		place = place.get_slice("|", 0).strip_edges()
	var cut := place.rfind(",")
	if cut >= 0:
		var m := _rx("^\\s*([0-9]+(?:\\.[0-9]+)?)\\s*(?:s|secs?|seconds)?\\s*$").search(place.substr(cut + 1))
		if m != null:
			out["travel"] = float(m.get_string(1))
			place = place.substr(0, cut).strip_edges()
	out["place"] = place
	return out


## A fade's words: `{to (bool), secs, clock (minutes into the day, -1 for none)}`; {} when it is neither way.
static func fade_of(arg: String) -> Dictionary:
	var out := {"secs": FADE, "clock": -1}
	var parts := arg.split(",", false)
	if parts.is_empty():
		return {}
	var way := String(parts[0]).strip_edges().to_lower().replace(" ", "-")
	if not way in ["to-black", "from-black"]:
		return {}
	out["to"] = way == "to-black"
	for k in range(1, parts.size()):
		var p := String(parts[k]).strip_edges()
		var hm := _rx("^([0-9]{1,2}):([0-9]{2})$").search(p)
		if hm != null:
			out["clock"] = (int(hm.get_string(1)) % 24) * 60 + int(hm.get_string(2)) % 60
		elif p.is_valid_float():
			out["secs"] = clampf(float(p), 0.1, FADE_MOST)
		else:
			return {}
	return out


## A page fence's words: `{url, search, nav, text}` - its first line `url: address` (or `search: words`, the results page at
## a search engine's address), then any `nav: Forums | Members | Rules` (the site's menu, [TabletScript]'s `nav`), the rest
## the page in the tablet medium's markdown.
static func page_of(text: String) -> Dictionary:
	var lines := text.strip_edges().split("\n")
	var head := String(lines[0]).strip_edges() if not lines.is_empty() else ""
	var from := 1
	var nav := ""
	while from < lines.size() and String(lines[from]).strip_edges().to_lower().begins_with("nav:"):
		nav = String(lines[from]).strip_edges().substr(4).strip_edges()
		from += 1
	var body := "\n".join(lines.slice(from)).strip_edges()
	var out := {"url": "", "search": "", "nav": nav, "text": body}
	if head.to_lower().begins_with("url:"):
		out["url"] = head.substr(4).strip_edges()
	elif head.to_lower().begins_with("search:"):
		out["search"] = head.substr(7).strip_edges()
		out["url"] = "search?q=" + String(out["search"]).uri_encode()
	return out


## The places a page ([param text], the tablet medium's markdown) is brought to for words said while it is up: each
## `<!-- said: words -->` on it, `{words (as the voice says them), before (how many of the page's words are written above
## the mark, as [TabletScript] counts them)}`.
static func said_in(text: String) -> Array:
	var out: Array = []
	for m in _rx(SAID).search_all(text):
		var above := _rx(SAID).sub(text.substr(0, m.get_start()), "", true)
		out.append({"words": words_of(m.get_string(1)),
			"before": (TabletScript.parse("<!-- url: page.example -->\n\n" + above)["words"] as Array).size()})
	return out


## The tablet's browsing, worked out by the tablet medium's own walk: the page fences of [param all], and each `back`
## and `new tab` while the tablet is up, written out in order as a tablet chapter's marks and read by [TabletScript] - the
## document returned (`pages`, `words`, `actions`; a page's player a picture named [constant PLAYER]). Each of those blocks
## is given its `step`: the action that walk made of it (`kind` a link tapped, an address typed, a search - in the page's
## box unless `bar` - or a back; `page`, `tab`, `behind`, `again`), and none where it made nothing of it.
static func browsing(all: Array) -> Dictionary:
	var src := PackedStringArray()
	var made: Array = []                  # the block behind each mark written, in order
	var up := false
	for b in all:
		var blk: Dictionary = b
		match String(blk["kind"]):
			"mark":
				match String(blk["verb"]):
					"tablet":
						up = true
					"/tablet":
						up = false
					"back", "newtab":
						if up:
							src.append("<!-- back -->\n" if String(blk["verb"]) == "back" else "<!-- new tab -->\n")
							made.append(blk)
			"page":
				var pg := page_of(String(blk["text"]))
				if String(pg["url"]).is_empty():
					continue
				# what browses is the desk's marks, never a line of a page
				var text := _rx("(?m)^\\s*<!--\\s*(?:url|search|new tab|back)\\b[^>]*-->\\s*$").sub(String(pg["text"]), "", true)
				text = _rx("<!--\\s*player\\s*-->").sub(text, "<!-- image: %s -->" % PLAYER, true)
				blk["said"] = said_in(text)
				text = _rx(SAID).sub(text, "", true)
				src.append("<!-- search: %s -->" % pg["search"] if not String(pg["search"]).is_empty() else "<!-- url: %s -->" % pg["url"])
				if not String(pg["nav"]).is_empty():
					src.append("<!-- nav: %s -->" % pg["nav"])
				src.append("")
				src.append(text)
				src.append("")
				made.append(blk)
	var doc := TabletScript.parse("\n".join(src))
	for a in doc["actions"]:
		var act: Dictionary = a
		var m := int(act.get("mark", -1))
		if m >= 0 and m < made.size() and String(act["kind"]) != "open":
			(made[m] as Dictionary)["step"] = act
	return doc


## How long the voice waits for a page reached [param how] (`type`, `tap`, `search`, `again`), [param typed] what is typed
## to reach it - into the address bar ([param bar]) a key each [constant TABLET_KEY], into a page's own box at the tablet
## medium's pace ([method box_typing]).
static func page_rest(how: String, typed: String, bar: bool) -> float:
	match how:
		"again":
			return TABLET_AGAIN
		"tap":
			return TABLET_TAP + TABLET_GO + TABLET_LOOK
	if bar:
		return TABLET_GO + TABLET_LOOK + TABLET_KEY * float(typed.length())
	return TABLET_BOX + box_typing(typed) + TABLET_ENTER + TABLET_GO + TABLET_LOOK


## How long [param typed] takes to type into a page's own box: the hand over the keys, then each letter as the tablet
## medium types it ([method TabletScript.char_times]).
static func box_typing(typed: String) -> float:
	return TABLET_HAND + float(TabletScript.char_times(typed)[typed.length()])


## A clock's minutes into the day as it shows them: `HH:MM`.
static func clock_text(minutes: int) -> String:
	var m := posmod(minutes, 24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


## How far a flap has turned over (radians: 0 standing up, PI lying down) [param v] of the way through its turn (0-1): it
## falls faster all the way to [constant CLOCK_LAND], slaps down, and bounces once off its stop.
static func flap_angle(v: float) -> float:
	if v <= 0.0:
		return 0.0
	if v < CLOCK_LAND:
		return PI * pow(v / CLOCK_LAND, 2.0)
	var w := clampf((v - CLOCK_LAND) / (1.0 - CLOCK_LAND), 0.0, 1.0)
	return PI - CLOCK_BOUNCE * sin(w * PI) * (1.0 - w)


## When each digit of a turn from [param was] to [param now] (HH:MM) begins to flap, in seconds after the turn begins: the
## rightmost that changes first, each changed one to its left [constant CLOCK_STAGGER] after; -1 for a digit that stays.
static func flap_starts(was: String, now: String) -> PackedFloat32Array:
	var a := was.replace(":", "")
	var b := now.replace(":", "")
	var out := PackedFloat32Array([-1.0, -1.0, -1.0, -1.0])
	var n := 0
	for k in range(3, -1, -1):
		if k < a.length() and k < b.length() and a[k] != b[k]:
			out[k] = float(n) * CLOCK_STAGGER
			n += 1
	return out


## How long a reply [param shown] takes to type on a phone's keypad (seconds): its characters at [constant T9_RATE], at most
## [constant REPLY_MOST].
static func reply_typing(shown: String) -> float:
	return minf(float(shown.length()) / T9_RATE, REPLY_MOST)


## Where each character of [param text] is typed on a phone's keypad, 0 to 1 of the way through its typing (the middle of its
## keys): a letter takes as many presses as it does there (an "a" one, a "c" three, an "s" four), a space or a mark one, each
## with a hand's unevenness of its own - drawn from the text, so the same reply is typed the same way.
static func key_times(text: String) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(text.length())
	var total := 0.0
	for c in text.length():
		var ch := text[c].to_lower()
		var presses := 1.0
		var at := T9_KEYS.find(ch)
		if at >= 0:
			presses = float(T9_PRESSES[at])
		var r := hash([text, c]) % 1000
		w[c] = (0.55 + 0.45 * presses) * lerpf(0.65, 1.45, float(r) / 999.0)
		total += w[c]
	var out := PackedFloat32Array()
	out.resize(text.length())
	var run := 0.0
	for c in text.length():
		out[c] = (run + w[c] * 0.5) / maxf(total, 1e-6)
		run += w[c]
	return out


## Where each key of [param text]'s characters [param c0] to [param c1] (a said word, [method typed_spans]) is struck in
## the word's time, 0 to 1 of the way through (the middle of its key): each with a hand's give ([constant
## DispatchTerminal.KEY_JITTER]), a space or line break [constant DispatchTerminal.SPACE_MORE] longer - drawn from the
## text, so the same line is typed the same way.
static func hand_times(text: String, c0: int, c1: int) -> PackedFloat32Array:
	var n := maxi(c1 - c0, 0)
	var w := PackedFloat32Array()
	w.resize(n)
	var total := 0.0
	var seed := hash(text)
	for k in n:
		var ch := text[c0 + k]
		w[k] = (1.0 + DispatchTerminal.KEY_JITTER * (DispatchSounds.hash01(seed, c0 + k) * 2.0 - 1.0)) \
			* (DispatchTerminal.SPACE_MORE if ch == " " or ch == "\n" else 1.0)
		total += w[k]
	var out := PackedFloat32Array()
	out.resize(n)
	var run := 0.0
	for k in n:
		out[k] = (run + w[k] * 0.5) / maxf(total, 1e-6)
		run += w[k]
	return out


## How long after the room's reply its answer [param words] comes back: read and thought over ([constant THEIRS_THINK]), and
## typed at the same pace, at most [constant THEIRS_MOST].
static func answer_wait(words: String) -> float:
	return minf(THEIRS_THINK + float(words.length()) / T9_RATE, THEIRS_MOST)


## Does the note open in the black: its first block that shows or says anything a fade up from it?
static func _opens_dark(all: Array) -> bool:
	for b in all:
		var blk: Dictionary = b
		match String(blk["kind"]):
			"speaker", "heard", "voice":
				continue
			"mark":
				var f := fade_of(String(blk["arg"])) if String(blk["verb"]) == "fade" else {}
				return not f.is_empty() and not bool(f["to"])
			_:
				return false
	return false


## The actions made in the black from [param from] on happen at once: the voice waits for none of them but a sound and a
## fade (their rests out of the silence and out of the voice's text).
static func _hush(actions: Array, gap: Array, pending: PackedStringArray, from: int) -> void:
	for i in range(from, actions.size()):
		var a: Dictionary = actions[i]
		if String(a["kind"]) in ["sound", "fade"] or float(a["rest"]) <= 0.0:
			continue
		var hold := "<!-- action-hold: %s -->" % String.num(float(a["rest"]) + REST_PAD, 2)
		var k := pending.rfind(hold)
		if k >= 0:
			pending.remove_at(k)
		for g in gap:
			if int((g as Array)[1]) == i:
				(g as Array)[0] = 0.0
		a["rest"] = 0.0
		a["dark"] = true


## A said line that opens on a time (`22:54.`) more than [constant CLOCK_OFF] minutes off the desk's clock when it is typed,
## both placed by a steady voice ([constant CLOCK_WORD] seconds a word, the rests at their lengths): the warnings.
static func _clock_check(actions: Array, words: int) -> PackedStringArray:
	var out := PackedStringArray()
	var at := PackedFloat32Array()             # each word's moment, and one past the last
	at.resize(words + 1)
	var t := 0.0
	var k := 0
	for w in words + 1:
		while k < actions.size() and int((actions[k] as Dictionary)["after"]) <= w:
			t += float((actions[k] as Dictionary)["rest"])
			k += 1
		at[w] = t
		t += CLOCK_WORD
	var set_at := -1.0
	var set_to := -1
	for a in actions:
		var act: Dictionary = a
		if String(act["kind"]) == "fade" and int(act.get("clock", -1)) >= 0:
			set_at = at[int(act["after"])]
			set_to = int(act["clock"])
		elif String(act["kind"]) == "type" and set_to >= 0:
			var m := _rx("^\\s*([0-9]{1,2}):([0-9]{2})\\b").search(String(act["text"]))
			if m == null:
				continue
			var said := int(m.get_string(1)) * 60 + int(m.get_string(2))
			var clock := set_to + int((at[int(act["from"])] - set_at) / 60.0)
			var off := posmod(said - clock + 720, 1440) - 720
			if absi(off) > CLOCK_OFF:
				out.append("clock: %s is typed about %s on the clock (%+d minutes, by a steady voice)" % [m.get_string(), clock_text(clock), off])
	return out


## [param text] with every redacted character as an X: what the printer prints of it.
static func plain(text: String) -> String:
	var out := ""
	for i in text.length():
		out += "X" if is_redacted(text.unicode_at(i)) else text[i]
	return out


## What a turn of [param who] is heard through: the room's own voice in the room; a voice whose phone is in hand
## through it, one whose phone lies open on the desk from the desk, and any other through the phone in hand (a voice in
## the caller's room) - or the one on the desk.
static func _heard(who: String, room: String, in_hand: String, held: Array) -> String:
	if who == room:
		return ""
	var label := label_of(who)
	if label == in_hand:
		return "phone"
	if held.has(label):
		return "desk"
	if not in_hand.is_empty() or not held.is_empty():
		return "far"
	return ""


## Is a typed block after [param speaker]'s cue the receiver's: a voice that is not the room's, with no phone on the desk.
static func on_receiver(speaker: String, room: String, phones: PackedStringArray) -> bool:
	return not speaker.is_empty() and not room.is_empty() and speaker != room and not phones.has(label_of(speaker))


## An action before spoken word [param at]: added, its rest written into the voice's text, its place in its silence
## noted. Returns its index.
static func _act(actions: Array, gap: Array, pending: PackedStringArray, at: int, a: Dictionary, rest: float, length: float) -> int:
	a["after"] = at
	a["rest"] = rest
	a["len"] = maxf(length, rest)
	actions.append(a)
	var i := actions.size() - 1
	a["gap"] = gap
	gap.append([rest, i])
	if rest > 0.0:
		pending.append("<!-- action-hold: %s -->" % String.num(rest + REST_PAD, 2))
	return i


## A film still playing as its silence ends: the voice waits for the rest of it - each `play` in [param gap] whose film runs past
## what is written after it in that silence (its own rest, the marks and hesitations after it) has the rest of its seconds written
## in as a rest of the voice's, once. Marks written after a `play` in the same silence so happen while it plays.
static func _hold_films(actions: Array, gap: Array, pending: PackedStringArray) -> void:
	for k in gap.size():
		var i := int((gap[k] as Array)[1])
		if i < 0:
			continue
		var a: Dictionary = actions[i]
		if String(a["kind"]) != "play" or a.has("held") or float(a["secs"]) <= 0.0 or bool(a.get(LOOP, false)):
			continue
		a["held"] = true
		var after := float(a["rest"]) + REST_PAD
		for j in range(k + 1, gap.size()):
			after += float((gap[j] as Array)[0]) + (REST_PAD if int((gap[j] as Array)[1]) >= 0 else 0.0)
		var left := float(a["secs"]) - after
		if left > 0.05:
			gap.append([left, -1])
			pending.append("<!-- action-hold: %s -->" % String.num(left, 2))


## An `environment:` mark's words: `{set: {name: on}, secs, bad}` - each part `NAME on` or `NAME off` (an element's kind or the name
## it was kept under, lowered), a bare number the seconds it takes (else [constant ENVIRONMENT_FADE]), and the parts that are neither.
static func environment_of(arg: String) -> Dictionary:
	var set := {}
	var bad := PackedStringArray()
	var secs := ENVIRONMENT_FADE
	for part in arg.split(",", false):
		var p := String(part).strip_edges().to_lower()
		if p.is_valid_float():
			secs = clampf(float(p), 0.0, 30.0)
			continue
		var m := _rx("^(.+?)\\s+(on|off)$").search(p)
		if m == null:
			bad.append(p)
			continue
		set[m.get_string(1).strip_edges()] = m.get_string(2) == "on"
	return {"set": set, "secs": secs, "bad": bad}


## Each action's `fwd` and `back`: the seconds of its silence written before and after it - its hesitations and the rests
## of the actions in it, in order (each action holds its silence's list, `gap`, until now).
static func _silences(actions: Array) -> void:
	for i in actions.size():
		var act: Dictionary = actions[i]
		var g: Array = act.get("gap", [])
		var before := 0.0
		var mine := -1
		for k in g.size():
			if int((g[k] as Array)[1]) == i:
				mine = k
				break
			before += float((g[k] as Array)[0]) + (REST_PAD if int((g[k] as Array)[1]) >= 0 else 0.0)
		var after := 0.0
		for k in range(mine + 1, g.size()):
			after += float((g[k] as Array)[0]) + (REST_PAD if int((g[k] as Array)[1]) >= 0 else 0.0)
		act["fwd"] = before
		act["back"] = after + REST_PAD
		act.erase("gap")


## The voice's text for the next words: a speaker cue where the voice or what it is heard through changes, then what
## waited for them (voice marks, rests) - so a rest before a turn is that turn's, leading its first word.
static func _flush(speak: PackedStringArray, pending: PackedStringArray, who: String, heard: String, said_as: String,
		heard_as: String) -> void:
	if who != said_as or heard != heard_as:
		var cue := "<!-- speaker: %s -->" % who
		if not heard.is_empty():
			cue += "\n<!-- heard: %s -->" % heard
		speak.append(cue)
	if not pending.is_empty():
		speak.append(" ".join(pending))
		pending.clear()


## Does a picture over the whole screen end at spoken word [param at] (its `/image` just before), so the next begins on
## it - a dissolve, the desk never seen between?
static func _ends_at(spans: Array, at: int) -> bool:
	return not spans.is_empty() and int((spans.back() as Dictionary)["to"]) == at


## Which spoken words end a sentence in [param parsed]: 1 for each that ends in `.`, `!` or `?` (a quote or bracket after it
## kept) or ends its paragraph - the voice's text walked as [method rehearsal] walks it (the spoken words themselves are
## normalized, their punctuation gone).
static func sentence_ends(parsed: Dictionary) -> PackedByteArray:
	var spoken: PackedStringArray = parsed["spoken"]
	var out := PackedByteArray()
	out.resize(spoken.size())
	var token := _rx("<!--.*?-->|\\S+")
	var stop := _rx("[.!?][\"')\\]]*$")
	var n := 0
	for chunk in String(parsed["speakable"]).split("\n\n"):
		var last := -1
		for m in token.search_all(String(chunk)):
			var tok := m.get_string()
			if tok.begins_with("<!--") or TabletScript.norm(tok).is_empty() or n >= spoken.size():
				continue
			out[n] = 1 if stop.search(tok) != null else 0
			last = n
			n += 1
		if last >= 0:
			out[last] = 1
	return out


## A steady voice's word times for [param parsed] (for a probe and a gate): every spoken word [param word] seconds, a
## sentence's rest after each paragraph, and the rests the script writes and its hesitations at their lengths - as
## [method DeskScript.rehearsal] does for the desk, and as a live reading's words arrive: `{text, t0, t1}`.
static func rehearsal(parsed: Dictionary, word := 0.32, pause := 0.35, lead := 1.0) -> Array:
	var spoken: PackedStringArray = parsed["spoken"]
	var token := _rx("<!--\\s*action-hold\\s*:\\s*([0-9.]+)\\s*-->|<!--\\s*hesitation\\s*(?::\\s*([0-9.]+))?\\s*-->|<!--.*?-->|\\S+")
	var out: Array = []
	var t := lead
	for chunk in String(parsed["speakable"]).split("\n\n"):
		var any := false
		for m in token.search_all(String(chunk)):
			if not m.get_string(1).is_empty():
				t += float(m.get_string(1))
			elif m.get_string().contains("hesitation"):
				t += float(m.get_string(2)) if not m.get_string(2).is_empty() else HESITATE
			elif not m.get_string().begins_with("<!--") and not TabletScript.norm(m.get_string()).is_empty():
				if out.size() < spoken.size():
					out.append({"text": spoken[out.size()], "t0": t, "t1": t + word * 0.9, "sentence": 0})
				t += word
				any = true
		if any:
			t += pause
	return out
