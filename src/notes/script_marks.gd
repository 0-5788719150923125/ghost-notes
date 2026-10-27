extends RefCounted
class_name ScriptMarks

## ScriptMarks - every authoring mark a script may carry, registered with what it does.
##
## A script is plain Markdown, and ghost reads more out of it than the words: speaker cues,
## hesitations, picture markers, inline pronunciations, template macros, emphasis. Each of
## those used to be documented only where it was implemented, so a new author had no way to
## find out what ghost understands short of reading the source. This is the one list: the
## [ScriptWriter] palette is built from it, [ScriptHighlighter] colors a script with its
## patterns, and docs.py writes docs/script.md from it.
##
## AN ENTRY DOES NOT IMPLEMENT ITS MARK. The parsers of record stay where they are
## ([Manuscript] for cues, rests and pictures; [TextNorm] and [Phonemes] for the rest), and
## `tests/notes/script_marks_check.gd` inserts every entry's example and asks THOSE parsers what
## they make of it - so an entry that drifts from what the reader actually does fails there,
## and a new entry without a check fails too.
##
## A CARDS BRIEF IS NOT A SCRIPT, AND HAS MARKS OF ITS OWN (2026-10-12, the user: "why are all of
## the supported macros and features missing from 'cards' editor mode? I would expect that most if
## not all of the features from generative mode should also work here"). The palette was empty
## there because no entry named the mode: a show's document is the BRIEF its agents work from,
## never read aloud, so a mark in it does something only where the code reads it out of the brief
## or an agent is told to honor it. Those are offered ("cards" in `modes`), each saying what it
## does THERE (`blurbs`): a speaker cue gives the show another voice, a `## Cards` section is its
## deck, a macro reads as its default and a note to self is taken out before any agent sees the
## brief ([method TablePrompts.brief]), and a hesitation, a delivery or a stressed word stands in
## a line the brief gives the host word for word (rules/table/reader.yaml, `spoken`). The marks of
## a page or a tablet (pictures, scene lines, web pages) and the inline pronunciation are not: the
## table is the only medium there, its pictures are the painter's, and a reader's passage keeps no
## bracket ([method TableProducer.clean_spoken]).

## Fields of an entry:
##   label    the palette button
##   group    a key of [constant GROUPS]
##   blurb    what it does, for the palette and the docs (one or two sentences)
##   before / fill / after   the text inserted. A selection replaces `fill`, and whatever
##            ends up in the fill is left selected so typing replaces it.
##   line     "own": the mark goes on a line of its own; "start": at the head of the line;
##            "" anywhere
##   modes    the panels that honor it ("generative", "synthesis", "cards")
##   blurbs   optional, {mode: blurb}: what it does in a panel where that differs ([method blurb])
##   within   optional, a key of [constant REGIONS]: colored only inside that section of the script
##   pattern  how [ScriptHighlighter] finds it. Registry ORDER is highlight priority: a span
##            claimed by an earlier entry is not recolored by a later one.

## The heading that opens a show's deck in a Cards brief: `## Cards` or `## The Cards` ([CardDeck]
## reads the deck under it).
const DECK_HEADING := "(?i)^(#{1,6})\\s*(?:the\\s+)?cards\\s*:?\\s*$"

## THE REGIONS a mark can be `within`: a section of the script, named, with the pattern of the
## heading that opens it ([method Manuscript.section_span] finds where it is).
const REGIONS := {"deck": DECK_HEADING}

