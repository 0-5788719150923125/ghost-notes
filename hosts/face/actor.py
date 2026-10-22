#!/usr/bin/env python3
"""actor.py - the Likeness pipeline's steps that read video: an actor built from their own footage.

One entry point, a subcommand per step (next/likeness.md, "The steps"), run in ghost's face
environment (`face_venv`: MediaPipe, OpenCV, numpy - nothing else). The GDScript side
([ActorBuilder]) decides what runs and when; each step here reads files and writes files, and
nothing else: no step knows about another except through what it wrote.

    survey      a video, every 0.2 s: the face (its pose, its 52 blendshapes, its box), the body's
                33 points, a small person mask and a gray thumbnail - for finding things
    shots       a video's cuts, from its survey, each placed on its exact frame
    sets        every video's shots grouped by camera placement (the background's EDGES, so the
                sun moving on the wall keeps a set whole), with the contact sheets the audit sees
    stills      a set's most typical calm moments, facing the camera: the one frame a Likeness is
                drawn on, and a few to pick from
    rig         the mesh on the set's still: its face, the rings round it, the frame's edge, one
                triangulation, and the face's box with a mask for the lips and one for the eyes
    visemes     their mouth for each sound class, from caption-timed phones (or their own range),
                over every video
    motion      their head's own motion where they face the camera, over every video: its quick part
                in runs, which looks are speech, how often they blink
    library     each sound class's prototype mouths and their eyes half and fully closed, from any
                video at the still's turn, unwrapped into the box

THE SECOND BUILD (next/likeness.md, 2026-10-21, night): a Likeness is one still and a model of the person
- their motion, their blinks, their mouths - so nothing here follows a set frame by frame; a step that
needs a frame at full size seeks it ([frame_at]) and looks at it as a picture of its own.

EVERY STEP WRITES A TEMPORARY NAME AND RENAMES IT INTO PLACE: a reader never opens half a file.
Progress, where a step reports it, is a share in [0, 1] written to `--progress` as face_track.py
writes it.

DECODING IS FFMPEG'S, piped as raw RGB (`--ffmpeg`, ghost's own). The survey decodes only the
frames other frames refer to (`-skip_frame noref`, measured 2026-10-21: 28.9 s of CPU for a minute
of their 1080p60 down to 8.1 s) since it samples every 0.2 s.

THE SURVEY'S FORMAT (survey.bin), little-endian like face_track.py's GFT1:

    magic   4s   b"ACT1"
    version u32  1
    rate    f32  samples per second
    count   u32  samples
    fields  u32  which of FIELDS are present, a bit each in FIELDS' order
    then `count` records: every present f32 field in order, then every present u8 field

A record's size follows from `fields`, so a reader needs nothing else. Coordinates are normalized to
the frame (0..1, origin top-left), as MediaPipe gives them.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import shutil
import struct
import subprocess
import sys

MAGIC = b"ACT1"
VERSION = 1

# name, count, kind ("f" f32 or "B" u8). The order is the file's: a field once written keeps its bit.
FIELDS = [
    ("time", 1, "f"),       # the source video's seconds
    ("found", 1, "f"),      # 1 when a face was found
    ("matrix", 16, "f"),    # MediaPipe's facial transformation matrix, row major
    ("blend", 52, "f"),     # the 52 blendshapes, MediaPipe's order (BLEND_NAMES)
    ("box", 4, "f"),        # the face points' box: x0, y0, x1, y1
    ("pose", 132, "f"),     # 33 body points: x, y, z, visibility
    ("points", 1434, "f"),  # 478 face points: x, y, z
    ("clip", 1, "f"),       # the track's segment this frame belongs to
    ("light", 6, "f"),      # the cheeks' mean and spread, r g b each, 0..1
    ("mask", 576, "B"),     # the person, 32 x 18
    ("thumb", 2304, "B"),   # the frame in gray, 64 x 36
]
SURVEY_FIELDS = ["time", "found", "matrix", "blend", "box", "pose", "mask", "thumb"]

BLEND_NAMES = [
    "_neutral", "browDownLeft", "browDownRight", "browInnerUp", "browOuterUpLeft", "browOuterUpRight",
    "cheekPuff", "cheekSquintLeft", "cheekSquintRight", "eyeBlinkLeft", "eyeBlinkRight",
    "eyeLookDownLeft", "eyeLookDownRight", "eyeLookInLeft", "eyeLookInRight", "eyeLookOutLeft",
    "eyeLookOutRight", "eyeLookUpLeft", "eyeLookUpRight", "eyeSquintLeft", "eyeSquintRight",
    "eyeWideLeft", "eyeWideRight", "jawForward", "jawLeft", "jawOpen", "jawRight", "mouthClose",
    "mouthDimpleLeft", "mouthDimpleRight", "mouthFrownLeft", "mouthFrownRight", "mouthFunnel",
    "mouthLeft", "mouthLowerDownLeft", "mouthLowerDownRight", "mouthPressLeft", "mouthPressRight",
    "mouthPucker", "mouthRight", "mouthRollLower", "mouthRollUpper", "mouthShrugLower",
    "mouthShrugUpper", "mouthSmileLeft", "mouthSmileRight", "mouthStretchLeft", "mouthStretchRight",
    "mouthUpperUpLeft", "mouthUpperUpRight", "noseSneerLeft", "noseSneerRight",
]
# THE MOUTH'S BLENDSHAPES: what a mouth is keyed by, and what a viseme is a target of.
MOUTH_NAMES = [
    "jawOpen", "jawForward", "jawLeft", "jawRight", "mouthClose", "mouthFunnel", "mouthPucker",
    "mouthLeft", "mouthRight", "mouthSmileLeft", "mouthSmileRight", "mouthStretchLeft",
    "mouthStretchRight", "mouthRollLower", "mouthRollUpper", "mouthShrugLower", "mouthShrugUpper",
    "mouthPressLeft", "mouthPressRight", "mouthLowerDownLeft", "mouthLowerDownRight",
    "mouthUpperUpLeft", "mouthUpperUpRight",
]
MOUTH_INDEX = [BLEND_NAMES.index(n) for n in MOUTH_NAMES]

# Pose points: the wrists, and the fingers MediaPipe gives (pinky, index, thumb), each side.
HAND_POINTS = [15, 16, 17, 18, 19, 20, 21, 22]
SHOULDERS = [11, 12]
NOSE = 0

MASK_W, MASK_H = 32, 18
THUMB_W, THUMB_H = 64, 36
SURVEY_W, SURVEY_H = 640, 360

# THE FACE OVAL, in order round the face (MediaPipe's FACE_OVAL connections, walked as a loop).
OVAL = [10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377,
        152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109]
# THE LIPS: outer and inner rings.
LIPS_OUTER = [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409, 270, 269, 267, 0, 37, 39, 40, 185]
LIPS_INNER = [78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308, 415, 310, 311, 312, 13, 82, 81, 80, 191]
# THE EYES' RIMS, each walked round its eye (MediaPipe's FACEMESH_RIGHT_EYE and _LEFT_EYE as loops).
EYE_RIGHT = [33, 246, 161, 160, 159, 158, 157, 173, 133, 155, 154, 153, 145, 144, 163, 7]
EYE_LEFT = [263, 466, 388, 387, 386, 385, 384, 398, 362, 382, 381, 380, 374, 373, 390, 249]
# The brows: never moved with the lids.
BROWS = [46, 53, 52, 65, 55, 70, 63, 105, 66, 107, 276, 283, 282, 295, 285, 300, 293, 334, 296, 336]
# The cheeks, where the light is read: two patches beside the nose, clear of the beard's middle.
CHEEK_LEFT = [50, 101, 118, 117, 123, 187, 205, 36]
CHEEK_RIGHT = [280, 330, 347, 346, 352, 411, 425, 266]
SUBNASALE = 2
CHIN = 152
NOSE_TIP = 1
FACE_POINTS = 468


# --- small things ---------------------------------------------------------------------------------

def say(*parts) -> None:
    print("actor:", *parts, file=sys.stderr, flush=True)


def progress(path: str, frac: float) -> None:
    if not path:
        return
    try:
        with open(path, "w") as f:
            f.write("%.4f\n" % max(0.0, min(1.0, frac)))
    except OSError:
        pass  # progress is a convenience; never fail the run over it


def write_json(path: str, data) -> None:
    tmp = path + ".part"
    with open(tmp, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    os.replace(tmp, path)


def read_json(path: str):
    with open(path) as f:
        return json.load(f)


def head_angles(m) -> tuple:
    """Yaw, pitch and roll in degrees from a facial transformation matrix (row major, 16)."""
    r00, r01, r02 = m[0], m[1], m[2]
    r10, r11, r12 = m[4], m[5], m[6]
    r22 = m[10]
    yaw = math.degrees(math.atan2(r02, r22))
    pitch = -math.degrees(math.asin(max(-1.0, min(1.0, r12))))
    roll = math.degrees(math.atan2(r10, r11))
    return yaw, pitch, roll


def mmss(t: float) -> str:
    t = max(0.0, t)
    return "%d:%02d" % (int(t // 60), int(t % 60))


# --- the track format -----------------------------------------------------------------------------

class Layout:
    """Where each field sits in a record of a file holding [names]."""

    def __init__(self, names):
        self.names = [n for n, _c, _k in FIELDS if n in names]
        self.bits = 0
        self.f_off = {}
        self.b_off = {}
        nf = 0
        nb = 0
        for i, (n, c, k) in enumerate(FIELDS):
            if n not in names:
                continue
            self.bits |= 1 << i
            if k == "f":
                self.f_off[n] = (nf, c)
                nf += c
        for n, c, k in FIELDS:
            if n in names and k == "B":
                self.b_off[n] = (nb, c)
                nb += c
        self.nf = nf
        self.nb = nb
        self.size = nf * 4 + nb

    @staticmethod
    def of_bits(bits: int) -> "Layout":
        return Layout([n for i, (n, _c, _k) in enumerate(FIELDS) if bits & (1 << i)])


class TrackWriter:
    def __init__(self, path: str, names, rate: float):
        self.path = path
        self.tmp = path + ".part"
        self.layout = Layout(names)
        self.rate = rate
        self.count = 0
        self.f = open(self.tmp, "wb")
        self._header()

    def _header(self) -> None:
        self.f.seek(0)
        self.f.write(MAGIC)
        self.f.write(struct.pack("<IfII", VERSION, self.rate, self.count, self.layout.bits))

    def add(self, rec: dict) -> None:
        import numpy as np
        lay = self.layout
        fl = np.zeros(lay.nf, dtype="<f4")
        by = np.zeros(lay.nb, dtype=np.uint8)
        for n, (o, c) in lay.f_off.items():
            v = rec.get(n)
            if v is not None:
                fl[o:o + c] = np.asarray(v, dtype=np.float32).reshape(-1)[:c]
        for n, (o, c) in lay.b_off.items():
            v = rec.get(n)
            if v is not None:
                by[o:o + c] = np.asarray(v, dtype=np.uint8).reshape(-1)[:c]
        self.f.write(fl.tobytes())
        self.f.write(by.tobytes())
        self.count += 1

    def close(self) -> None:
        self._header()
        self.f.close()
        os.replace(self.tmp, self.path)

    def abandon(self) -> None:
        self.f.close()
        try:
            os.remove(self.tmp)
        except OSError:
            pass


class Track:
    """A survey or a track, read whole: each field an array of [count, size]."""

    def __init__(self, path: str):
        import numpy as np
        with open(path, "rb") as f:
            data = f.read()
        if data[:4] != MAGIC:
            raise ValueError("%s is not an ACT1 track" % path)
        _version, self.rate, self.count, bits = struct.unpack("<IfII", data[4:20])
        lay = Layout.of_bits(bits)
        self.layout = lay
        body = np.frombuffer(data, dtype=np.uint8, offset=20, count=self.count * lay.size)
        recs = body.reshape(self.count, lay.size)
        floats = recs[:, :lay.nf * 4].copy().view("<f4").reshape(self.count, lay.nf)
        bytes_ = recs[:, lay.nf * 4:]
        self.f = {}
        for n, (o, c) in lay.f_off.items():
            self.f[n] = floats[:, o:o + c]
        for n, (o, c) in lay.b_off.items():
            self.f[n] = bytes_[:, o:o + c]

    def __getitem__(self, name):
        return self.f[name]

    def has(self, name) -> bool:
        return name in self.f


# --- decoding --------------------------------------------------------------------------------------

def probe(ffmpeg: str, video: str) -> dict:
    """Duration, frame rate and size, by ffprobe beside the given ffmpeg."""
    ffprobe = os.path.join(os.path.dirname(ffmpeg), "ffprobe" + (".exe" if ffmpeg.endswith(".exe") else ""))
    out = subprocess.run([ffprobe, "-v", "error", "-select_streams", "v:0", "-show_entries",
                          "stream=width,height,avg_frame_rate,r_frame_rate:format=duration", "-of", "json", video],
                         capture_output=True, text=True)
    d = json.loads(out.stdout or "{}")
    st = (d.get("streams") or [{}])[0]

    def rate(s):
        try:
            a, b = str(s).split("/")
            return float(a) / float(b) if float(b) else 0.0
        except (ValueError, ZeroDivisionError):
            return 0.0

    fps = rate(st.get("avg_frame_rate")) or rate(st.get("r_frame_rate")) or 30.0
    return {"width": int(st.get("width", 0)), "height": int(st.get("height", 0)), "fps": fps,
            "duration": float((d.get("format") or {}).get("duration", 0.0) or 0.0)}


def frames(ffmpeg: str, video: str, w: int, h: int, rate=None, start=None, length=None, refs_only=False,
           gray=False):
    """Yield (k, frame) from ffmpeg: frame k of the stream, as uint8 [h, w, 3] RGB (or [h, w] gray).

    The command is the same for the same arguments, so the same frames come out of it every time.
    """
    import numpy as np
    cmd = [ffmpeg, "-v", "error", "-nostdin"]
    if refs_only:
        cmd += ["-skip_frame", "noref"]
    if start is not None:
        cmd += ["-ss", "%.4f" % start]
    cmd += ["-i", video]
    if length is not None:
        cmd += ["-t", "%.4f" % length]
    vf = []
    if rate:
        vf.append("fps=%g" % rate)
    vf.append("scale=%d:%d:flags=area" % (w, h))
    cmd += ["-vf", ",".join(vf), "-an", "-f", "rawvideo", "-pix_fmt", "gray" if gray else "rgb24", "-"]
    size = w * h * (1 if gray else 3)
    # (its complaint when the reader stops early - a broken pipe - is no failure: a step is judged by
    # what it wrote)
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stdin=subprocess.DEVNULL, stderr=subprocess.DEVNULL, bufsize=size * 4)
    k = 0
    try:
        while True:
            b = p.stdout.read(size)
            if len(b) < size:
                break
            a = np.frombuffer(b, dtype=np.uint8)
            yield k, (a.reshape(h, w) if gray else a.reshape(h, w, 3))
            k += 1
    finally:
        p.stdout.close()
        p.kill()
        p.wait()


def frame_at(ffmpeg: str, video: str, t: float, w: int, h: int):
    """One frame near [t], scaled to w x h, or None."""
    for _k, f in frames(ffmpeg, video, w, h, start=max(0.0, t), length=0.5):
        return f
    return None


# --- MediaPipe -------------------------------------------------------------------------------------

class Watcher:
    """The face and pose landmarkers: in VIDEO mode they track from one frame to the next (a survey); with
    [image], each frame is a picture of its own (frames picked from all over the footage, where tracking
    across them would carry one face's places into another)."""

    def __init__(self, face_model: str, pose_model: str, masks: bool, image: bool = False):
        from mediapipe.tasks import python as mpp
        from mediapipe.tasks.python import vision
        import mediapipe as mp
        self.mp = mp
        self.image = image
        mode = vision.RunningMode.IMAGE if image else vision.RunningMode.VIDEO
        self.face = vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
            base_options=mpp.BaseOptions(model_asset_path=face_model),
            running_mode=mode, num_faces=1,
            output_face_blendshapes=True, output_facial_transformation_matrixes=True))
        self.pose = vision.PoseLandmarker.create_from_options(vision.PoseLandmarkerOptions(
            base_options=mpp.BaseOptions(model_asset_path=pose_model),
            running_mode=mode, num_poses=1, output_segmentation_masks=masks))
        self.ms = 0

    def look(self, rgb, step_ms: int) -> dict:
        """The face and the body in one frame: a record's fields (no thumb, no light)."""
        import numpy as np
        self.ms += max(1, step_ms)
        img = self.mp.Image(image_format=self.mp.ImageFormat.SRGB, data=np.ascontiguousarray(rgb))
        if self.image:
            fr = self.face.detect(img)
            pr = self.pose.detect(img)
        else:
            fr = self.face.detect_for_video(img, self.ms)
            pr = self.pose.detect_for_video(img, self.ms)
        rec = {"found": 0.0}
        if fr.face_landmarks:
            pts = np.array([(p.x, p.y, p.z) for p in fr.face_landmarks[0]], dtype=np.float32)
            if pts.shape[0] >= 478:
                pts = pts[:478]
                rec["found"] = 1.0
                rec["points"] = pts
                rec["box"] = [float(pts[:FACE_POINTS, 0].min()), float(pts[:FACE_POINTS, 1].min()),
                              float(pts[:FACE_POINTS, 0].max()), float(pts[:FACE_POINTS, 1].max())]
                if fr.face_blendshapes:
                    rec["blend"] = [c.score for c in fr.face_blendshapes[0]][:52]
                if fr.facial_transformation_matrixes:
                    rec["matrix"] = np.asarray(fr.facial_transformation_matrixes[0], dtype=np.float32).reshape(-1)
        if pr.pose_landmarks:
            rec["pose"] = [c for p in pr.pose_landmarks[0] for c in (p.x, p.y, p.z, p.visibility)]
        if pr.segmentation_masks:
            rec["segmentation"] = pr.segmentation_masks[0].numpy_view()
        return rec


