# Portrait: a table show at 9:16, for TikTok

## Status

**Built 2026-11-23; rendered at 9:16 by the look probe, never exported or judged on a phone.** The author pivoted a game show
(Mistakes Were Made) to three-to-five-minute TikTok episodes, made its first episode, and found the Medium card could not be set
to portrait. A table show can be portrait now. Its first episode (`table/mistakes-were-made/633647`) was stood whole at 540x960
(`tests/table/game_look_probe.gd --stand <dir> --medium table --frame portrait --size 540x960`), board alone and with its pages,
beside the same at 960x540.

## How it works

- **The frame is the note's.** The `table` row of `Medium.REGISTRY` takes `portrait`; the Medium card keeps a table show's frame
  in its block (`medium: frame: portrait`) and gives it to the Director, writing nothing for landscape, so every other table
  show's block stays as it was. It is not an episode's: any episode is shown in the frame the note has now.
- **The lens is the frame's short side** (`CardTable.lens`, `CardTable.keep`): in landscape and 4:3 the camera keeps its height,
  in portrait its width. A portrait frame sees what a landscape one does turned on end - across what landscape sees up, up what it
  sees across - and a die framed to fill a landscape picture's height fills a portrait one's width. The medium reads the frame's
  shape from its feed (`ShowFeed.frame_aspect`, the Director's `resolved_frame`), so a render launched `--frame portrait` has it.
- **Each shot of a game keeps a landscape frame's top edge** (`TableGame._kept_top`): it is turned down until its top is where
  landscape's was, so the height portrait gains is the board and the table in front, never more of the dark room past the model
  (built to be seen from the table's head alone). What a shot looks at sits about a third of the way down. Measured before it: a
  march at 2 cm off the board left the top half of the frame black.
- **A march looks ahead of its figures as far as the frame is wide** (`TableGame.MARCH_LEAD`): at the landscape lead, figures a
  landscape march had at the frame's edge were off a portrait one.
- **A sticker page is framed, not painted, for portrait** (next/sticker_book.md): its sets are painted 3:2 whatever the frame and the
  camera frames the cast on them at the frame's shape - a tall frame sees a third of a set's width, so a crowded row overlaps and steps
  back to fit, and the game master is told to keep a tall picture to one or two (rules/table/game_master.yaml `tall`); its characters
  are drawn 2:3, whole. Nothing goes stale with the frame.
- **Whole painted pages are painted 2:3 for portrait** (`TableEpisode.tall`, rules/table/painter.yaml `game_page`, `tall`): composed for a phone
  held upright, faces in the upper half (TikTok's buttons and caption cover the right edge and the bottom third, the subtitles the
  lower middle). A page's key carries its shape (`TableEpisode.page_key`), so a landscape page goes **stale** in portrait and
  Generate paints it again - pages alone: the script, the session, the board and the figures do not depend on the frame. Until
  it is, a landscape page covers the tall frame by its height and shows its middle third. A page is a unit square stretched each
  frame to cover the frame (`TableGame._page_size`); the tilt-shift band and the air's motes (`Effects._lens`) cover it too. The game
  master of a portrait show is told so (rules/table/game_master.yaml `pictures`, `tall`): each page one subject seen close, rather than a
  wide view of many, which a phone shows small.
- **A picture held up** (a reveal, painted 3:2 as a card in the hand) is held farther off where the frame is too narrow for it,
  never wider than `HOLD_ACROSS` of it.
- **The table is still dressed for 16:9** (`CardTable.DRESSED`): where things are set out, what is kept in the shot, what is pruned
  as giving nothing, the headroom the set dresser is told, the blueprint. A portrait frame sees the middle of that table. Said in
  the code where it is so (`ShotReach.ASPECT`, `table_things`, `table_box`).

## Open

- **Judged on a phone.** No portrait episode has been exported (`--frame portrait` renders 720x1280 or 1080x1920) or watched.
- **A card reading at 9:16.** The deck and a spread are laid out for 16:9; a three-card reading's sides fall outside a portrait view.
- **The room's picture** (`backdrop`, from the head) is sized for the dressed frame's width and kept that size; the first episode had
  none, so a portrait head-of-table view over a room picture is unseen.
- Seen while measuring, not portrait's: the episode's one throw (70-75 s) is under a page, since a page gives way only to a throw at
  its extreme or one the game master watches (`TableGame._page_end`); and its "dust in the lamplight" blows out white where a game's
  moving camera passes through it (`Effects` keeps motes clear of the head's camera only).

## TikTok's cover

- **Direct post** sends `post_info.video_cover_timestamp_ms` only when the Upload card's Thumbnail is "title" (the title's moment).
  TikTok's API takes no cover image: the cover is a frame of the video.
- **Draft** (this note's `tiktok_mode: draft`) sends no cover: the author picks it in the TikTok app. Unpicked, TikTok uses the first
  frame, and a table show's first frame is black (it fades up over 1.2 s).
- A painted thumbnail goes to YouTube alone; with TikTok the only target, it is not made.
- Drafts are not checked against the account's longest video (`max_video_post_duration_sec`) before they go: only posts are. TikTok
  allows every account 3 minutes and some 5 or 10, so a five-minute episode may be refused.
- Profile grids crop the cover to about 3:4 from its middle (third-party guides, not TikTok's documentation): a title and faces belong
  in the vertical middle.