const REGISTRY := {
	"speaker": {
		"label": "Speaker cue",
		"group": "voices",
		"blurb": "Hands everything after it to the named voice, until the next cue. The panel's voices list follows the names the script uses. Must be a line of its own, or it is only a note.",
		"before": "<!-- speaker: ", "fill": "Name", "after": " -->", "line": "own",
		"modes": ["generative", "table"],
		"blurbs": {"table": "Gives the show another voice by this name: a tab of its own on the Voice card, and the reader writes its lines and hands them over. Say in the brief who it is and when it speaks. Must be a line of its own."},
		"pattern": "(?m)^[ \\t]*(?:<!--\\s*speaker\\s*:\\s*.+?\\s*-->|\\[\\s*speaker\\s*:\\s*[^\\]]+?\\s*\\])[ \\t]*$",
	},
	"hesitation": {
		"label": "Hesitation",
		"group": "timing",
		"blurb": "A longer rest at exactly this point, mid-sentence included. Its length is the panel's Hesitate dial.",
		"before": "<!-- hesitation -->", "fill": "", "after": "", "line": "",
		"modes": ["generative", "table"],
		"blurbs": {"table": "In a line the brief gives the host to say word for word, a rest at exactly this point; its length is the Voice card's Hesitate dial. Everywhere else the reader places its own."},
		"pattern": Manuscript.HESITATION,
	},
	"delivery": {
		"label": "Delivery",
		"group": "timing",
		"blurb": "Lean how the rest of this paragraph is said, a step at a time: quicker / slower, brighter / graver, tighter / looser (pauses), louder / softer, or excited, serious, hushed, urgent, playful, tender, dry; steady is the voice's own. Small, and eased in and out over a few sentences.",
		"before": "<!-- delivery: ", "fill": "quicker, brighter", "after": " -->", "line": "own",
		"modes": ["generative", "table"],
		"blurbs": {"table": "On a line of its own before words the brief gives the host to say word for word: leans how they are said - quicker / slower, brighter / graver, tighter / looser, louder / softer, or excited, serious, hushed, urgent, playful, tender, dry. Everywhere else the reader chooses its own."},
		"pattern": Manuscript.DELIVERY,
	},
	"hesitation_timed": {
		"label": "Timed hesitation",
		"group": "timing",
		"blurb": "A rest of exactly this many seconds, whatever the Hesitate dial says.",
		"before": "<!-- hesitation: ", "fill": "2.5", "after": " -->", "line": "",
		"modes": ["generative", "table"],
		"blurbs": {"table": "In a line the brief gives the host to say word for word, a rest of exactly this many seconds."},
		"pattern": Manuscript.HESITATION,
	},
	"timestamp": {
		"label": "Log-entry time",
		"group": "timing",
		"blurb": "A time opening a paragraph is read as its heading, with a hesitation after it. The Notebook sets it in the margin.",
		"before": "", "fill": "21:40", "after": " ", "line": "start",
		"modes": ["generative"],
		"pattern": Manuscript.TIMESTAMP_LEAD,
	},
	"hum": {
		"label": "Thinking hum",
		"group": "timing",
		"blurb": "Hm, Hmm, Mmm as a sentence of their own are held to most of a second, settling and falling in pitch, instead of read as a clipped syllable.",
		"before": "", "fill": "Hmm.", "after": "", "line": "",
		"modes": ["generative"],
		"pattern": "(?<![\\w'])(?:[Hh]m{1,3}|[Mm]{2,3})[.!?…]",
	},
	"image": {
		"label": "Picture",
		"group": "pictures",
		"blurb": "An illustration, described, placed where it sits: a full page when it opens the chapter or a scene, beside the text otherwise. Generated on request in the Illustrations panel.",
		"before": "<!-- image: ", "fill": "what the picture shows", "after": " -->", "line": "own",
		"modes": ["generative"],
		"pattern": Manuscript.IMAGE,
	},
	"image_full": {
		"label": "Full-page picture",
		"group": "pictures",
		"blurb": "A picture pinned to a page of its own, wherever it sits.",
		"before": "<!-- image (full): ", "fill": "what the picture shows", "after": " -->", "line": "own",
		"modes": ["generative"],
		"pattern": Manuscript.IMAGE,
	},
	"image_left": {
		"label": "Picture, left edge",
		"group": "pictures",
		"blurb": "A picture beside the text, pinned to the left edge. (right) and (inline) pin it the other ways.",
		"before": "<!-- image (left): ", "fill": "what the picture shows", "after": " -->", "line": "own",
		"modes": ["generative"],
		"pattern": Manuscript.IMAGE,
	},
	"sketch": {
		"label": "Sketch",
		"group": "pictures",
		"blurb": "A drawing made on the page in the writer's own ink, black on white, without the book's style or references.",
		"before": "<!-- sketch: ", "fill": "a wiring diagram", "after": " -->", "line": "own",
		"modes": ["generative"],
		"pattern": Manuscript.IMAGE,
	},
	"phonetic": {
		"label": "Pronunciation",
		"group": "pronunciation",
		"blurb": "Spells a word in ARPAbet phonemes, read exactly as written. For a name the voice gets wrong.",
		"before": "[", "fill": "K AE T", "after": "]", "line": "",
		"modes": ["generative", "synthesis"],
		"pattern": "\\[[A-Za-z]{1,2}[0-2]?(?:\\s+[A-Za-z]{1,2}[0-2]?)*\\]",
	},
	"letter": {
		"label": "Letter",
		"group": "pronunciation",
		"blurb": "A letter that names something - a number, a point, a case - said by its name and shown as the letter: [a] is \"ay\", where a bare a is read as the word a.",
		"before": "[", "fill": "a", "after": "]", "line": "",
		"modes": ["generative", "synthesis"],
		"pattern": "\\[[A-Za-z]\\]",
	},
	"macro": {
		"label": "Template macro",
		"group": "text",
		"blurb": "A placeholder for a fact only the book's build knows. Ghost Notes reads the default after the colon, never the macro itself; one with no default is skipped and named in the panel.",
		"before": "${", "fill": "CHAPTERS_BEFORE:twenty-one", "after": "}", "line": "",
		"modes": ["generative", "synthesis", "table"],
		"blurbs": {"table": "A placeholder for a fact only the build knows. The agents are handed the default after the colon, never the macro itself; one with no default is left out."},
		"pattern": "\\$\\{[A-Za-z_][A-Za-z0-9_.]*(?::(?:[^{}]|\\{[^{}]*\\})*)?\\}",
	},
	"deck": {
		"label": "The deck",
		"group": "deck",
		"blurb": "Opens the show's own deck: every list item under this heading, down to the next heading of its level, is a card, and each episode's cards are a seeded shuffle of them. A brief with no such section leaves each episode's cards to the producer.",
		"before": "## Cards", "fill": "", "after": "", "line": "own",
		"modes": ["table"],
		"pattern": "(?im)^#{1,6}[ \\t]*(?:the[ \\t]+)?cards[ \\t]*:?[ \\t]*$",
	},
	"suit": {
		"label": "A suit",
		"group": "deck",
		"blurb": "Inside the deck: names the group the cards listed under it belong to - a suit, an arcana, a team.",
		"before": "### ", "fill": "Major Arcana", "after": "", "line": "start",
		"modes": ["table"], "within": "deck",
		"pattern": "(?m)^#{1,6}[ \\t]+.+$",
	},
	"card": {
		"label": "A card",
		"group": "deck",
		"blurb": "Inside the deck: one card - its name, then what it means after a colon. A numeral may lead it (XVI. The Tower). A writer is handed a card's meaning only once that card is drawn.",
		"before": "- ", "fill": "The Tower: sudden upheaval, a structure that was never sound", "after": "", "line": "start",
		"modes": ["table"], "within": "deck",
		"pattern": "(?m)^[ \\t]*(?:[-*+]|\\d+[.)])[ \\t]+.+$",
	},
	"heading": {
		"label": "Heading",
		"group": "typography",
		"blurb": "Spoken like any line, set as a heading on the page. The frontmatter's title is read first on its own.",
		"before": "# ", "fill": "Heading", "after": "", "line": "start",
		"modes": ["generative", "synthesis", "table"],
		"blurbs": {"table": "A section of the brief, for the agents to find their way by. One heading is read by Ghost Notes itself: Cards, the show's deck."},
		"pattern": "(?m)^#{1,6}[ \\t].*$",
	},
	"scene_line": {
		"label": "Scene line",
		"group": "typography",
		"blurb": "A short paragraph entirely in italics announces a change of time or place; a picture just before it gets a full page.",
		"before": "*", "fill": "Nine-thirty. Orientation.", "after": "*", "line": "own",
		"modes": ["generative"],
		"pattern": "(?m)^[ \\t]*\\*[^*\\n]{1,158}\\*[ \\t]*$",
	},
	"thought": {
		"label": "Thought",
		"group": "letter",
		"blurb": "Letter: a paragraph in italics, whole, is a thought - said, and never written: the writer stops and thinks it, the pen lifted.",
		"before": "*", "fill": "She is always fine.", "after": "*", "line": "own",
		"modes": ["generative"],
		"pattern": "(?m)^[ \\t]*(?:<!--[^\\n]*?-->[ \\t]*)?\\*[^*\\n]+\\*[ \\t]*$",
	},
	"italic": {
		"label": "Italic",
		"group": "typography",
		"blurb": "Shown in italics in the subtitles and on the page, and a word or a few so marked is hit: held longer and said louder. A longer run is typography, said plainly. The asterisks are never spoken.",
		"before": "*", "fill": "emphasized", "after": "*", "line": "",
		"modes": ["generative", "synthesis", "table"],
		"blurbs": {"table": "In a line the brief gives the host to say word for word, the word the voice hits, shown in italics in the subtitle. Anywhere else it is emphasis for the agents reading the brief."},
		"pattern": "(?<![*\\w])\\*(?![*\\s])[^*\\n]*?[^*\\s]\\*(?![*\\w])|(?<![*\\w])\\*[^*\\s]\\*(?![*\\w])",
	},
	"bold": {
		"label": "Bold",
		"group": "typography",
		"blurb": "Shown in bold in the subtitles and on the page, and a word or a few so marked is hit harder than an italic one. The asterisks are never spoken.",
		"before": "**", "fill": "strong", "after": "**", "line": "",
		"modes": ["generative", "synthesis", "table"],
		"blurbs": {"table": "In a line the brief gives the host to say word for word, the word the voice hits hardest, shown in bold in the subtitle. Anywhere else it is emphasis for the agents reading the brief."},
		"pattern": "\\*\\*(?![*\\s])[^*\\n]*?\\*\\*",
	},
	"rule": {
		"label": "Scene break",
		"group": "typography",
		"blurb": "A rule across the page between two scenes. Silent.",
		"before": "* * *", "fill": "", "after": "", "line": "own",
		"modes": ["generative"],
		"pattern": "(?m)^[ \\t]*(?:\\* \\* \\*|\\*\\*\\*|---)[ \\t]*$",
	},
	"outro": {
		"label": "Outro starts here",
		"group": "timing",
		"blurb": "The end begins at this point: the reading carries on but fades out - voice and picture together, over the Outro setting - and whatever text is left is cut. Own line or mid-sentence; the first one counts.",
		"before": "<!-- outro -->", "fill": "", "after": "", "line": "",
		"modes": ["generative"],
		"pattern": Manuscript.OUTRO,
	},
	"url": {
		"label": "Web page",
		"group": "tablet",
		"blurb": "Tablet: the page below lives at this address. How it is reached is worked out - a link on the page on screen is tapped, anything else is typed in. With nothing written under it, it is the REAL page there, captured from the web.",
		"before": "<!-- url: ", "fill": "www.example.com", "after": " -->", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*url\\s*:[^>]*-->",
	},
	"search": {
		"label": "Search",
		"group": "tablet",
		"blurb": "Tablet: type this into a search box - the page's own, on a search engine, else the address bar - and the results page follows.",
		"before": "<!-- search: ", "fill": "what is the 7th realm", "after": " -->", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*search\\s*:[^>]*-->",
	},
	"new_tab": {
		"label": "New tab",
		"group": "tablet",
		"blurb": "Tablet: a pause to think, then a blank tab; the next web page is typed into it.",
		"before": "<!-- new tab -->", "fill": "", "after": "", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*new tab\\s*-->",
	},
	"back": {
		"label": "Back",
		"group": "tablet",
		"blurb": "Tablet: back to the page before, scrolled where it was left. An unread page is glanced down first. Follow it with a mark, not text.",
		"before": "<!-- back -->", "fill": "", "after": "", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*back\\s*-->",
	},
	"redirect": {
		"label": "Redirect",
		"group": "tablet",
		"blurb": "Tablet: put it before a url - the tap (or typed address) that reaches that page is sent through a chain of redirects the reader never asked for, the address bar jumping through them on its own. Bare: six hops made up from the page's own site, a scam's funnel. Or name them, comma-separated.",
		"before": "<!-- redirect", "fill": "", "after": " -->", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*redirect\\s*(?::[^>]*)?-->",
	},
	"notify": {
		"label": "Notification",
		"group": "tablet",
		"blurb": "Tablet: a notification banner drops from the top of the screen a moment after the reading reaches this point - mid-paragraph or on a line of its own - holds a few seconds and slides away: an email arriving. Sender | subject | preview. Not read aloud; the voice does not wait for it.",
		"before": "<!-- notify: ", "fill": "Sender | Subject | A line of the message", "after": " -->", "line": "",
		"modes": ["generative"],
		"pattern": "<!--\\s*notify\\s*:[^>]*-->",
	},
	"landscape": {
		"label": "Landscape",
		"group": "tablet",
		"blurb": "Tablet: turn to landscape. The camera turns; the tablet stays where it lies.",
		"before": "<!-- landscape -->", "fill": "", "after": "", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*landscape\\s*-->",
	},
	"portrait": {
		"label": "Portrait",
		"group": "tablet",
		"blurb": "Tablet: turn back to portrait.",
		"before": "<!-- portrait -->", "fill": "", "after": "", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*portrait\\s*-->",
	},
	"skip": {
		"label": "Skip",
		"group": "tablet",
		"blurb": "Tablet: shown, not read. Mid-paragraph, the rest of it from the end of that sentence; on its own line, the whole paragraph below.",
		"before": "<!-- skip -->", "fill": "", "after": "", "line": "",
		"modes": ["generative"],
		"pattern": "<!--\\s*skip\\s*-->",
	},
	"filler": {
		"label": "Placeholder stories",
		"group": "tablet",
		"blurb": "Tablet: this many placeholder stories - squiggles where writing would be - on the page here.",
		"before": "<!-- filler: ", "fill": "3", "after": " -->", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*filler\\s*(?::[^>]*)?-->",
	},
	"strike": {
		"label": "Strike",
		"group": "letter",
		"blurb": "Letter: the pen crosses out the paragraph it last wrote, every line of it.",
		"before": "<!-- strike -->", "fill": "", "after": "", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*strike\\s*-->",
	},
	"unspoken": {
		"label": "Written, not said",
		"group": "letter",
		"blurb": "Letter: the pen writes this and the voice does not say it - it waits while it is written.",
		"before": "<!-- unspoken: ", "fill": "Dear Ink,", "after": " -->", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*unspoken\\s*:[^>]*-->",
	},
	"point": {
		"label": "Point",
		"group": "letter",
		"blurb": "Letter: inside what is said, at the next word the pen points at the last sketch - or at the part of it so described - until the sentence ends. point: camera lifts the pen to whoever is watching.",
		"before": "<!-- point: ", "fill": "sketch, the dot", "after": " -->", "line": "",
		"modes": ["generative"],
		"pattern": "<!--\\s*point\\s*:[^>]*-->",
	},
	"tap": {
		"label": "Tap",
		"group": "letter",
		"blurb": "Letter: the pen is turned over and its top tapped on the pad - tap: desk, on the desk beside it - while the writer thinks. The voice waits a moment; the taps run on under the next words.",
		"before": "<!-- tap", "fill": "", "after": " -->", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*tap\\s*(?::[^>]*)?-->",
	},
	"image_end": {
		"label": "Picture ends",
		"group": "letter",
		"blurb": "Letter: ends the passage a picture is shown over - from its image mark to here the picture fills the screen, slowly panning, while the voice reads on and the pen writes on unseen; then the desk comes back.",
		"before": "<!-- /image -->", "fill": "", "after": "", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*/\\s*image\\s*-->",
	},
	"still": {
		"label": "Hold still",
		"group": "letter",
		"blurb": "Letter: from here to the next written line the camera holds dead still on the last sketch, and the pen is taken off the page - for something the viewer does on the screen.",
		"before": "<!-- still -->", "fill": "", "after": "", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*still\\s*-->",
	},
	"new_page": {
		"label": "New page",
		"group": "letter",
		"blurb": "Letter: the next writing starts a page of its own (a page also turns by itself once it is full).",
		"before": "<!-- new page -->", "fill": "", "after": "", "line": "own",
		"modes": ["generative"],
		"pattern": "<!--\\s*new\\s+page\\s*-->",
	},
	"note": {
		"label": "Note to self",
		"group": "notes",
		"blurb": "Any other HTML comment is an authoring note: never spoken, never printed.",
		"before": "<!-- ", "fill": "a note to yourself", "after": " -->", "line": "",
		"modes": ["generative", "synthesis", "table"],
		"blurbs": {"table": "Any other HTML comment is a note to yourself: taken out of the brief before any agent is handed it."},
		"pattern": Manuscript.COMMENT,
	},
}