def gray_thumb(rgb):
    import cv2
    g = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    return cv2.resize(g, (THUMB_W, THUMB_H), interpolation=cv2.INTER_AREA)


def small_mask(seg):
    import cv2
    import numpy as np
    if seg is None:
        return np.zeros((MASK_H, MASK_W), dtype=np.uint8)
    m = seg.reshape(seg.shape[0], seg.shape[1])
    m = cv2.resize(m, (MASK_W, MASK_H), interpolation=cv2.INTER_AREA)
    return np.clip(m * 255.0 + 0.5, 0, 255).astype(np.uint8)


def cheek_light(rgb, pts, w: int, h: int):
    """The cheeks' mean and spread (r, g, b each, 0..1), from the two patches beside the nose."""
    import cv2
    import numpy as np
    mask = np.zeros(rgb.shape[:2], dtype=np.uint8)
    for patch in (CHEEK_LEFT, CHEEK_RIGHT):
        poly = np.array([[pts[i][0] * w, pts[i][1] * h] for i in patch], dtype=np.float32)
        hull = cv2.convexHull(poly).astype(np.int32)
        cv2.fillConvexPoly(mask, hull, 255)
    sel = rgb[mask > 0]
    if sel.shape[0] < 20:
        return [0.5, 0.5, 0.5, 0.1, 0.1, 0.1]
    sel = sel.astype(np.float32) / 255.0
    return [float(x) for x in sel.mean(axis=0)] + [float(x) for x in sel.std(axis=0)]


def hands_at_mouth(pose, box, margin=0.35, below=0.7) -> bool:
    """Is a hand in the lower half of the face box - grown by [margin] of its width to the sides and by
    [below] of it downward, where a beard is (a hand at the chin, 2026-10-21, stood in a mouth kept)?"""
    if pose is None or box is None:
        return False
    x0, y0, x1, y1 = box
    bw = x1 - x0
    lx0, lx1 = x0 - margin * bw, x1 + margin * bw
    ly0, ly1 = (y0 + y1) * 0.5, y1 + below * bw
    for i in HAND_POINTS:
        x, y, vis = pose[i * 4], pose[i * 4 + 1], pose[i * 4 + 3]
        if vis > 0.5 and lx0 <= x <= lx1 and ly0 <= y <= ly1:
            return True
    return False


# --- survey ----------------------------------------------------------------------------------------

def cmd_survey(a) -> int:
    info = probe(a.ffmpeg, a.video)
    if info["duration"] <= 0.0:
        say("could not read", a.video)
        return 2
    w = TrackWriter(a.out, SURVEY_FIELDS, 1.0 / a.interval)
    watch = Watcher(a.face_model, a.pose_model, masks=True)
    step_ms = int(a.interval * 1000)
    last = -10.0
    try:
        for k, rgb in frames(a.ffmpeg, a.video, SURVEY_W, SURVEY_H, rate=1.0 / a.interval, refs_only=True):
            t = k * a.interval
            rec = watch.look(rgb, step_ms)
            rec["time"] = t
            rec["mask"] = small_mask(rec.pop("segmentation", None))
            rec["thumb"] = gray_thumb(rgb)
            w.add(rec)
            if t - last >= 2.0:
                last = t
                progress(a.progress, t / info["duration"])
    except BaseException:
        w.abandon()
        raise
    if w.count == 0:
        w.abandon()
        say("no frames decoded from", a.video)
        return 2
    w.close()
    progress(a.progress, 1.0)
    say("survey: %d samples of %s" % (w.count, os.path.basename(a.video)))
    return 0


# --- shots -----------------------------------------------------------------------------------------

def find_cuts(thumbs, floor=4.0, rel=2.5, alone=1.8):
    """The sample indices i where a cut MAY fall between sample i-1 and i.

    A cut is a jump in the thumbnails' difference that the samples either side do not share: motion
    raises a run of differences, a cut raises one. A jump cut keeps the room and moves only them, so
    its jump is small - a candidate here is confirmed at the full frame rate ([exact_cut]).
    """
    import numpy as np
    th = thumbs.astype(np.float32)
    n = th.shape[0]
    if n < 3:
        return []
    d = np.zeros(n, dtype=np.float32)
    d[1:] = np.abs(th[1:] - th[:-1]).mean(axis=1)
    cuts = []
    win = 12
    for i in range(1, n):
        lo, hi = max(1, i - win), min(n, i + win + 1)
        local = float(np.median(d[lo:hi]))
        prev = d[i - 1] if i - 1 >= 1 else 0.0
        nxt = d[i + 1] if i + 1 < n else 0.0
        if d[i] > max(floor, rel * local) and d[i] > alone * max(prev, nxt):
            cuts.append(i)
    return cuts


