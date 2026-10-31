extends RefCounted
class_name Icons

## Icons - the few pictures a button wears in place of words (2026-10-31, the user, of the notes list:
## "remove the 'New' and 'Existing note...' buttons and just replace them plain icons, no text").
##
## DRAWN, NEVER IMPORTED: each is a stroke path on a 24-unit square, made into a texture at the size it
## is asked for ([method texture]), so a phone's 43-pixel button is as sharp as a desktop's 24 - and a
## new icon is a row, with no file for the editor's import step to miss (a `--path .` run never imports).
## Drawn white: a [Button] tints its icon by its own state colors. A button that wears one says what it
## does in its tooltip, since nothing else on it does.
##
## The paths are our own: plain geometry, nothing traced from an icon set.

## One row an icon: `label` (what the button does), `blurb`, and `svg`, the shapes inside a 24x24 view.
const ROWS := {
	"new": {"label": "New note",
		"blurb": "A plus: a new note, with nothing on it yet.",
		"svg": "<path d=\"M12 5v14M5 12h14\"/>"},
	"existing": {"label": "Existing note",
		"blurb": "A folder: a markdown file from anywhere, kept in the list where it is.",
		"svg": "<path d=\"M3 6.5A1.5 1.5 0 0 1 4.5 5H9l2 2.5h8.5A1.5 1.5 0 0 1 21 9v9.5a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 18.5z\"/>"},
	"search": {"label": "Search",
		"blurb": "A magnifier: the notes narrowed to those that say what is typed.",
		"svg": "<circle cx=\"10.5\" cy=\"10.5\" r=\"6.5\"/><path d=\"M15.5 15.5 21 21\"/>"},
	"open": {"label": "Open the whole note",
		"blurb": "An arrow out of a box: the note on its own panel, where + attaches what it becomes.",
		"svg": "<path d=\"M14 4h6v6M20 4l-8 8\"/><path d=\"M18 14v4.5a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 4 18.5v-11A1.5 1.5 0 0 1 5.5 6H10\"/>"},
	"delete": {"label": "Delete this note",
		"blurb": "A bin: the note thrown away, asked first.",
		"svg": "<path d=\"M4 7h16M9.5 7V4.5h5V7M6 7l1 12.5A1.5 1.5 0 0 0 8.5 21h7a1.5 1.5 0 0 0 1.5-1.5L18 7\"/>"},
	"export": {"label": "Export this note",
		"blurb": "An arrow up out of a tray: the note written out to a file elsewhere.",
		"svg": "<path d=\"M12 15V4M7.5 8.5 12 4l4.5 4.5\"/><path d=\"M5 13v5.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V13\"/>"},
}

## The stroke, in the view's units.
const STROKE := 2.0

static var _made := {}


## [param key]'s icon, [param px] pixels square (made once per size), or null for a key with no row.
static func texture(key: String, px: int) -> Texture2D:
	var id := "%s@%d" % [key, px]
	if _made.has(id):
		return _made[id]
	if not ROWS.has(key):
		return null
	var svg := ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" "
		+ "fill=\"none\" stroke=\"#ffffff\" stroke-width=\"%s\" stroke-linecap=\"round\" stroke-linejoin=\"round\">%s</svg>") \
		% [STROKE, String(ROWS[key]["svg"])]
	var img := Image.new()
	# a quarter pixel over, so the loader lands on px whether it rounds or floors
	if img.load_svg_from_string(svg, (maxf(px, 1) + 0.25) / 24.0) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_made[id] = tex
	return tex


## A BUTTON THAT WEARS ICON [param key] and no words, [param px] pixels square inside its padding: its
## tooltip says what it does ([param tip], else the row's label).
static func button(key: String, px: int, tip := "") -> Button:
	var b := Button.new()
	b.icon = texture(key, px)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip if not tip.is_empty() else Registry.label(ROWS, key)
	var side := px + roundi(px * 0.66)
	b.custom_minimum_size = Vector2(side, side)
	return b
