# Camera: how a flown camera follows what it turns to

## Status

**Built, not yet judged by eye.** One follow for every medium that flies a camera (`CameraFollow`, `src/motion/camera_follow.gd`):
the Dispatch desk, the desk and the Letter, the novel, the notebook and the tablet step it each frame in place of a spring
loop of their own. Each channel is led in (`ease_in`) and settled on a critically damped spring (`settle`). A long look runs
on a quicker clock, its end included (`long`, between `long_from` and `long_full` degrees), and the camera never turns past
`top_speed`.

- **The Camera card** (component `camera`, `src/show/camera_card.gd`, block `ghost: camera:`): one row per setting, each
  dimmed at the format's own until moved; above them, for a format that plans shots of its own (the comic, the novel, the
  notebook, the tablet), the Severity dial (`severity`, `ShowFeed.camera`). Its values are the Director's (`ShowFeed.camera_follow`, `[director]
  camera_follow`), as the Look's are, so a reading and an export follow them alike and a playing show takes a change on its
  next frame.
- **Each format's own** is its Medium row's `follow` (docs/media.md, "How a flown camera follows"), so a note with no Camera
  card moves as before. What a format changes for a moment (the tablet's quick springs on a new page, the Letter's through a
  still, the Camera dial's severity) is a pace on one step, laid over the settings.
- **The Dispatch desk** times the tablet's first page by the camera's own arrival (`CameraFollow.arrival`), so a quicker
  camera reads it sooner.
- **Measured** (the Dispatch desk's own, a look from rest to within a tenth of its way): 20 degrees or less as before (about
  8 s); 45 degrees 5.8 s, 60 degrees 4.6 s, 90 degrees 3.9 s against 7.3 s; 120 degrees held at the top speed, 4.0 s.
- **Gate**: `tests/motion/camera_follow_check.gd` (settings laid over a format's own; a short look unchanged; a long one
  under 0.6 of the time, the control at Long looks 1; a look turned mid-way keeps its pace; the top speed, the control
  without one; the ease in, the control without one; a pace).

## Open

- The author's eye on the Dispatch desk's long looks, and whether Long looks 2 and 80 degrees suit every format.
- Where and when the Dispatch camera looks (`LOOK_LEAST`, `HOME_AFTER`, `PING_HOLD`) is still the format's own constants.