def exact_cut(ffmpeg: str, video: str, t0: float, t1: float, fps: float):
    """The cut between samples t0 and t1, if there is one: (time, how far one frame's jump stands over
    the rest). A CUT IS ONE FRAME: between two frames the picture jumps, and between every other pair
    it moves as it always does; a fast movement spreads its change over every frame."""
    import numpy as np
    prev = None
    diffs = []
    s0 = max(0.0, t0 - 2.0 / fps)
    for k, g in frames(ffmpeg, video, THUMB_W * 2, THUMB_H * 2, start=s0, length=(t1 - s0) + 2.0 / fps, gray=True):
        g = g.astype(np.float32)
        if prev is not None:
            diffs.append((float(np.abs(g - prev).mean()), s0 + k / fps))
        prev = g
    if len(diffs) < 3:
        return t1, 0.0
    diffs.sort(key=lambda x: -x[0])
    best, at = diffs[0]
    rest = float(np.median([x[0] for x in diffs[1:]]))
    second = diffs[1][0]
    return at, best / max(0.5, second, 2.0 * rest)


CUT_STANDS = 2.2  # how far one frame's jump must stand over the next-largest for a cut
# THE CAMERA MOVES when the room does: the mean change of the background (the thumbnail where the
# person is not) between samples, over 2 s. Measured 2026-10-21 on their footage: a camera on a tripod
# reads 0.1 to 0.3 (the sun moving, the encoder), a handheld one 1.5 to 20.
MOVE_AT = 1.0
MOVE_SMOOTH = 10


def camera_motion(tr):
    """Per sample, how much the room moved since the last: the background's change, smoothed."""
    import cv2
    import numpy as np
    n = tr.count
    th = tr["thumb"].astype(np.float32).reshape(-1, THUMB_H, THUMB_W)
    mk = tr["mask"].astype(np.float32).reshape(-1, MASK_H, MASK_W) / 255.0
    up = np.stack([cv2.resize(m, (THUMB_W, THUMB_H), interpolation=cv2.INTER_LINEAR) for m in mk]) if n else mk
    bg = np.zeros(n, dtype=np.float32)
    kernel = np.ones((3, 3), np.uint8)
    for i in range(1, n):
        clear = cv2.erode(((up[i] < 0.1) & (up[i - 1] < 0.1)).astype(np.uint8), kernel) > 0
        bg[i] = float(np.abs(th[i] - th[i - 1])[clear].mean()) if clear.sum() > 200 else bg[i - 1]
    return np.convolve(bg, np.ones(MOVE_SMOOTH) / MOVE_SMOOTH, mode="same")


def split_moving(times, moving, s: float, e: float, least: float):
    """A shot [s, e) in runs where the camera is still or moving: [(start, end, moving)], each run at
    least [least] seconds (a shorter one goes to the run before it)."""
    import numpy as np
    sel = np.nonzero((times >= s) & (times < e))[0]
    if sel.size == 0:
        return [(s, e, False)]
    runs = []
    start = s
    cur = bool(moving[sel[0]])
    for i in sel[1:]:
        m = bool(moving[i])
        if m != cur:
            runs.append([start, float(times[i]), cur])
            start, cur = float(times[i]), m
    runs.append([start, e, cur])
    merged = []
    for r in runs:
        if merged and (r[1] - r[0] < least or merged[-1][2] == r[2]):
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    if len(merged) > 1 and merged[0][1] - merged[0][0] < least:
        merged[1][0] = merged[0][0]
        merged.pop(0)
    return [tuple(r) for r in merged]



def cmd_shots(a) -> int:
    import numpy as np
    info = probe(a.ffmpeg, a.video)
    tr = Track(a.survey)
    times = tr["time"][:, 0]
    cuts = []
    for i in find_cuts(tr["thumb"]):
        at, stands = exact_cut(a.ffmpeg, a.video, float(times[i - 1]), float(times[i]), info["fps"])
        if stands >= CUT_STANDS and (not cuts or at - cuts[-1] > 0.5):
            cuts.append(round(at, 4))
    end = float(info["duration"]) or float(times[-1] + 1.0 / tr.rate)
    edges = [0.0] + cuts + [end]
    moving = camera_motion(tr) > MOVE_AT
    shots, dropped = [], []
    for s, e in zip(edges[:-1], edges[1:]):
        # A SHOT IS ALSO SPLIT WHERE THE CAMERA STARTS OR STOPS MOVING: a handheld stretch, and the
        # camera set down somewhere new after it, are not the room a tripod saw
        for rs, re_, mv in split_moving(times, moving, s, e, max(a.min_shot, 6.0)):
            row = [round(rs, 4), round(re_, 4), bool(mv)]
            (shots if re_ - rs >= a.min_shot else dropped).append(row)
    write_json(a.out, {"duration": end, "fps": info["fps"], "width": info["width"], "height": info["height"],
                       "cuts": cuts, "shots": shots, "dropped": dropped})
    held = sum(1 for x in shots if x[2])
    say("shots: %d cuts, %d shots (%d handheld), %d under %.1f s" % (len(cuts), len(shots), held, len(dropped), a.min_shot))
    return 0


# --- sets ------------------------------------------------------------------------------------------

