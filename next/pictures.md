# The Pictures card: one place for a note's pictures

One card paints, steps, deletes and imports a note's pictures, whatever presents the note. It replaces the copies of the
picture list that the Picture, Letter and Dispatch desk cards each carried and fed their own way.

## What was wrong (in the code, before)

The list and look were one widget ([IllustrationPanel], over the [Illustrations] library), but three cards each carried a
copy:

- the **Picture** card (novel, notebook, tablet), fed the chapter by the reading (`PictureCard.set_script_text`);
- the **Letter** card, with its own poll of the words through `LetterScript.pictures_only` (no sketches);
- the **Dispatch desk** card, with its own poll through `DispatchScript.pictures_only` (screen-pinned marks).

The reading kept each copy's `illustrations:` block through a hook (`illustrations()`) asked of every card. The widget had
no Generate all of its own (it lives on the Pipeline card), so none of the three offered one. The YouTube card's painted
thumbnail had also grown its own two-press delete and its own full-size window with a version bar.

## What was built

- **`PicturesCard`** (`src/show/pictures_card.gd`): the `illustrations` component's card, titled Pictures. Its block is
  still `illustrations:` (renaming it would lose every note's look). It **comes with** each presentation that can show
  pictures (`comes_with`: the Medium card; `Components.with_parts`, which the reading's `_voiced` uses), is never attached
  by itself, and has no × (`NoteCards.build`: a part that only comes with another).
- **Which marks are pictures is the presentation's to say**: `Medium.pictures_of(key, body)` asks the medium's script for a
  static `pictures_in(body)` where it has one (`LetterMedium`: never a sketch; `DispatchMedium`: screen-pinned marks;
  `TabletMedium`: its real pages captured), else every image mark. A medium shows pictures when its `uses` has
  `"illustrations"`. No card names another; a new presentation says it in one function. `NoteUpload.pictures` (what a
  thumbnail is painted to match) reads the same list.
- **The card stands only while the medium shows pictures**: under Auto, the full frame or the comic it is off the panel,
  and its Pipeline section with it. It follows the Director's resolved medium (a pin raises no signal, so it looks four
  times a second).
- **Generate all is on the card**, saying how many have none, and is the Pipeline card's Generate: one function behind
  both (`IllustrationPanel._generate_missing`, over `_owed`). Each picture's row keeps Generate / Regenerate, ‹ ›, ✕ and
  **Import…** (a file used for that picture, kept as a version beside painted ones); a tablet's page keeps Capture.
- **Shared widgets** (`src/ui/`): `ArmedDelete` (the two-press delete) and `PictureWindow` (one picture full size, its
  words, its versions, the owner's buttons), used by the Pictures card and the YouTube card's thumbnail.
- The style kind picker (pictures or sketches) shows only where a note has a sketch to paint, or a sketch look set.

## Decided and left where they are

- **A letter's sketches stay on the Letter card**: they are SVG drawings an agent writes and TeX lays out for the pen to
  draw, not pictures painted to be shown. Its section of the Pipeline card lists them.
- **The YouTube thumbnail stays on the YouTube card**: it is a picture of the upload, painted per episode from a brief a
  writer makes, on table notes that have no presentation of pictures. It shares the Pictures card's window and delete
  button.
- **A table show's card paintings stay steps of its episode** (designed, painted, judged by the art director): rows of the
  Pipeline card's Episode section. Every picture an episode's agents made is also shown on the Pictures card
  (`EpisodeFeed.made_pictures`, `MadePictures`; next/face_layers.md), and the card comes with a table show too. Making one
  again is its row on the Pipeline card.

## Gates

`tests/show/pictures_card_check.gd`: which marks each medium shows (with controls); the card comes with its hosts and never
alone; one card on a letter's panel and no list on the Letter, Dispatch desk or Picture card; it stands and goes with the
medium, its section with it; Generate all's count and read-only refusal; a captured page is never counted. Related:
pictures_rows_check (the widget), doc_sync_check (the look kept by the Pictures card), panel_fit_check, youtube_check (the
note's pictures as its presentation shows them, a medium with none as the control).

## Status

- It comes with the Medium alone (`comes_with: ["medium"]`): the Picture card became the Medium card, and the Letter and
  the Dispatch desk are its formats (next/notes.md, "The Medium card").
- Built; the related gates pass (components, dispatch, doc_sync, letter_card, letter, notebook, notes_list, panel_fit,
  pictures_card, pictures_rows, pipeline, tablet, youtube).
- Open: the author has not yet seen it in the app.
