# The pop-up book: a Medium format

A note read as a pop-up book open on the Letter's desk, one scene a spread. The novel ([BookMedium]) has the 3D spread, the
turning leaf, the voice followed word by word and the camera; the pop-up book ([PopupMedium], `src/desk/popup.gd`, its typesetter
[PopupLayout] in `media/`) is what differs.

## Status

**Built 2026-11-27, rebuilt 2026-11-28 from the author's first viewing** (the voice ran over the cover, the V faced the wrong way,
a piece could fold only once, the pictures did not sit on the page, the desk was bare). Now: the voice rests for the book
([PopupWalk]), pieces of any creasing standing as the note's design says ([PopupDesign]), scenery standing at the back and a floor
under it, the Letter's dressed desk under the book, and a paper engineer that stands each spread and looks at it
([PopupEngineer], [PopupTools], [PopupStudio]). Seen with the first real pictures (*Cut It Out*, rift `papers/cut-it-out/`):
the cover, the opening, a turn, two spreads, the engineer's three views (`tests/media/popup_studio_probe.gd`). Not yet: the
engineer run on a real note (it runs only inside the app: a probe may not start agents), a whole reading played, an export.
**Later the same day the layers became the engineer's**: the script gives each spread a brief (`<!-- spread: -->`) and the
engineer decides the layering, writes each layer's picture, has it painted, waits, looks and refines in rounds.

## How it works

- **Scenes, not pages.** A scene opens at a picture mark that follows words. Its words are set below the pop-up band
  ([constant PopupLayout.TEXT_TOP]), split over both pages at a paragraph end near the middle, a short scene kept whole on
  the left page. Its brief (`<!-- spread: -->`, never painted as written; any other page prints it as a picture) says
  what the spread shows; until the engineer makes it, it is printed faintly on the band.
- **The engineer makes the layers.** From the brief and the words, not bound to them: a scenery flat at the back (painted
  as `Illustrations.SPREAD`, a backdrop at eye level), up to [constant PopupDesign.MOST] cut-outs before it (`POPUP`), a
  floor printed under them (`FLOOR`, seen from above) - each layer a picture of its own words, keyed by them
  ([method PopupDesign.key_of]), listed on the Pipeline card and painted there. A script may still name layers itself
  (`<!-- image: -->` scenery, `<!-- popup: -->` cut-outs); the design makes them stand.
- **Pieces are creased card.** A picture creased at `folds` (fractions across it) into panels, each turned from facing the
  reader by `turns`, crease `at` on the spine at depth `z` ([method PopupMedium.footprint]: kept inside the page, off the
  words, folding flat inside the page). A V (ridge toward the reader) is one crease; a box (front facing, sides back) two;
  a zigzag several. Every crease leans together as a V-fold's does ([method PopupMedium.crease], feet at
  [constant PopupMedium.FOLD] to the spine) and every foot rides its own page: exact for a V, and nothing ever passes
  through a page. A cut-out (`<!-- popup: -->`) is painted at eye level on magenta and cut out by the puppet host.
- **The design** is the note's (`popup.json` in its folder, carried in the document's `popup`); with none, each cut-out
  stands as a V in [constant PopupMedium.SLOTS] and the scenery as a shallow V at the back.
- **The paper engineer** (rules/popup/engineer.yaml) is a row on the Pipeline card: its tools ([PopupTools]) read the scenes,
  stand a scene's layers (new pictures asked for at once), wait for paintings, LOOK (the spread as the show sees it, from
  above, from the side - the book's own medium drawing it, [PopupStudio]) and refine one layer's painting with only an ask
  changed. It works in rounds until each spread works. It never touches the script's words.
- **The voice waits.** [PopupWalk] rests it after the title ([constant PopupWalk.OPEN_REST]) while the cover opens and the
  first scene stands, and at each later scene ([constant PopupWalk.TURN_REST]); the leaf turns early in that rest
  ([constant PopupMedium.TURN_EARLY]). A rest sits on the word after it: a paragraph of nothing but a rest is dropped.
- **The desk is the Letter's** ([DeskLook], [DeskLight]): chosen on the Medium card's desk rows ([PopupFormat]), lit as the
  Environment card says; the book set on it at [constant PopupMedium.BOOK_M] a page, nothing lying under it. [BookMedium]
  keeps its book under `_book` and places its camera through that node's scale.
- **The camera** holds the spread from low in front while a scene stands up, then, as its words are read, eases only a
  little nearer and higher, leaning toward the page and line being read: the pop-up never leaves the frame (the scene and its
  words are one picture), and each spread is seen at less of its own angle than the novel. Hooks on [BookMedium]:
  `_wide_view`, `_local_view`, `_local_aim`, `_arc_shares`, `_spread_tilt`.
- **A story told whole.** It opens over the closed book from above, its painted cover (`<!-- image (cover): -->`, the note's
  `book`, `subtitle` and `author` set over it as type, [method BookMedium.draw_cover]); after the sources (what follows
  `<!-- unread -->`) the cover shuts, the camera rises over it, and only then does the picture fade. The outro hold gives the
  close its room (about 15 s shows the sources first).

## Open

- The engineer on a real note, and whether its looks lead it to good spreads; whether `describe` should wait for a painting.
- A piece the engineer places off the gutter (on one page) is untried in a turn.
- The lamp's shadows on the scenery, and candles too near a piece blooming.
- Pull tabs, pieces that turn as the page does.