## Palette sections, in order, with the color [ScriptHighlighter] gives their marks.
const GROUPS := {
	"voices": {"label": "Voices", "color": Color(0.98, 0.72, 0.35)},
	"timing": {"label": "Timing", "color": Color(0.55, 0.85, 0.95)},
	"pictures": {"label": "Pictures", "color": Color(0.75, 0.62, 1.0)},
	"pronunciation": {"label": "Pronunciation", "color": Color(0.55, 0.95, 0.6)},
	"text": {"label": "Text", "color": Color(1.0, 0.6, 0.75)},
	"typography": {"label": "Typography", "color": Color(0.95, 0.9, 0.6)},
	"tablet": {"label": "Tablet", "color": Color(0.5, 0.75, 1.0)},
	"deck": {"label": "The deck", "color": Color(0.98, 0.62, 0.5)},
	"letter": {"label": "Letter", "color": Color(0.72, 0.9, 0.55)},
	"notes": {"label": "Notes", "color": Color(0.6, 0.6, 0.66)},
}


## The keys a panel honors, in registry order.
static func for_mode(mode: String) -> PackedStringArray:
	var out := PackedStringArray()
	for k in REGISTRY:
		if (REGISTRY[k]["modes"] as Array).has(mode):
			out.append(k)
	return out


