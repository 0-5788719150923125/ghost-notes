# The Pictures card: one place for a note's pictures

Opened and built 2026-11-06. The user, of the Dispatch desk card carrying its own picture list: "We recently implemented a
dedicated pipeline card, to hold all of the various agentic steps that might require regeneration. Then here, on the
Dispatch Desk card, you've implemented image generation... which we have ALREADY done a few times before, on other cards
(like the journal one, and the tablet medium, and elsewhere). I think we ought to unify these as well, so that if we are
generating images, we are doing it from a unified place: not from a bunch of disparate cards. And the reason is
maintainability: here, you forgot to add the 'Generate all' button ... I think a 'Pictures' card would probably be
appropriate ... which allows us to generate pictures for our scenes but would also allow us to upload pictures."

## What was wrong (in the code, before)

The list and look were one widget already ([IllustrationPanel], over the [Illustrations] library), but three cards each
carried a copy of it and each fed it its own way:

- the **Picture** card, for a novel, a notebook or a tablet: hidden by the medium's `uses`, fed the chapter by the
  reading (`PictureCard.set_script_text`), the tablet's captured pages added inside the widget itself;
- the **Letter** card: its own poll of the words, through `LetterScript.pictures_only` (no sketches);
- the **Dispatch desk** card: its own poll, through `DispatchScript.pictures_only` (screen-pinned marks).

The reading kept each copy's `illustrations:` block through a hook (`illustrations()`) asked of every card. The widget
had no Generate all of its own (it had moved to the Pipeline card), so nothing on any of the three said one existed.
Elsewhere, the YouTube card's painted thumbnail had grown its own copies of the two-press delete and of the full-size
window with its version bar.

## What was built

- **`PicturesCard`** (`src/show/pictures_card.gd`): the `illustrations` component's card, a card of its own titled
  Pictures. Its block is still `illustrations:` (renamed, every note's look would be lost). It **comes with** each
  presentation that can show pictures (`comes_with`: Picture, Letter, Dispatch desk; `Components.with_parts`, which the
  reading's `_voiced` uses), is never attached by itself, and has no × (`NoteCards.build`: a part that only comes with
  another).
- **Which marks are pictures is the presentation's to say**: `Medium.pictures_of(key, body)` asks the medium's script for
  a static `pictures_in(body)` where it has one (`LetterMedium`: never a sketch; `DispatchMedium`: screen-pinned marks;
  `TabletMedium`: its real pages captured), else every image mark. A medium shows pictures when its `uses` has
  `"illustrations"` (now the letter's and the dispatch desk's too). No card names another, and a presentation added later
  says it in one function. `NoteUpload.pictures` (what a thumbnail is painted to match) reads the same list.
- **The card stands only while the medium shows pictures**: under Auto, the full frame or the comic it is off the panel,
  its Pipeline section with it; picking a novel brings it back. It follows the Director's resolved medium (a pin raises
  no signal, so it looks four times a second).
- **Generate all is on the card**, saying how many have none, and is the Pipeline card's Generate: one function behind
  both (`IllustrationPanel._generate_missing`, over `_owed`), so neither can go without it. Each picture's row keeps
  Generate / Regenerate, ‹ ›, ✕ and **Import…** (a file of the author's used for that picture, kept as a version beside
  painted ones); a tablet's page keeps Capture.
- **Shared widgets** (`src/ui/`): `ArmedDelete` (the two-press delete) and `PictureWindow` (one picture full size, its words,
  its versions, the owner's buttons), used by the Pictures card and the YouTube card's thumbnail.
- The style kind picker (pictures or sketches) shows only where a note has a sketch to paint, or a sketch look set.

## Decided and left where they are

- **A letter's sketches stay on the Letter card**: they are SVG drawings an agent writes and TeX lays out for the pen to
  draw, not pictures painted to be shown - its section of the Pipeline card already lists them.
- **The YouTube thumbnail stays on the YouTube card**: it is a picture of the upload, painted per episode from a brief a
  writer makes, on table and proof notes that have no presentation of pictures. It shares the Pictures card's window and
  delete button.
- **A table show's card paintings stay steps of its episode** (designed, painted, judged by the art director): rows of
  the Pipeline card's Episode section. **Changed 2026-11-09**: they stay steps, and every picture an episode's agents made is now
  also SHOWN on the Pictures card ("we will never see the reference image in the UI"; next/face_layers.md) - `EpisodeFeed.made_pictures`,
  `MadePictures`; the card comes with a table show too. Making one again is still its row on the Pipeline card.

## Gates

`tests/show/pictures_card_check.gd` (which marks each medium shows, with controls; comes with its hosts and never alone;
one card on a letter's panel and no list on the Letter, Dispatch desk or Picture card; stands and goes with the medium,
its section with it; Generate all's count, read-only refusal, a captured page never counted). Updated: pictures_rows_check
(unchanged, the widget), doc_sync_check (the look kept by the Pictures card), panel_fit_check, youtube_check (the note's
pictures as its presentation shows them, a medium with none as the control).

## Status

**2026-11-09: it comes with the Medium alone** (`comes_with: ["medium"]`): the Picture card became the Medium card,
and the Letter and the Dispatch desk its formats, so the three hosts above are one (next/notes.md, "The Medium card").

Built 2026-11-06; the related gates pass (components, dispatch, doc_sync, letter_card, letter, notebook, notes_list,
panel_fit, pictures_card, pictures_rows, pipeline, tablet, youtube). Not yet seen by the author in the app.