def shot_profile(tr, s: float, e: float):
    """What a shot looks like: its background's edges, its face box, and its usable samples."""
    import cv2
    import numpy as np
    times = tr["time"][:, 0]
    sel = np.nonzero((times >= s) & (times < e))[0]
    if sel.size == 0:
        return None
    th = tr["thumb"][sel].astype(np.float32).reshape(-1, THUMB_H, THUMB_W)
    mk = tr["mask"][sel].astype(np.float32).reshape(-1, MASK_H, MASK_W) / 255.0
    up = np.stack([cv2.resize(m, (THUMB_W, THUMB_H), interpolation=cv2.INTER_LINEAR) for m in mk])
    # a pixel the person covers - or is near - is not the room
    clear = up < 0.15
    vals = np.where(clear, th, np.nan)
    import warnings
    with warnings.catch_warnings():
        # a pixel the person covers in every sample has no room to take the median of: it is NaN, and left out
        warnings.simplefilter("ignore", category=RuntimeWarning)
        bg = np.nanmedian(vals, axis=0)
    seen = clear.sum(axis=0) >= max(2, int(0.1 * sel.size))
    bg = np.where(seen, bg, np.nan)
    fill = np.where(np.isnan(bg), np.nanmean(bg) if np.any(seen) else 128.0, bg).astype(np.float32)
    gx = cv2.Sobel(fill, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(fill, cv2.CV_32F, 0, 1, ksize=3)
    edge = np.sqrt(gx * gx + gy * gy)
    # a pixel beside one never seen has an edge that is the hole's, not the room's
    near_hole = cv2.dilate((~seen).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    valid = seen & ~near_hole
    mean = float(edge[valid].mean()) if valid.any() else 1.0
    edge = edge / max(mean, 1e-3)
    found = tr["found"][sel, 0] > 0.5
    boxes = tr["box"][sel][found]
    box = [float(x) for x in np.median(boxes, axis=0)] if boxes.shape[0] else None
    usable = 0
    pose = tr["pose"][sel]
    for j in range(sel.size):
        if found[j] and not hands_at_mouth(pose[j], tr["box"][sel[j]]):
            usable += 1
    return {"edge": edge, "valid": valid, "box": box, "samples": sel, "usable": usable,
            "found": int(found.sum()), "bg": fill}


def shot_distance(p, q) -> float:
    import numpy as np
    both = p["valid"] & q["valid"]
    if both.sum() < 0.3 * both.size:
        d_edge = 2.0
    else:
        d_edge = float(np.abs(p["edge"][both] - q["edge"][both]).mean())
    if p["box"] is None or q["box"] is None:
        d_box = 1.0 if (p["box"] is None) != (q["box"] is None) else 0.0
    else:
        pc = ((p["box"][0] + p["box"][2]) * 0.5, (p["box"][1] + p["box"][3]) * 0.5)
        qc = ((q["box"][0] + q["box"][2]) * 0.5, (q["box"][1] + q["box"][3]) * 0.5)
        ps = max(1e-3, p["box"][2] - p["box"][0])
        qs = max(1e-3, q["box"][2] - q["box"][0])
        d_box = math.hypot(pc[0] - qc[0], pc[1] - qc[1]) / 0.15 + abs(math.log(ps / qs)) / 0.35
    return d_edge + 0.35 * d_box


def cluster(n: int, dist, threshold: float):
    """Average-linkage agglomerative clustering: groups of indices, merged while their mean distance
    is under [threshold]."""
    groups = [[i] for i in range(n)]
    # the mean distance between every pair of groups, kept as a table and updated on each merge
    D = [[dist[i][j] for j in range(n)] for i in range(n)]
    size = [1] * n
    alive = set(range(n))
    while len(alive) > 1:
        best, bi, bj = None, -1, -1
        al = sorted(alive)
        for x in range(len(al)):
            i = al[x]
            for y in range(x + 1, len(al)):
                j = al[y]
                if best is None or D[i][j] < best:
                    best, bi, bj = D[i][j], i, j
        if best is None or best > threshold:
            break
        for k in alive:
            if k in (bi, bj):
                continue
            D[bi][k] = D[k][bi] = (D[bi][k] * size[bi] + D[bj][k] * size[bj]) / (size[bi] + size[bj])
        groups[bi] += groups[bj]
        size[bi] += size[bj]
        alive.discard(bj)
    return [sorted(groups[i]) for i in sorted(alive)]


def tile_label(img, text: str) -> None:
    import cv2
    h = img.shape[0]
    scale = max(0.4, h / 400.0)
    cv2.putText(img, text, (8, h - 10), cv2.FONT_HERSHEY_SIMPLEX, scale, (0, 0, 0), 4, cv2.LINE_AA)
    cv2.putText(img, text, (8, h - 10), cv2.FONT_HERSHEY_SIMPLEX, scale, (255, 255, 255), 1, cv2.LINE_AA)


def contact_sheet(ffmpeg: str, picks, out: str, cols=4, tile_w=392, tile_h=220) -> None:
    """A grid of frames - [(video, time, label)] - as one JPEG, each labeled where it is from."""
    import cv2
    import numpy as np
    rows = max(1, (len(picks) + cols - 1) // cols)
    sheet = np.zeros((rows * tile_h, cols * tile_w, 3), dtype=np.uint8)
    for i, (video, t, label) in enumerate(picks):
        f = frame_at(ffmpeg, video, t, tile_w, tile_h)
        if f is None:
            continue
        tile = f.copy()
        tile_label(tile, label)
        r, c = divmod(i, cols)
        sheet[r * tile_h:(r + 1) * tile_h, c * tile_w:(c + 1) * tile_w] = tile
    tmp = out + ".part.jpg"
    cv2.imwrite(tmp, cv2.cvtColor(sheet, cv2.COLOR_RGB2BGR), [cv2.IMWRITE_JPEG_QUALITY, 85])
    os.replace(tmp, out)


def set_id(members) -> str:
    return "set-" + hashlib.sha1("|".join(members).encode()).hexdigest()[:8]


def cmd_sets(a) -> int:
    """Every video's shots grouped into SETS: one camera placement each.

    The spec names the videos: [{vid, path, survey, shots, label}].
    """
    import numpy as np
    spec = read_json(a.spec)
    shots = []          # {vid, n, s, e, profile, video}
    profiles = []
    videos = spec["videos"]
    for vi, v in enumerate(videos):
        tr = Track(v["survey"])
        sh = read_json(v["shots"])
        for n, row in enumerate(sh["shots"]):
            s, e = row[0], row[1]
            p = shot_profile(tr, s, e)
            if p is None:
                continue
            p["size"] = (sh.get("width", 0), sh.get("height", 0))
            p["interval"] = 1.0 / tr.rate
            p["moving"] = bool(row[2]) if len(row) > 2 else False
            shots.append({"vid": v["vid"], "n": n, "s": s, "e": e, "video": v["path"], "label": v.get("label", ""),
                          "vi": vi})
            profiles.append(p)
        progress(a.progress, 0.3 * (vi + 1) / max(1, len(videos)))
    n = len(shots)
    if n == 0:
        write_json(a.out, {"sets": [], "threshold": a.threshold})
        say("sets: no shots")
        return 0
    dist = [[0.0] * n for _ in range(n)]
    for i in range(n):
        for j in range(i + 1, n):
            same = profiles[i]["size"] == profiles[j]["size"] and profiles[i]["moving"] == profiles[j]["moving"]
            d = shot_distance(profiles[i], profiles[j]) if same else 99.0
            dist[i][j] = dist[j][i] = d
    groups = cluster(n, dist, a.threshold)
    sets = []
    for g in groups:
        members = ["%s:%d" % (shots[i]["vid"], shots[i]["n"]) for i in g]
        usable = sum(profiles[i]["usable"] * profiles[i]["interval"] for i in g)
        length = sum(shots[i]["e"] - shots[i]["s"] for i in g)
        sid = set_id(members)
        # the frames the sheet shows: spread over the set's length, where their face is
        picks = []
        for i in g:
            p = profiles[i]
            for j in p["samples"][::max(1, len(p["samples"]) // 4)][:4]:
                picks.append((shots[i]["video"], float(shots[i]["s"]) + 0.0, i, int(j)))
        handheld = all(profiles[i]["moving"] for i in g)
        sets.append({"id": sid, "shots": [{"vid": shots[i]["vid"], "n": shots[i]["n"], "start": shots[i]["s"],
                                            "end": shots[i]["e"], "usable": round(profiles[i]["usable"] * profiles[i]["interval"], 2),
                                            "box": profiles[i]["box"], "moving": profiles[i]["moving"]} for i in g],
                     "minutes": round(length / 60.0, 2), "usable": round(usable / 60.0, 2), "handheld": handheld,
                     "size": list(profiles[g[0]]["size"]), "videos": sorted({shots[i]["vid"] for i in g})})
    # A STEADY SET FIRST: a handheld one's room moves under them, and its joins would show it
    sets.sort(key=lambda s: (s["handheld"], -s["usable"]))
    # within-set and between-set distances, for the card and for tuning the threshold
    os.makedirs(a.sheets, exist_ok=True)
    by_vid = {v["vid"]: v for v in videos}
    for k, st in enumerate(sets):
        st["sheet"] = os.path.join(a.sheets, st["id"] + ".jpg")
        st["shot_sheets"] = []
        # THE SET'S SHEET: 16 frames across its length, each where they are
        spots = []
        total = sum(s["end"] - s["start"] for s in st["shots"])
        for q in range(16):
            at = (q + 0.5) / 16.0 * total
            for s in st["shots"]:
                ln = s["end"] - s["start"]
                if at <= ln:
                    v = by_vid[s["vid"]]
                    spots.append((v["path"], s["start"] + at, "%s %s" % (v.get("label", s["vid"])[:18], mmss(s["start"] + at))))
                    break
                at -= ln
        contact_sheet(a.ffmpeg, spots, st["sheet"])
        # THE SHOTS' SHEETS: one frame from the middle of each shot, sixteen shots a sheet, numbered
        for b in range(0, len(st["shots"]), 16):
            picks = []
            for j, s in enumerate(st["shots"][b:b + 16]):
                v = by_vid[s["vid"]]
                picks.append((v["path"], (s["start"] + s["end"]) * 0.5,
                              "shot %d  %s" % (b + j + 1, mmss((s["start"] + s["end"]) * 0.5))))
            path = os.path.join(a.sheets, "%s_shots_%02d.jpg" % (st["id"], b // 16 + 1))
            contact_sheet(a.ffmpeg, picks, path)
            st["shot_sheets"].append(path)
        progress(a.progress, 0.3 + 0.7 * (k + 1) / len(sets))
    write_json(a.out, {"sets": sets, "threshold": a.threshold, "shots": n})
    say("sets: %d shots in %d sets; the largest %.1f usable minutes" % (n, len(sets), sets[0]["usable"] if sets else 0.0))
    return 0


# --- what the surveys hold -------------------------------------------------------------------------

# THE EYES' LOOK, summed: how far from straight ahead they are looking.
LOOKS = [BLEND_NAMES.index(n) for n in ["eyeLookDownLeft", "eyeLookDownRight", "eyeLookInLeft", "eyeLookInRight",
                                        "eyeLookOutLeft", "eyeLookOutRight", "eyeLookUpLeft", "eyeLookUpRight"]]
BLINK = [BLEND_NAMES.index("eyeBlinkLeft"), BLEND_NAMES.index("eyeBlinkRight")]
JAW = BLEND_NAMES.index("jawOpen")
# Looks this far from a cut are left out: the frames either side of one are neither shot.
CUT_MARGIN = 0.4
# Degrees of turn and tilt within which they are taken to face the camera.
FACING = 25.0


def angles_of(matrices):
    """Yaw, pitch and roll in degrees of every facial transformation matrix in [matrices] ([n, 16]):
    head_angles, all at once."""
    import numpy as np
    m = np.asarray(matrices, dtype=np.float64).reshape(-1, 16)
    yaw = np.degrees(np.arctan2(m[:, 2], m[:, 10]))
    pitch = -np.degrees(np.arcsin(np.clip(m[:, 6], -1.0, 1.0)))
    roll = np.degrees(np.arctan2(m[:, 4], m[:, 5]))
    return np.stack([yaw, pitch, roll], axis=1)


def survey_records(videos, shots, pictures=False):
    """EVERY SURVEY LOOK THAT FOUND A FACE inside [shots] (`[{vid, start, end, set}]`, a little in from
    each cut), across [videos] (`{vid: {survey}}`): one array per field, shot by shot, and where each came
    from - `vid`, `time`, `set`, and `piece` (the shot it is in, so nothing is read across a cut). With
    [pictures], the thumbnails and the person masks too. A video's survey is read once, and let go when
    its shots are done."""
    import numpy as np
    keep = ["blend", "matrix", "box", "pose"] + (["thumb", "mask"] if pictures else [])
    cols = {k: [] for k in keep}
    vids, times, sets, pieces = [], [], [], []
    order = sorted(range(len(shots)), key=lambda k: (str(shots[k]["vid"]), float(shots[k]["start"])))
    vid_in, tr = None, None
    for k in order:
        s = shots[k]
        vid = str(s["vid"])
        if vid != vid_in:
            vid_in = vid
            path = str((videos.get(vid) or {}).get("survey", ""))
            tr = Track(path) if path and os.path.exists(path) else None
        if tr is None:
            continue
        t = tr["time"][:, 0]
        sel = np.nonzero((tr["found"][:, 0] > 0.5) & (t >= float(s["start"]) + CUT_MARGIN)
                         & (t <= float(s["end"]) - CUT_MARGIN))[0]
        if sel.size == 0:
            continue
        for f in keep:
            cols[f].append(tr[f][sel])
        vids += [vid] * sel.size
        times.append(t[sel].astype(np.float64))
        sets += [str(s.get("set", ""))] * sel.size
        pieces.append(np.full(sel.size, k))
    out = {"count": len(vids)}
    widths = {"blend": 52, "matrix": 16, "box": 4, "pose": 132, "thumb": THUMB_W * THUMB_H, "mask": MASK_W * MASK_H}
    for f in keep:
        kind = np.uint8 if f in ("thumb", "mask") else np.float32
        out[f] = np.concatenate(cols[f]).astype(kind) if cols[f] else np.zeros((0, widths[f]), dtype=kind)
    out["vid"] = np.array(vids, dtype=object)
    out["time"] = np.concatenate(times) if times else np.zeros(0)
    out["set"] = np.array(sets, dtype=object)
    out["piece"] = np.concatenate(pieces) if pieces else np.zeros(0, dtype=int)
    out["angles"] = angles_of(out["matrix"]) if out["count"] else np.zeros((0, 3))
    return out


def spaced(order, R, seconds: float, most: int):
    """The first [most] of [order] (indices into the records [R]) with none within [seconds] of another
    in the same video: candidates that are not one moment twice."""
    taken = []
    for i in order:
        i = int(i)
        if all(R["vid"][i] != R["vid"][j] or abs(R["time"][i] - R["time"][j]) >= seconds for j in taken):
            taken.append(i)
            if len(taken) >= most:
                break
    return taken


def hands_at_mouth_all(pose, box, margin=0.35, below=0.7):
    """[hands_at_mouth] for every look at once ([n, 132] and [n, 4])."""
    import numpy as np
    p = np.asarray(pose).reshape(-1, 33, 4)
    b = np.asarray(box).reshape(-1, 4)
    bw = b[:, 2] - b[:, 0]
    lx0, lx1 = b[:, 0] - margin * bw, b[:, 2] + margin * bw
    ly0, ly1 = (b[:, 1] + b[:, 3]) * 0.5, b[:, 3] + below * bw
    out = np.zeros(p.shape[0], dtype=bool)
    for i in HAND_POINTS:
        x, y, vis = p[:, i, 0], p[:, i, 1], p[:, i, 3]
        out |= (vis > 0.5) & (x >= lx0) & (x <= lx1) & (y >= ly0) & (y <= ly1)
    return out


def hands_raised(pose, box):
    """Is a hand up - a wrist seen at the shoulders' height or above - or at the lower face?"""
    import numpy as np
    p = np.asarray(pose).reshape(-1, 33, 4)
    shoulders = p[:, SHOULDERS, 1].mean(axis=1)
    up = np.zeros(p.shape[0], dtype=bool)
    for w in (15, 16):
        up |= (p[:, w, 3] > 0.5) & (p[:, w, 1] < shoulders + 0.08)
    return up | hands_at_mouth_all(pose, box)


def sharpness(rgb, pts, w: int, h: int, region) -> float:
    """How sharp the frame is round the face points [region]: the variance of its Laplacian there (a
    blurred or moving face is low)."""
    import cv2
    import numpy as np
    xy = np.array([[pts[i][0] * w, pts[i][1] * h] for i in region])
    x0, y0 = np.maximum(0, xy.min(axis=0).astype(int) - 4)
    x1, y1 = np.minimum([w, h], xy.max(axis=0).astype(int) + 4)
    if x1 - x0 < 4 or y1 - y0 < 4:
        return 0.0
    g = cv2.cvtColor(np.ascontiguousarray(rgb[y0:y1, x0:x1]), cv2.COLOR_RGB2GRAY)
    return float(cv2.Laplacian(g, cv2.CV_64F).var())


# --- stills ----------------------------------------------------------------------------------------

# A look's thumbnail is counted as straying from the set's usual picture where it differs by this many
# gray levels (of 255): a globe held up, an arm out - while the sun's slow drift over the wall does not.
STRAY = 28
STILL_THUMB_W = 384


def calm_of(R):
    """How much each look moves: the head (degrees) and the hands (shares of the frame) against the looks
    either side in the same shot, each over its own median - 1 is their usual."""
    import numpy as np
    n = R["count"]
    piece = R["piece"]
    hands = np.asarray(R["pose"]).reshape(-1, 33, 4)[:, [15, 16], :2].reshape(n, 4)

    def moved(x):
        d = np.zeros(n)
        if n < 2:
            return d
        step = np.abs(np.diff(x, axis=0)).sum(axis=1)
        same = piece[1:] == piece[:-1]
        d[1:] += np.where(same, step, 0.0)
        d[:-1] += np.where(same, step, 0.0)
        m = np.median(d[d > 0]) if np.any(d > 0) else 1.0
        return d / max(float(m), 1e-9)

    return moved(R["angles"]) + moved(hands)


def hands_up(pose):
    """How far each look's hands are up from where they rest: each wrist seen, its height over the low
    place wrists are seen at in these looks, past a little (in shares of the frame), summed. Their resting
    hands are mostly on the desk, out of the frame or hidden, so the wrists seen are mostly raised ones: the
    middle of where they are seen is a gesture (2026-10-21: every still came out mid-gesture), the low end
    of it is rest."""
    import numpy as np
    p = np.asarray(pose).reshape(-1, 33, 4)
    out = np.zeros(p.shape[0])
    for w in (15, 16):
        seen = p[:, w, 3] > 0.5
        if not np.any(seen):
            continue
        rest = float(np.percentile(p[seen, w, 1], 85))
        out += np.where(seen, np.clip(rest - p[:, w, 1] - 0.05, 0.0, None) / 0.1, 0.0)
    return out


# THE FACE AT REST: brows neither up nor down, no smile, no squint - each counted against a still.
EXPRESSION = [BLEND_NAMES.index(n) for n in ["browInnerUp", "browOuterUpLeft", "browOuterUpRight", "browDownLeft",
                                             "browDownRight", "mouthSmileLeft", "mouthSmileRight", "cheekSquintLeft",
                                             "cheekSquintRight", "eyeWideLeft", "eyeWideRight"]]


def cmd_stills(a) -> int:
    """A SET'S STILLS: its most typical calm moments facing the camera, each a candidate for the one frame
    a Likeness is drawn on (next/likeness.md, "The second build"). Found in the survey, then looked at
    again at full size - the face found, the eyes open, the mouth closed, sharp."""
    import cv2
    import numpy as np
    spec = read_json(a.spec)
    count = int(spec.get("count", 6))
    R = survey_records(spec["videos"], spec["shots"], pictures=True)
    n = R["count"]
    if n < 20:
        say("stills: the set has too little usable footage (%d looks)" % n)
        return 2
    # WHAT THE SET USUALLY LOOKS LIKE (the user: "the average of all samples is likely to be a pretty
    # normal, forward-facing actor"): its median picture and person, and how much of each look strays
    # from them - counted in places, so that the light's drift is not
    th = R["thumb"].astype(np.float32)
    strays = (np.abs(th - np.median(th, axis=0)) > STRAY).mean(axis=1)
    mk = R["mask"].astype(np.float32)
    person = np.abs(mk - np.median(mk, axis=0)).mean(axis=1) / 255.0
    base = (strays * 8.0 + person * 6.0 + calm_of(R) * 0.5 + hands_raised(R["pose"], R["box"]) * 5.0
            + hands_up(R["pose"]) * 2.0)

    def face_cost(blend, yaw, pitch, roll):
        bl = np.asarray(blend, dtype=np.float64).reshape(-1, 52)
        return ((np.abs(yaw) + np.abs(pitch) + np.abs(roll)) / 8.0 + bl[:, BLINK].mean(axis=1) * 4.0
                + bl[:, LOOKS].sum(axis=1) * 1.5 + bl[:, JAW] * 6.0 + bl[:, EXPRESSION].sum(axis=1) * 3.0)

    ang = R["angles"]
    score = base + face_cost(R["blend"], ang[:, 0], ang[:, 1], ang[:, 2])
    picks = spaced(np.argsort(score), R, 8.0, count * 4)
    progress(a.progress, 0.05)
    watch = Watcher(a.face_model, a.pose_model, masks=False, image=True)
    found = []
    for j, i in enumerate(picks):
        v = spec["videos"][R["vid"][i]]
        W, H = int(v["size"][0]), int(v["size"][1])
        rgb = frame_at(a.ffmpeg, v["path"], float(R["time"][i]), W, H)
        progress(a.progress, 0.05 + 0.85 * (j + 1) / len(picks))
        if rgb is None:
            continue
        rec = watch.look(rgb, 0)
        if rec["found"] < 0.5 or "blend" not in rec or "matrix" not in rec:
            continue
        yaw, pitch, roll = head_angles(rec["matrix"])
        found.append({"i": i, "rgb": rgb, "rec": rec, "size": [W, H], "angles": (yaw, pitch, roll),
                      "sharp": sharpness(rgb, rec["points"], W, H, OVAL),
                      "face": float(face_cost(rec["blend"], yaw, pitch, roll)[0])})
    if not found:
        say("stills: no face was found at full size")
        return 2
    med = float(np.median([f["sharp"] for f in found])) or 1.0
    for f in found:
        f["score"] = float(base[f["i"]]) + f["face"] + 2.0 * max(0.0, 1.0 - f["sharp"] / med)
    found.sort(key=lambda f: f["score"])
    # (spaced already when they were picked)
    chosen = found[:count]
    out_dir = spec["out"]
    part = out_dir + ".part"
    shutil.rmtree(part, ignore_errors=True)
    os.makedirs(part)
    stills = []
    for k, f in enumerate(chosen):
        W, H = f["size"]
        rec = f["rec"]
        bgr = cv2.cvtColor(f["rgb"], cv2.COLOR_RGB2BGR)
        name, thumb = "still_%d.jpg" % k, "still_%d_thumb.jpg" % k
        cv2.imwrite(os.path.join(part, name), bgr, [cv2.IMWRITE_JPEG_QUALITY, 95])
        small = cv2.resize(bgr, (STILL_THUMB_W, int(round(STILL_THUMB_W * H / W))), interpolation=cv2.INTER_AREA)
        cv2.imwrite(os.path.join(part, thumb), small, [cv2.IMWRITE_JPEG_QUALITY, 88])
        i = f["i"]
        stills.append({"file": name, "thumb": thumb, "vid": str(R["vid"][i]), "time": round(float(R["time"][i]), 3),
                       "set": str(R["set"][i]), "size": [W, H],
                       "points": [[round(float(c), 5) for c in p] for p in rec["points"]],
                       "matrix": [round(float(x), 6) for x in rec["matrix"]],
                       "blend": [round(float(x), 4) for x in rec["blend"]],
                       "light": [round(float(x), 4) for x in cheek_light(f["rgb"], rec["points"], W, H)],
                       "yaw": round(f["angles"][0], 2), "pitch": round(f["angles"][1], 2), "roll": round(f["angles"][2], 2),
                       "sharp": round(f["sharp"], 1), "score": round(f["score"], 3)})
    shutil.rmtree(out_dir, ignore_errors=True)
    os.replace(part, out_dir)
    write_json(spec["index"], {"stills": stills})
    progress(a.progress, 1.0)
    say("stills: %d, the best of %d looked at in %d looks" % (len(stills), len(found), n))
    return 0


# --- rig -------------------------------------------------------------------------------------------

def to_pixels(points, w: int, h: int):
    """[n, 478, 3] normalized -> [n, 468, 2] pixels."""
    import numpy as np
    p = np.asarray(points).reshape(-1, 478, 3)[:, :FACE_POINTS, :2].astype(np.float64)
    return p * np.array([w, h], dtype=np.float64)


def similarity(src, dst):
    """The similarity (scale, rotation, translation) taking src [n, 2] onto dst [n, 2]: (s, R, t)."""
    import numpy as np
    ms, md = src.mean(axis=0), dst.mean(axis=0)
    a, b = src - ms, dst - md
    den = (a * a).sum()
    if den <= 0:
        return 1.0, np.eye(2), md - ms
    c = (a[:, 0] * b[:, 0] + a[:, 1] * b[:, 1]).sum() / den
    s_ = (a[:, 0] * b[:, 1] - a[:, 1] * b[:, 0]).sum() / den
    scale = math.hypot(c, s_)
    R = np.array([[c, -s_], [s_, c]]) / max(scale, 1e-9)
    t = md - scale * (R @ ms)
    return scale, R, t


def ring_of(face2d, scale: float):
    """The ring at [scale] round the face oval: the oval's points pushed out from its middle."""
    oval = face2d[OVAL]
    c = oval.mean(axis=0)
    return c + scale * (oval - c)


def edge_anchors(w: int, h: int, per_side=6):
    pts = []
    for i in range(per_side + 1):
        u = i / per_side
        pts += [(u * w, 0.0), (u * w, float(h))]
    for i in range(1, per_side):
        v = i / per_side
        pts += [(0.0, v * h), (float(w), v * h)]
    return pts


def triangulate(allpts, w: int, h: int):
    """ONE TRIANGULATION over every mesh point, the frame's edge too (Delaunay, OpenCV's Subdiv2D):
    `[[i, j, k]]`."""
    import cv2
    import numpy as np
    lo_x = min(-1.0, float(allpts[:, 0].min()) - 10)
    lo_y = min(-1.0, float(allpts[:, 1].min()) - 10)
    hi_x = max(w + 1.0, float(allpts[:, 0].max()) + 10)
    hi_y = max(h + 1.0, float(allpts[:, 1].max()) + 10)
    sub = cv2.Subdiv2D((int(lo_x), int(lo_y), int(hi_x - lo_x) + 1, int(hi_y - lo_y) + 1))
    key = {}
    for i, p in enumerate(allpts):
        q = (float(p[0]), float(p[1]))
        sub.insert(q)
        key[(round(q[0], 3), round(q[1], 3))] = i
    tris = []
    for t6 in sub.getTriangleList():
        ids = []
        for j in range(3):
            q = (round(float(t6[2 * j]), 3), round(float(t6[2 * j + 1]), 3))
            if q not in key:
                # a point Subdiv2D moved by a rounding: the nearest one
                d = np.hypot(allpts[:, 0] - t6[2 * j], allpts[:, 1] - t6[2 * j + 1])
                ids.append(int(d.argmin()) if d.min() < 0.5 else -1)
            else:
                ids.append(key[q])
        if -1 in ids or len(set(ids)) < 3:
            continue
        tris.append(ids)
    return tris


def mouth_weights(layout):
    """How much each face point moves with the mouth (0 the head, 1 the lips and the jaw): by where it
    is in the layout - below the nose and between the cheeks."""
    import numpy as np
    sub = layout[SUBNASALE]
    chin = layout[CHIN]
    corners = layout[[61, 291]]
    half = max(1.0, abs(corners[1, 0] - corners[0, 0]) * 0.5)
    mid_x = (corners[0, 0] + corners[1, 0]) * 0.5
    height = max(1.0, chin[1] - sub[1])
    w = np.zeros(FACE_POINTS)
    for i in range(FACE_POINTS):
        x, y = layout[i]
        dy = (y - sub[1]) / height                   # 0 at the nose's foot, 1 at the chin
        dx = abs(x - mid_x) / half                   # 1 at a mouth corner
        vert = np.clip((dy + 0.15) / 0.35, 0.0, 1.0)  # rises just above the nose's foot
        horiz = np.clip((2.3 - dx) / 0.9, 0.0, 1.0)   # falls off past the corners, to the cheeks
        w[i] = float(vert * horiz)
    for i in LIPS_OUTER + LIPS_INNER:
        w[i] = 1.0
    return w


def eye_weights(layout):
    """How much each face point moves with the eyelids (0 the rest of the face, 1 the lids' rims): by its
    distance from an eye's middle, in eye widths - the brows never."""
    import numpy as np
    w = np.zeros(FACE_POINTS)
    for rim in (EYE_RIGHT, EYE_LEFT):
        pts = layout[rim]
        c = pts.mean(axis=0)
        width = max(1.0, float(pts[:, 0].max() - pts[:, 0].min()))
        d = np.hypot(layout[:, 0] - c[0], layout[:, 1] - c[1]) / width
        w = np.maximum(w, np.clip((0.95 - d) / 0.45, 0.0, 1.0))
        w[rim] = 1.0
    w[BROWS] = 0.0
    return w


def feathered(shape, polys, sigma: float):
    """A mask of [shape] (h, w): [polys] filled, blurred by [sigma] pixels, its middle kept whole."""
    import cv2
    import numpy as np
    m = np.zeros(shape, dtype=np.float32)
    for p in polys:
        cv2.fillPoly(m, [np.round(p).astype(np.int32)], 1.0)
    m = cv2.GaussianBlur(m, (0, 0), max(0.5, sigma))
    return np.clip((m - 0.1) / 0.6, 0.0, 1.0)


def grown(poly, sx: float, sy: float):
    """[poly] pushed out from its middle, [sx] across and [sy] up and down."""
    import numpy as np
    c = poly.mean(axis=0)
    return c + (poly - c) * np.array([sx, sy])


def save_mask(path: str, m) -> None:
    import cv2
    import numpy as np
    cv2.imwrite(path + ".part.png", np.clip(m * 255 + 0.5, 0, 255).astype(np.uint8))
    os.replace(path + ".part.png", path)


def cmd_rig(a) -> int:
    """THE SET'S MESH, made on its first still: its face, the rings round it, the frame's edge, one
    triangulation - and the face's BOX, where the library keeps its mouths and eyes, with a mask for
    each: the lips with a little round them, and each eye's lids (the beard round the mouth stays the
    still's, bent with the jaw, and never swaps from one mouth to the next)."""
    import numpy as np
    stills = read_json(a.stills)["stills"]
    if not stills:
        say("rig: the set has no still")
        return 2
    st = stills[0]
    W, H = int(st["size"][0]), int(st["size"][1])
    layout = to_pixels([st["points"]], W, H)[0]
    anchors = np.array(edge_anchors(W, H), dtype=np.float64)
    allpts = np.vstack([layout, ring_of(layout, a.ring1), ring_of(layout, a.ring2), anchors])
    tris = triangulate(allpts, W, H)
    weights = mouth_weights(layout)
    eyes = eye_weights(layout)
    # THE BOX: from over the brows to under the chin, between the cheeks
    oval = layout[OVAL]
    fw = float(oval[:, 0].max() - oval[:, 0].min())
    fh = float(layout[CHIN][1] - layout[10][1])
    x0 = float(oval[:, 0].min() - 0.04 * fw)
    x1 = float(oval[:, 0].max() + 0.04 * fw)
    y0 = float(layout[BROWS][:, 1].min() - 0.03 * fh)
    y1 = float(layout[CHIN][1] + 0.10 * fh)
    img_w = int(a.box_width)
    img_h = max(64, min(1024, int(round(img_w * (y1 - y0) / max(1e-3, x1 - x0) / 8.0)) * 8))

    def to_img(p):
        return (np.asarray(p) - np.array([x0, y0])) / np.array([x1 - x0, y1 - y0]) * np.array([img_w, img_h])

    lips = to_img(layout[LIPS_OUTER])
    mouth_w = float(lips[:, 0].max() - lips[:, 0].min())
    mouth = feathered((img_h, img_w), [grown(lips, 1.18, 1.45)], mouth_w * 0.06)
    rims = [to_img(layout[EYE_RIGHT]), to_img(layout[EYE_LEFT])]
    eye_w = float(np.mean([r[:, 0].max() - r[:, 0].min() for r in rims]))
    eye_mask = feathered((img_h, img_w), [grown(r, 1.45, 2.2) for r in rims], eye_w * 0.12)
    out_dir = os.path.dirname(a.out)
    save_mask(os.path.join(out_dir, "mask_mouth.png"), mouth)
    save_mask(os.path.join(out_dir, "mask_eyes.png"), eye_mask)

    # THE TRIANGLES THAT MOVE MOST LAST: a canvas mesh draws in order, so lips and lids are never under a fold
    def moving(t):
        return min(max(weights[i], eyes[i]) if i < FACE_POINTS else 0.0 for i in t) > 0.5
    tris.sort(key=lambda t: 1 if moving(t) else 0)
    rig = {
        "size": [W, H], "points": int(allpts.shape[0]), "face": FACE_POINTS, "oval": OVAL,
        "ring1": a.ring1, "ring2": a.ring2, "ring_moves": a.ring_moves,
        "layout": [[round(float(x), 3), round(float(y), 3)] for x, y in layout],
        "mean": [[round(float(x), 2), round(float(y), 2)] for x, y in allpts],
        "anchors": [[round(x / W, 5), round(y / H, 5)] for x, y in anchors],
        "triangles": tris, "moving_triangles": sum(1 for t in tris if moving(t)),
        "weights": [round(float(x), 3) for x in weights],
        "eye_weights": [round(float(x), 3) for x in eyes],
        "box": [round(x0, 3), round(y0, 3), round(x1, 3), round(y1, 3)], "image": [img_w, img_h],
        "masks": {"mouth": "mask_mouth.png", "eyes": "mask_eyes.png"},
        "lips": LIPS_OUTER + LIPS_INNER, "cheeks": [CHEEK_LEFT, CHEEK_RIGHT],
    }
    write_json(a.out, rig)
    say("rig: %d points, %d triangles, the face's box %dx%d" % (allpts.shape[0], len(tris), img_w, img_h))
    return 0


# --- the rig in one frame ----------------------------------------------------------------------------

class Rig:
    def __init__(self, path: str):
        import numpy as np
        d = read_json(path)
        self.d = d
        self.W, self.H = d["size"]
        self.layout = np.array(d["layout"], dtype=np.float64)
        self.tris = np.array(d["triangles"], dtype=np.int32)
        self.weights = np.array(d["weights"], dtype=np.float64)
        self.eye_weights = np.array(d.get("eye_weights", [0.0] * FACE_POINTS), dtype=np.float64)
        self.box = d["box"]
        self.img_w, self.img_h = d["image"]
        self.anchors = np.array(d["anchors"], dtype=np.float64) * np.array([self.W, self.H])
        self.ring1, self.ring2 = d["ring1"], d["ring2"]

    def steady(self):
        """The points a frame is aligned to the layout by: the ones that move with neither the mouth nor
        the lids."""
        import numpy as np
        return np.nonzero((self.weights < 0.2) & (self.eye_weights < 0.2))[0]

    def to_layout(self, face2d):
        """A frame's face, aligned onto the layout by its steady points: [468, 2] in the layout."""
        idx = self.steady()
        s, R, t = similarity(face2d[idx], self.layout[idx])
        return (s * (R @ face2d.T)).T + t

    def frame_points(self, face2d):
        """Every mesh point in a frame whose 468 face points (pixels) are [face2d]."""
        import numpy as np
        return np.vstack([face2d, ring_of(face2d, self.ring1), ring_of(face2d, self.ring2), self.anchors])

    def layout_points(self):
        """Every mesh point's place in the box's image (pixels of it): the layout, with its rings."""
        import numpy as np
        x0, y0, x1, y1 = self.box
        lay = np.vstack([self.layout, ring_of(self.layout, self.ring1), ring_of(self.layout, self.ring2)])
        return (lay - np.array([x0, y0])) / np.array([x1 - x0, y1 - y0]) * np.array([self.img_w, self.img_h])

    def box_triangles(self):
        """The triangles that touch the box (no edge anchor among them)."""
        import numpy as np
        lay = self.layout_points()
        n = lay.shape[0]
        out = []
        for t in self.tris:
            if max(t) >= n:
                continue
            p = lay[t]
            if p[:, 0].max() < 0 or p[:, 1].max() < 0 or p[:, 0].min() > self.img_w or p[:, 1].min() > self.img_h:
                continue
            out.append(t)
        return np.array(out, dtype=np.int32)


def warp_triangles(src, src_pts, dst_pts, tris, out_shape):
    """Each triangle of [src] at [src_pts] drawn at [dst_pts] in an image of [out_shape]: a piecewise
    affine warp, triangle by triangle."""
    import cv2
    import numpy as np
    out = np.zeros(out_shape, dtype=src.dtype)
    H, W = out_shape[:2]
    for t in tris:
        s = src_pts[t].astype(np.float32)
        d = dst_pts[t].astype(np.float32)
        x, y, w, h = cv2.boundingRect(d)
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(W, x + w), min(H, y + h)
        if x1 <= x0 or y1 <= y0:
            continue
        u, v = d[1] - d[0], d[2] - d[0]
        if abs(float(u[0] * v[1] - u[1] * v[0])) < 1e-6:
            continue
        M = cv2.getAffineTransform(s, (d - np.array([x0, y0], dtype=np.float32)).astype(np.float32))
        patch = cv2.warpAffine(src, M, (x1 - x0, y1 - y0), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
        m = np.zeros((y1 - y0, x1 - x0), dtype=np.uint8)
        cv2.fillConvexPoly(m, np.round(d - np.array([x0, y0])).astype(np.int32), 1, lineType=cv2.LINE_8)
        region = out[y0:y1, x0:x1]
        region[m > 0] = patch[m > 0]
    return out


def unwrap(rgb, face2d, rig: Rig, tris):
    """A frame's face, in the box: what the library keeps of a mouth or an eye."""
    src = rig.frame_points(face2d)[: rig.layout_points().shape[0]]
    dst = rig.layout_points()
    return warp_triangles(rgb, src, dst, tris, (rig.img_h, rig.img_w, 3))


# --- visemes ---------------------------------------------------------------------------------------

def cmd_visemes(a) -> int:
    """THEIR MOUTH FOR EACH SOUND CLASS, from every video's survey: the median of their mouth blendshapes
    at the class's phones - where captions give enough of them - else the class's place in their own range
    (each class's `range`: a percentile of their range per blendshape)."""
    import numpy as np
    spec = read_json(a.spec)
    R = survey_records(spec["videos"], spec["shots"])
    if R["count"] < 50:
        say("visemes: too little usable footage (%d looks)" % R["count"])
        return 2
    ang = R["angles"]
    facing = (np.abs(ang[:, 0]) < FACING) & (np.abs(ang[:, 1]) < FACING)
    bl = R["blend"][:, MOUTH_INDEX].astype(np.float64)
    have = bl[facing] if facing.sum() >= 50 else bl
    pct = {q: np.percentile(have, q, axis=0) for q in (5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 97, 99)}
    # each phone's look: the one nearest its middle, within half the survey's spacing
    times = {}
    for vid in set(R["vid"].tolist()):
        idx = np.nonzero(R["vid"] == vid)[0]
        times[vid] = (idx, R["time"][idx])
    hits = {}
    for ph in spec.get("phones", []):
        cls = ph.get("class")
        got = times.get(str(ph.get("vid")))
        if not cls or got is None:
            continue
        idx, tv = got
        mid = (float(ph["t0"]) + float(ph["t1"])) * 0.5
        j = int(np.searchsorted(tv, mid))
        best = [k for k in (j - 1, j) if 0 <= k < tv.size]
        if not best:
            continue
        k = min(best, key=lambda k: abs(tv[k] - mid))
        if abs(tv[k] - mid) <= 0.11:
            hits.setdefault(cls, []).append(bl[idx[k]])
    out = {}
    least = int(spec.get("least", 30))
    for cls, row in spec["classes"].items():
        got = hits.get(cls, [])
        if len(got) >= least:
            med = np.median(np.array(got), axis=0)
            out[cls] = {"blend": [round(float(x), 4) for x in med], "n": len(got), "from": "captions"}
            continue
        from_range = pct[50].copy()
        for name, q in (row.get("range") or {}).items():
            if name in MOUTH_NAMES:
                from_range[MOUTH_NAMES.index(name)] = pct[min(pct, key=lambda p: abs(p - int(q)))][MOUTH_NAMES.index(name)]
        out[cls] = {"blend": [round(float(x), 4) for x in from_range], "n": len(got), "from": "range"}
    write_json(a.out, {"names": MOUTH_NAMES, "classes": out,
                       "range": {str(q): [round(float(x), 4) for x in v] for q, v in pct.items()}})
    learned = sum(1 for c in out.values() if c["from"] == "captions")
    if learned:
        say("visemes: %d sounds, %d learned from captions, the rest from their range" % (len(out), learned))
    else:
        say("visemes: %d sounds, from their own range (no captions)" % len(out))
    return 0


# --- motion ----------------------------------------------------------------------------------------

# THE HEAD'S MOTION, a row per look: yaw, pitch and roll (degrees), where the face is across and down (in
# face widths) and how near (the log of its width).
AXES = ["yaw", "pitch", "roll", "x", "y", "near"]
# A run is at least this many seconds; its quick part is what moves within this many.
LEAST_RUN = 8.0
DRIFT = 4.0
# A look this many of their own spreads off on any axis ends a run there: a turn to a screen, a lean out.
WILD = 4.0
# A blink is caught by a look only when it falls in one: about the share of the spacing a blink lasts.
CAUGHT = 0.55


def high_pass(X, k: int):
    """[X] ([n, d]) less its own mean over the [k] looks round each (k odd), the ends mirrored: what is
    quick in it."""
    import numpy as np
    X = np.asarray(X, dtype=np.float64)
    h = k // 2
    if X.shape[0] <= h + 1:
        return X - X.mean(axis=0)
    pad = np.concatenate([X[h:0:-1], X, X[-2:-h - 2:-1]], axis=0)
    ker = np.ones(k) / k
    smooth = np.stack([np.convolve(pad[:, j], ker, mode="valid") for j in range(X.shape[1])], axis=1)
    return X - smooth


def runs_of(R, rate: float, facing):
    """The records' runs: indices of looks one after another in one shot, facing the camera, with no
    gap - each at least [LEAST_RUN] seconds."""
    import numpy as np
    out = []
    cur = []
    for i in range(R["count"]):
        ok = bool(facing[i])
        joined = cur and R["piece"][i] == R["piece"][cur[-1]] and R["time"][i] - R["time"][cur[-1]] < 1.6 / rate
        if ok and (not cur or joined):
            cur.append(i)
            continue
        if len(cur) >= LEAST_RUN * rate:
            out.append(np.array(cur))
        cur = [i] if ok else []
    if len(cur) >= LEAST_RUN * rate:
        out.append(np.array(cur))
    return out


def head_rows(R, idx, aspect):
    """The head's [AXES] at looks [idx]: the turn, and where the face's box is in face widths."""
    import numpy as np
    box = R["box"][idx].astype(np.float64)
    bw = np.maximum(box[:, 2] - box[:, 0], 1e-4)
    fw = float(np.median(bw))
    cx = (box[:, 0] + box[:, 2]) * 0.5 / fw
    cy = (box[:, 1] + box[:, 3]) * 0.5 * aspect / fw
    return np.column_stack([R["angles"][idx], cx, cy, np.log(bw / fw)])


def blinks_per_minute(R, runs, rate: float) -> float:
    """HOW OFTEN THEY BLINK, from looks a fifth of a second apart: a look with both eyes far more closed
    than the run's own usual is a blink caught, and a blink is caught about [CAUGHT] of the time."""
    import numpy as np
    events, looks = 0, 0
    for idx in runs:
        b = R["blend"][idx][:, BLINK].astype(np.float64)
        both = b.min(axis=1)
        k = max(3, int(10 * rate) | 1)
        base = np.array([np.median(both[max(0, i - k // 2): i + k // 2 + 1]) for i in range(both.size)])
        shut = both - base > 0.3
        events += int(np.count_nonzero(shut[1:] & ~shut[:-1]) + (1 if shut.size and shut[0] else 0))
        looks += both.size
    minutes = looks / rate / 60.0
    if minutes <= 0:
        return 16.0
    return float(np.clip(events / minutes / CAUGHT, 6.0, 30.0))


def cmd_motion(a) -> int:
    """THEIR HEAD'S OWN MOTION, from every video's survey where they face the camera: its quick part (the
    slow drift out), in runs a Likeness plays back in pieces, which looks are speech, and how often they
    blink (next/likeness.md, "The second build")."""
    import numpy as np
    spec = read_json(a.spec)
    rate = float(spec.get("rate", 5.0))
    R = survey_records(spec["videos"], spec["shots"])
    if R["count"] < LEAST_RUN * rate:
        say("motion: too little usable footage (%d looks)" % R["count"])
        return 2
    ang = R["angles"]
    facing = (np.abs(ang[:, 0]) < FACING) & (np.abs(ang[:, 1]) < FACING)
    runs = runs_of(R, rate, facing)
    k = max(3, int(round(DRIFT * rate)) | 1)
    trim = int(round(rate))
    jaw = R["blend"][:, JAW].astype(np.float64)
    pieces = []
    for idx in runs:
        v = spec["videos"].get(R["vid"][idx[0]], {})
        size = v.get("size", [16, 9])
        X = high_pass(head_rows(R, idx, float(size[1]) / float(size[0])), k)[trim:-trim]
        j = jaw[idx]
        spread = np.array([j[max(0, i - 5): i + 6].std() for i in range(j.size)])[trim:-trim]
        pieces.append((idx[trim:-trim], X, spread))
    if not pieces:
        say("motion: no run of %d seconds facing the camera" % int(LEAST_RUN))
        return 2
    allx = np.concatenate([p[1] for p in pieces])
    sd = 1.4826 * np.median(np.abs(allx - np.median(allx, axis=0)), axis=0)
    sd = np.maximum(sd, 1e-6)
    talking = float(np.median(np.concatenate([p[2] for p in pieces])))
    # A LOOK FAR OUT ON ANY AXIS ENDS ITS RUN: what is kept is how they move while they talk to the camera
    out = []
    for idx, X, spread in pieces:
        wild = (np.abs(X) > WILD * sd).any(axis=1)
        start = 0
        for i in range(X.shape[0] + 1):
            if i == X.shape[0] or wild[i]:
                if i - start >= LEAST_RUN * rate:
                    out.append({"vid": str(R["vid"][idx[start]]), "t0": round(float(R["time"][idx[start]]), 2),
                                "talk": "".join("1" if s > talking else "0" for s in spread[start:i]),
                                "rows": [[round(float(x), 4) for x in r] for r in X[start:i]]})
                start = i + 1
    out.sort(key=lambda r: -len(r["rows"]))
    most = int(float(spec.get("most_minutes", 60.0)) * 60.0 * rate)
    kept, total = [], 0
    for r in out:
        if total >= most:
            break
        kept.append(r)
        total += len(r["rows"])
    blinks = blinks_per_minute(R, runs, rate)
    write_json(a.out, {"rate": rate, "axes": AXES, "sd": [round(float(x), 5) for x in sd],
                       "blinks_per_min": round(blinks, 1), "runs": kept})
    say("motion: %.0f minutes of their head in %d runs, %.0f blinks a minute" % (total / rate / 60.0, len(kept), blinks))
    return 0


# --- library ---------------------------------------------------------------------------------------

# HOW MUCH EACH OF A MOUTH'S BLENDSHAPES WEIGHS, per one of their own spreads (2026-10-21: their
# blendshapes span a few hundredths - jawOpen 0.01 to 0.22 - so raw values matched every sound to one
# mouth). The jaw and the lips' rounding and pressing carry what a sound looks like; the rest less -
# mouthClose least: it is the lips held together WITH the jaw open, so it rises on open mouths.
KEY_WEIGHT = {"jawOpen": 3.0, "mouthClose": 0.3, "mouthFunnel": 1.5, "mouthPucker": 1.5,
              "mouthRollLower": 1.0, "mouthRollUpper": 1.0, "mouthStretchLeft": 0.8, "mouthStretchRight": 0.8,
              "mouthSmileLeft": 0.8, "mouthSmileRight": 0.8, "mouthPressLeft": 0.8, "mouthPressRight": 0.8,
              "mouthLowerDownLeft": 1.0, "mouthLowerDownRight": 1.0, "mouthShrugLower": 0.7,
              "mouthShrugUpper": 0.5, "mouthUpperUpLeft": 0.5, "mouthUpperUpRight": 0.5,
              "jawForward": 0.3, "jawLeft": 0.3, "jawRight": 0.3, "mouthLeft": 0.5, "mouthRight": 0.5}
# a blendshape that barely moves is noise: it is never weighed as if its spread were less than this
SPREAD_FLOOR = 0.02
# How far (degrees) a mouth's or an eye's turn and tilt may be from the still's; one unit of cost per
# this many degrees; the cost of coming from another set (another camera, another light).
NEAR_TURN = 12.0
DEGREES = 6.0
OTHER_SET = 1.5
# Candidates looked at again at full size, for each sound class and each eye state.
CANDIDATES = 10
# THE EYES' STATES the library keeps (both eyes' blink): the open one is the still's own.
EYE_STATES = {"half": 0.45, "closed": 0.9}


def mouth_scale(blend):
    """Each mouth blendshape's weight per unit, from their own looks [blend] ([n, MOUTH_NAMES])."""
    import numpy as np
    sd = np.maximum(np.asarray(blend, dtype=np.float64).std(axis=0), SPREAD_FLOOR)
    return np.array([KEY_WEIGHT.get(n, 0.5) for n in MOUTH_NAMES]) / sd


# THE SHAPES A SOUND IS SEEN BY, pushed past their own: the jaw, the lips' rounding, spreading, pressing
# and rolling. Not mouthClose (the lips together with the jaw open: pushed, it chose open jaws for P, B
# and M - 2026-10-21, the first library), and not the jaw's sideways slides.
PUSHED = [MOUTH_NAMES.index(n) for n in ["jawOpen", "mouthFunnel", "mouthPucker", "mouthStretchLeft",
                                         "mouthStretchRight", "mouthSmileLeft", "mouthSmileRight", "mouthPressLeft",
                                         "mouthPressRight", "mouthRollLower", "mouthRollUpper", "mouthLowerDownLeft",
                                         "mouthLowerDownRight", "mouthUpperUpLeft", "mouthUpperUpRight"]]
# A candidate whose face strays this many times the candidates' usual from their median face (a hand at
# the cheek, a mug) is left out.
ODD = 2.0
# ...and one less sharp than this share of the candidates' usual is left out when its sound has others.
BLURRED = 0.5


def class_target(blend, rest, articulation: float):
    """A SOUND CLASS'S MOUTH, PUSHED PAST THEIR OWN: its [PUSHED] shapes moved [articulation] times as far
    from [rest] (their mouth is mostly near closed while they talk, so a sound's own median reads as
    nothing on a still), the rest as they are, all within 0..1."""
    import numpy as np
    rest = np.asarray(rest, dtype=np.float64)
    out = np.asarray(blend, dtype=np.float64).copy()
    out[PUSHED] = rest[PUSHED] + (out[PUSHED] - rest[PUSHED]) * articulation
    return np.clip(out, 0.0, 1.0)


def cmd_library(a) -> int:
    """THE SET'S LIBRARY: for each sound class a few clean real mouths, and their eyes half and fully
    closed - from any video, at the still's turn, found in the surveys, then looked at again at full size
    and unwrapped into the rig's box (next/likeness.md, "The second build"). Silence and open eyes are the
    still's own."""
    import cv2
    import numpy as np
    spec = read_json(a.spec)
    rig = Rig(spec["rig"])
    still = read_json(spec["stills"])["stills"][0]
    classes = read_json(spec["visemes"])["classes"]
    art = float(spec.get("articulation", 2.0))
    variants = int(spec.get("variants", 3))
    eye_variants = int(spec.get("eye_variants", 2))
    sy, sp = float(still["yaw"]), float(still["pitch"])
    R = survey_records(spec["videos"], spec["shots"])
    if R["count"] < 50:
        say("library: too little usable footage (%d looks)" % R["count"])
        return 2
    ang = R["angles"]
    near = ((np.abs(ang[:, 0] - sy) < NEAR_TURN) & (np.abs(ang[:, 1] - sp) < NEAR_TURN)
            & ~hands_at_mouth_all(R["pose"], R["box"]))
    if near.sum() < 50:
        say("library: too few looks turned as the still is (%d)" % int(near.sum()))
        return 2
    other = (R["set"] != str(spec["set"])).astype(np.float64)
    turn = ((ang[:, 0] - sy) / DEGREES) ** 2 + ((ang[:, 1] - sp) / DEGREES) ** 2 + OTHER_SET * other
    mouth = R["blend"][:, MOUTH_INDEX].astype(np.float64)
    ks = mouth_scale(mouth[near])
    rest = np.array(classes["rest"]["blend"])
    # WHAT IS LOOKED FOR, and the survey's best guesses at each
    wants = []
    for cls, row in classes.items():
        if cls == "rest":
            continue
        T = class_target(row["blend"], rest, art)
        d = (((mouth - T) * ks) ** 2).sum(axis=1) + turn
        d[~near] = np.inf
        for i in spaced(np.argsort(d), R, 1.5, CANDIDATES):
            if np.isfinite(d[i]):
                wants.append({"kind": "mouth", "name": cls, "target": T, "i": i})
    blink = R["blend"][:, BLINK].astype(np.float64)
    for state, b in EYE_STATES.items():
        d = ((blink.mean(axis=1) - b) / 0.1) ** 2 + ((blink[:, 0] - blink[:, 1]) / 0.15) ** 2 + turn
        d[~near] = np.inf
        for i in spaced(np.argsort(d), R, 1.5, CANDIDATES):
            if np.isfinite(d[i]):
                wants.append({"kind": "eye", "name": state, "target": b, "i": i})
    progress(a.progress, 0.05)
    # EACH LOOKED AT AGAIN AT FULL SIZE: found, turned as the still, no hand at the mouth, how near what
    # was wanted, how sharp - and unwrapped into the box at once (the frame itself is let go)
    watch = Watcher(a.face_model, a.pose_model, masks=False, image=True)
    tris = rig.box_triangles()
    got = []
    for j, w in enumerate(wants):
        progress(a.progress, 0.05 + 0.85 * (j + 1) / len(wants))
        i = w["i"]
        v = spec["videos"][R["vid"][i]]
        W, H = int(v["size"][0]), int(v["size"][1])
        rgb = frame_at(a.ffmpeg, v["path"], float(R["time"][i]), W, H)
        if rgb is None:
            continue
        rec = watch.look(rgb, 0)
        if rec["found"] < 0.5 or "blend" not in rec or "matrix" not in rec:
            continue
        yaw, pitch, _roll = head_angles(rec["matrix"])
        if abs(yaw - sy) >= NEAR_TURN or abs(pitch - sp) >= NEAR_TURN or hands_at_mouth(rec.get("pose"), rec["box"]):
            continue
        bl = np.asarray(rec["blend"], dtype=np.float64)
        cost = ((yaw - sy) / DEGREES) ** 2 + ((pitch - sp) / DEGREES) ** 2 + OTHER_SET * float(other[i])
        if w["kind"] == "mouth":
            cost += float((((bl[MOUTH_INDEX] - w["target"]) * ks) ** 2).sum())
            region = LIPS_OUTER
        else:
            cost += ((bl[BLINK].mean() - w["target"]) / 0.1) ** 2 + ((bl[BLINK[0]] - bl[BLINK[1]]) / 0.15) ** 2
            region = EYE_RIGHT + EYE_LEFT
        face2d = to_pixels([rec["points"]], W, H)[0]
        got.append({"kind": w["kind"], "name": w["name"], "i": i, "cost": cost,
                    "sharp": sharpness(rgb, rec["points"], W, H, region),
                    "image": unwrap(rgb, face2d, rig, tris), "shape": rig.to_layout(face2d),
                    "blend": bl, "yaw": yaw, "pitch": pitch, "light": cheek_light(rgb, rec["points"], W, H)})
    # A FACE THAT STRAYS FROM THE OTHERS is something in front of it: a hand at the cheek, a mug - the
    # mouths' lower face and the eyes' upper, against the candidates' median there
    for kind, rows in (("mouth", slice(rig.img_h // 2, None)), ("eye", slice(0, rig.img_h // 2))):
        of = [g for g in got if g["kind"] == kind]
        if len(of) < 4:
            continue
        med_img = np.median(np.stack([g["image"][rows].astype(np.float32) for g in of]), axis=0)
        for g in of:
            g["odd"] = float(np.abs(g["image"][rows].astype(np.float32) - med_img).mean())
        usual = float(np.median([g["odd"] for g in of])) or 1.0
        got = [g for g in got if g["kind"] != kind or g["odd"] <= ODD * usual]
    # THE BEST OF EACH: nearest what was wanted, a blurred one costing more
    kept = []
    for kind in ("mouth", "eye"):
        of = [g for g in got if g["kind"] == kind]
        if not of:
            continue
        med = float(np.median([g["sharp"] for g in of])) or 1.0
        for g in of:
            g["score"] = g["cost"] + 2.0 * max(0.0, 1.0 - g["sharp"] / med)
        for name in sorted(set(g["name"] for g in of)):
            # one far blurrier than the rest (a mouth moving fast) only where there is nothing else
            mine = [g for g in of if g["name"] == name]
            sharp = [g for g in mine if g["sharp"] >= BLURRED * med]
            best = sorted(sharp if sharp else mine, key=lambda g: g["score"])
            kept += best[: variants if kind == "mouth" else eye_variants]
    if not any(g["kind"] == "mouth" for g in kept):
        say("library: no mouth found at full size")
        return 2
    out_dir = spec["out"]
    part = out_dir + ".part"
    shutil.rmtree(part, ignore_errors=True)
    os.makedirs(part)
    mouths, eyes, count = [], [], {}
    for g in kept:
        k = count.get((g["kind"], g["name"]), 0)
        count[(g["kind"], g["name"])] = k + 1
        name = "%s_%s_%d.png" % (g["kind"], g["name"], k)
        cv2.imwrite(os.path.join(part, name), cv2.cvtColor(g["image"], cv2.COLOR_RGB2BGR))
        i = g["i"]
        e = {"file": name, "vid": str(R["vid"][i]), "time": round(float(R["time"][i]), 3), "set": str(R["set"][i]),
             "yaw": round(g["yaw"], 2), "pitch": round(g["pitch"], 2), "sharp": round(g["sharp"], 1),
             "cost": round(g["cost"], 3), "light": [round(float(x), 4) for x in g["light"]],
             "shape": [[round(float(x), 2), round(float(y), 2)] for x, y in g["shape"]]}
        if g["kind"] == "mouth":
            e["class"] = g["name"]
            e["blend"] = [round(float(x), 4) for x in g["blend"][MOUTH_INDEX]]
            mouths.append(e)
        else:
            e["state"] = g["name"]
            e["blink"] = round(float(g["blend"][BLINK].mean()), 3)
            eyes.append(e)
    shutil.rmtree(out_dir, ignore_errors=True)
    os.replace(part, out_dir)
    write_json(spec["index"], {"names": MOUTH_NAMES, "image": [rig.img_w, rig.img_h], "articulation": art,
                               "mouths": mouths, "eyes": eyes})
    progress(a.progress, 1.0)
    sounds = len(set(m["class"] for m in mouths))
    say("library: %d mouths for %d sounds, %d eyes, %d from other sets" % (
        len(mouths), sounds, len(eyes), sum(1 for e in mouths + eyes if e["set"] != str(spec["set"]))))
    return 0


# --- the entry point -------------------------------------------------------------------------------

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="actor.py")
    sub = ap.add_subparsers(dest="step", required=True)

    def common(p, models=False):
        p.add_argument("--ffmpeg", required=True)
        p.add_argument("--progress", default="")
        if models:
            p.add_argument("--face-model", required=True)
            p.add_argument("--pose-model", required=True)

    p = sub.add_parser("survey")
    common(p, True)
    p.add_argument("--video", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--interval", type=float, default=0.2)
    p.set_defaults(fn=cmd_survey)

    p = sub.add_parser("shots")
    common(p)
    p.add_argument("--video", required=True)
    p.add_argument("--survey", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--min-shot", type=float, default=3.0)
    p.set_defaults(fn=cmd_shots)

    p = sub.add_parser("sets")
    common(p)
    p.add_argument("--spec", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--sheets", required=True)
    p.add_argument("--threshold", type=float, default=0.55)
    p.set_defaults(fn=cmd_sets)

    p = sub.add_parser("stills")
    common(p, True)
    p.add_argument("--spec", required=True)
    p.set_defaults(fn=cmd_stills)

    p = sub.add_parser("rig")
    p.add_argument("--progress", default="")
    p.add_argument("--stills", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--ring1", type=float, default=1.35)
    p.add_argument("--ring2", type=float, default=2.0)
    p.add_argument("--ring-moves", type=float, default=0.6)
    p.add_argument("--box-width", type=int, default=512)
    p.set_defaults(fn=cmd_rig)

    for name, fn in (("visemes", cmd_visemes), ("motion", cmd_motion)):
        p = sub.add_parser(name)
        p.add_argument("--progress", default="")
        p.add_argument("--spec", required=True)
        p.add_argument("--out", required=True)
        p.set_defaults(fn=fn)

    p = sub.add_parser("library")
    common(p, True)
    p.add_argument("--spec", required=True)
    p.set_defaults(fn=cmd_library)

    a = ap.parse_args(argv)
    return int(a.fn(a) or 0)


if __name__ == "__main__":
    sys.exit(main())