## What a mark does in the panel [param mode]: its own words for that panel (`blurbs`) where the
## mark means something else there, the registry's otherwise.
static func blurb(key: String, mode := "") -> String:
	var e: Dictionary = REGISTRY[key]
	return String((e.get("blurbs", {}) as Dictionary).get(mode, e["blurb"]))


## The highlight color of a mark.
static func color_of(key: String) -> Color:
	return GROUPS[REGISTRY[key]["group"]]["color"]


## The mark's text with [param fill] (the example when empty).
static func example(key: String, fill := "") -> String:
	var e: Dictionary = REGISTRY[key]
	return String(e["before"]) + (fill if not fill.is_empty() else String(e["fill"])) \
		+ String(e["after"])


## INSERT A MARK at the caret of [param te], as the palette does.
##
## A selection becomes the fill - select a name and press Speaker cue, and it is that
## speaker's cue - except for a mark with no fill, which goes after the selection rather
## than over it. Whatever ends up in the fill is left SELECTED, so the example is replaced
## by typing. One undo step. [param value] fills the mark outright (a known speaker's name),
## and is then left unselected.
static func insert(te: TextEdit, key: String, value := "") -> void:
	var e: Dictionary = REGISTRY[key]
	var before := String(e["before"])
	var after := String(e["after"])
	var fill := String(e["fill"]) if value.is_empty() else value
	var where := String(e["line"])
	te.begin_complex_operation()
	if te.has_selection():
		var sel := te.get_selected_text()
		if fill.is_empty() or not value.is_empty() or sel.contains("\n"):
			te.set_caret_line(te.get_selection_to_line())
			te.set_caret_column(te.get_selection_to_column())
			te.deselect()
		else:
			fill = sel
			te.delete_selection()
	var line := te.get_caret_line()
	var col := te.get_caret_column()
	var text := te.get_line(line)
	if where == "start":
		col = 0
	elif where == "own":
		if not text.substr(0, col).strip_edges().is_empty():
			before = "\n" + before
		if not text.substr(col).strip_edges().is_empty():
			after += "\n"
	te.set_caret_line(line)
	te.set_caret_column(col)
	te.insert_text_at_caret(before)
	var l0 := te.get_caret_line()
	var c0 := te.get_caret_column()
	te.insert_text_at_caret(fill)
	var l1 := te.get_caret_line()
	var c1 := te.get_caret_column()
	te.insert_text_at_caret(after)
	if not fill.is_empty() and value.is_empty():
		te.select(l0, c0, l1, c1)
	te.end_complex_operation()
