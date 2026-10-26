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
                drawn on, and a few to pick from - each with its room, its matte, what stands before
                them, and all of them on one numbered sheet for the writer that finds them at rest
    rig         the mesh on the set's still: its face, the rings round it, the frame's edge, one
                triangulation, and the face's box with a mask for the lips and one for the eyes; and
                each still's skeleton, every vertex of its body weighed to its bones
    visemes     their mouth for each sound class, from caption-timed phones (or their own range),
                over every video
    motion      their head's own motion where they face the camera, over every video: its quick part
                in runs, which looks are speech, how often they blink; and their posture - how far and
                which ways their body settles, and how long it holds
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
            # A COPY: the view is MediaPipe's own buffer, and the next frame writes over it (2026-10-22:
            # every still kept the last frame's matte)
            rec["segmentation"] = np.array(pr.segmentation_masks[0].numpy_view(), copy=True)
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
# THE STILLS ON ONE SHEET, numbered from 1 (the fourth pass): what the rest step's writer is shown - the
# hands at rest are a matter of what they look like, which the body's points cannot see (2026-10-22, his
# footage: open palms, folded hands and a phone held all came out alike by every measure of the points).
SHEET = "sheet.jpg"
SHEET_TILE_W = 480


def still_sheet(tiles, path: str, cols=4) -> None:
    """The stills [tiles] (BGR, full size) on one sheet at [SHEET_TILE_W] each, numbered from 1 large in a
    corner."""
    import cv2
    import numpy as np
    if not tiles:
        return
    h0, w0 = tiles[0].shape[:2]
    tw, th = SHEET_TILE_W, int(round(SHEET_TILE_W * h0 / w0))
    rows = (len(tiles) + cols - 1) // cols
    sheet = np.zeros((rows * th, cols * tw, 3), dtype=np.uint8)
    for k, t in enumerate(tiles):
        tile = cv2.resize(t, (tw, th), interpolation=cv2.INTER_AREA)
        for color, width in (((0, 0, 0), 7), ((255, 255, 255), 2)):
            cv2.putText(tile, str(k + 1), (10, 44), cv2.FONT_HERSHEY_SIMPLEX, 1.4, color, width, cv2.LINE_AA)
        r, c = divmod(k, cols)
        sheet[r * th:(r + 1) * th, c * tw:(c + 1) * tw] = tile
    cv2.imwrite(path, sheet, [cv2.IMWRITE_JPEG_QUALITY, 88])


# THEIR HANDS, CLOSER (2026-10-25, the user on the still At rest put first: "His resting pose is open palm, face-up -
# which is bizarre, because it makes him look like a priest"): on the sheet a hand is some 40 pixels, and the writer
# put two stills with open palms among its five at rest. So each still's hands are cropped for it too, numbered alike:
# the box round the landmarks of the hands seen (MediaPipe's pose, wrists to thumbs: HAND_POINTS), HANDS_GROW times as
# large and at least HANDS_LEAST shoulder widths across, at the frame's shape; no hand seen, the body below the shoulders.
HANDS = "hands.jpg"
HAND_POINTS = list(range(15, 23))
HANDS_GROW = 1.6
HANDS_LEAST = 1.2


def hands_box(pose, w: int, h: int):
    """Where the hands are in a still of [w] x [h] with [pose] (33 landmarks of x, y, z and how surely seen, flat):
    (x0, y0, x1, y1) in pixels, at the frame's shape, inside it."""
    import numpy as np
    p = np.asarray(pose, np.float64).reshape(33, 4)
    xy = p[:, :2] * np.array([w, h])
    sw = max(float(np.hypot(*(xy[11] - xy[12]))), 1.0)
    seen = [j for j in HAND_POINTS if p[j, 3] > 0.5]
    if seen:
        lo, hi = xy[seen].min(axis=0), xy[seen].max(axis=0)
        (cx, cy), span = (lo + hi) / 2.0, (hi - lo) * HANDS_GROW
    else:
        cx, cy = (xy[11] + xy[12]) / 2.0 + np.array([0.0, 1.2 * sw])
        span = np.array([2.0 * sw, 1.2 * sw])
    bw = max(float(span[0]), float(span[1]) * w / h, HANDS_LEAST * sw)
    bw = min(bw, float(w))
    bh = bw * h / w
    x0 = int(round(min(max(cx - bw / 2.0, 0.0), w - bw)))
    y0 = int(round(min(max(cy - bh / 2.0, 0.0), h - bh)))
    return x0, y0, x0 + int(round(bw)), y0 + int(round(bh))


def hands_sheet(tiles, poses, path: str) -> None:
    """Each of the stills [tiles] (BGR, full size) cropped to its hands ([hands_box], by its pose in [poses]), on a
    sheet as [still_sheet] lays them, numbered alike."""
    if not tiles:
        return
    h, w = tiles[0].shape[:2]
    crops = []
    for t, pose in zip(tiles, poses):
        x0, y0, x1, y1 = hands_box(pose, t.shape[1], t.shape[0])
        crops.append(t[y0:y1, x0:x1] if x1 > x0 and y1 > y0 else t)
    still_sheet(crops, path)


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


# THE ROOM'S PLATE: made from this many frames of the set, at least this many seconds apart.
PLATE_FRAMES = 150
PLATE_GAP = 4.0
# A frame's pixel this likely to be them (the segmentation's) is not the room - nor any within this many
# pixels of one, where their edge's color bleeds.
PERSON = 0.3
CLEAR = 12
# A PIXEL OF THEIR MATTE THAT NEVER MOVES is not them (2026-10-22: the segmentation took the microphone in
# front of them for them, and it would have moved with them): in this share of the set's frames it is still
# the still's - its color within STEADY levels, the frame and the still both in the first still's light,
# and where the still has texture (more than PLAIN over ALIKE_PATCH pixels) its patch alike too (normalized
# correlation past ALIKE) - all at half size. Each still is judged against its own pixels. (The fourth
# pass, measured on his footage: by texture alone the microphone's plain dark body never matched and stayed
# in a still's matte; by color alone, without each still's own light, it never matched either - the light
# moves 15 levels over the hour - and with it, half his dark sweater did, its knit gone at half size; by
# color, and texture where there is some, the microphone alone, and a few flecks.)
STILL_SHARE = 0.6
ALIKE = 0.8
ALIKE_PATCH = 11
STEADY = 14
PLAIN = 20.0
# WHAT STANDS BEFORE THEM, not behind (the fourth pass: their bones bend their matte, and a microphone left
# in it bent with them): a pixel that never moves which is still the still's in the frames where they are
# there (at least FRONT_SEEN of the frames), in a piece of FRONT_LEAST pixels or more - it hides them. It
# is drawn over them and never moves (`front_K.png`), and their own picture under it is filled from round
# it (`body_K.jpg`), so that moving behind it they show no second microphone. A pixel within EDGE pixels of
# their matte's edge that never moves and is not before them is the wall their matte bled over: taken out.
FRONT_SEEN = 0.15
FRONT_LEAST = 3000
EDGE = 15
# How far from their matte a thing before them may reach, and how far past what passed it is grown (pixels).
NEAR = 60
FRONT_GROW = 6
# A THING BEFORE THEM HAS AN OUTLINE OF ITS OWN (2026-10-25, the user: the actor is "especially messy at the neck and
# around the beard"): a plain region passes as never moving whatever it is - a black t-shirt on a dark wall, a dark
# sweater's knit at half size - and pieces of their own clothes were drawn before them, frozen over the body as it moved
# and cutting the beard as the head turned. So a piece is kept only where at least OUTLINE_SHARE of the band round its
# edge (from 4 pixels outside it to 12 in) is a strong edge in the still - past OUTLINE_EDGE (a 3x3 Sobel of its grey,
# 0..255). On his four sets: a microphone's and a shock mount's 0.10 to 0.45, the t-shirt's and the sweater's pieces
# 0.00 to 0.06. (A microphone joined to a black shirt in one piece goes with it, and moves a little with them.)
OUTLINE_EDGE = 60.0
OUTLINE_SHARE = 0.08
# THE PLATE IS TRUSTED where a quarter of the frames saw the room - a median that outvotes the frames that
# were their own shape the segmentation missed, or the globe they held up a while - or where at least
# TRUSTED_FRAMES saw it and AGREE: AGREEING of them within AGREE levels of their median. Elsewhere it is
# filled from round it. (The fourth pass: by the quarter alone, the wall behind a still's head where they
# seldom sit - seen in 4 to 14% of the frames - was all filled, a smear where the picture's frame was; by
# six frames alone, a patch of their own face came in at their hairline, and the globe behind an arm.)
TRUSTED = 0.25
TRUSTED_FRAMES = 6
AGREE = 12
AGREEING = 0.75
# How far round them the still's room sets the plate's light, and how far in it spreads (pixels).
SHADE = 30
# Away from the head, the plate is used behind them only where their matte is past this.
SOFT = 0.6
# The head's reach, in the face's own radii from its middle.
HEAD_REACH = 2.3
# How far into their silhouette the plate is filled where the frames never showed the room (pixels):
# what any motion of theirs can uncover.
UNCOVER = 70


def soft_matte(seg, h: int, w: int):
    """The segmentation's person as an alpha, 0..1: its doubt cut, its soft edge kept."""
    import cv2
    import numpy as np
    m = np.asarray(seg, dtype=np.float32).reshape(h, w)
    m = np.clip((m - 0.25) / 0.5, 0.0, 1.0)
    return cv2.GaussianBlur(m, (0, 0), 1.2)


def light_fit(src, dst, where, most=20000, seed=0):
    """EACH CHANNEL'S GAIN AND OFFSET taking [src]'s pixels to [dst]'s where both show [where]: least
    squares over a sample of them, the gain kept within 0.7..1.4."""
    import numpy as np
    ys, xs = np.nonzero(where)
    if ys.size < 500:
        return np.ones(3), np.zeros(3)
    pick = np.random.default_rng(seed).choice(ys.size, size=min(most, ys.size), replace=False)
    s_ = src[ys[pick], xs[pick]].astype(np.float64)
    d_ = dst[ys[pick], xs[pick]].astype(np.float64)
    gain, off = np.ones(3), np.zeros(3)
    for c in range(3):
        g = np.linalg.lstsq(np.stack([s_[:, c], np.ones(s_.shape[0])], axis=1), d_[:, c], rcond=None)[0][0]
        gain[c] = float(np.clip(g, 0.7, 1.4))
        off[c] = float(np.mean(d_[:, c] - gain[c] * s_[:, c]))
    return gain, off


def room_plate(a, spec, R, stills_rgb, stills_person, watch, report):
    """THE ROOM OF THE SET, WITHOUT THEM, from its frames - each frame's light matched to the first still's
    on the room both show: per pixel, the MEDIAN of the frames where it is the room (a mean took in the
    globe they held up a while, and ghosts of them where the segmentation missed them: 2026-10-22) and the
    share of frames that saw it. And for each of [stills_rgb] (their people [stills_person]), WHAT NEVER
    MOVES - at half size, the still in the first one's light too: the share of frames still the still's
    there (its color within [STEADY], and where the still has texture its patch alike too: [patch_alike]),
    and that share among the frames they are there in (what hides them); and the share of frames they are
    there. `plate, trusted, [{still, front}], there, n` - trusted where the plate is ([TRUSTED])."""
    import cv2
    import warnings
    import numpy as np
    still_rgb = stills_rgb[0]
    H, W = still_rgb.shape[:2]
    half = (W // 2, H // 2)
    frames, rooms = [], []
    ker = np.ones((2 * CLEAR + 1, 2 * CLEAR + 1), np.uint8)
    # EACH STILL AS THE FRAMES WILL BE: in the first still's light, at half size, with where it is plain
    small_stills, small_grays, plains = [], [], []
    for st, person in zip(stills_rgb, stills_person):
        if st.shape != still_rgb.shape:
            small_stills.append(None)
            small_grays.append(None)
            plains.append(None)
            continue
        out = ~cv2.dilate((person | stills_person[0]).astype(np.uint8), ker).astype(bool)
        gain, off = light_fit(st, still_rgb, out)
        lit = np.clip(st.astype(np.float64) * gain + off, 0, 255).astype(np.uint8)
        small = cv2.resize(lit, half, interpolation=cv2.INTER_AREA)
        gray = cv2.cvtColor(small, cv2.COLOR_RGB2GRAY).astype(np.float32)
        small_stills.append(small.astype(np.int16))
        small_grays.append(gray)
        plains.append(texture(gray) <= PLAIN)
    still_n = [np.zeros((H // 2, W // 2), np.float64) for _ in stills_rgb]
    front_n = [np.zeros((H // 2, W // 2), np.float64) for _ in stills_rgb]
    there_n = np.zeros((H // 2, W // 2), np.float64)
    # ACROSS ALL OF THE SET (2026-10-22: the first PLATE_FRAMES of six times as many, taken in order, were
    # its first sixth - the light of the session's first quarter hour, and the microphone of a still made
    # later never matched them)
    order = np.linspace(0, R["count"] - 1, num=min(R["count"], PLATE_FRAMES)).astype(int)
    picks = spaced(order, R, PLATE_GAP, PLATE_FRAMES)
    for j, i in enumerate(picks):
        report(0.8 * j / max(1, len(picks)))
        v = spec["videos"][R["vid"][i]]
        if [int(v["size"][0]), int(v["size"][1])] != [W, H]:
            continue
        rgb = frame_at(a.ffmpeg, v["path"], float(R["time"][i]), W, H)
        if rgb is None:
            continue
        seg = watch.look(rgb, 0).get("segmentation")
        if seg is None:
            continue
        them = np.asarray(seg).reshape(H, W) > PERSON
        room = cv2.dilate(them.astype(np.uint8), ker) == 0
        gain, off = light_fit(rgb, still_rgb, room & ~stills_person[0], seed=j)
        adj = np.clip(rgb.astype(np.float64) * gain + off, 0, 255).astype(np.uint8)
        frames.append(adj)
        rooms.append(room)
        small = cv2.resize(adj, half, interpolation=cv2.INTER_AREA)
        gray = cv2.cvtColor(small, cv2.COLOR_RGB2GRAY).astype(np.float32)
        there = cv2.resize(them.astype(np.uint8), half, interpolation=cv2.INTER_NEAREST) > 0
        there_n += there
        small = small.astype(np.int16)
        for k, st in enumerate(small_stills):
            if st is None:
                continue
            like = (np.abs(small - st).max(axis=2) < STEADY) & (plains[k] | (patch_alike(gray, small_grays[k]) > 0))
            still_n[k] += like
            front_n[k] += like & there
    n = len(frames)
    plate = np.zeros((H, W, 3), np.float64)
    seen = np.zeros((H, W), np.float64)
    agree = np.zeros((H, W), np.float64)
    if n:
        # the median, a band of rows at a time (all of it at once is gigabytes)
        for r0 in range(0, H, 60):
            block = np.stack([f[r0:r0 + 60] for f in frames]).astype(np.float32)
            where = np.stack([m[r0:r0 + 60] for m in rooms])
            seen[r0:r0 + 60] = where.sum(axis=0)
            block[~where] = np.nan
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")          # a pixel no frame saw: an all-empty median
                plate[r0:r0 + 60] = np.nan_to_num(np.nanmedian(block, axis=0))
                near = np.abs(block - plate[r0:r0 + 60].astype(np.float32)).max(axis=3) < AGREE
            agree[r0:r0 + 60] = (near & where).sum(axis=0) / np.maximum(where.sum(axis=0), 1)
            report(0.8 + 0.2 * r0 / H)

    def full(m):
        # (smoothed a little first: a thing before them is a piece, not a scatter of pixels that passed)
        return cv2.resize(cv2.GaussianBlur(m.astype(np.float32), (0, 0), 2.0), (W, H), interpolation=cv2.INTER_LINEAR)

    judged = [{"still": full(still_n[k] / max(1, n)), "front": full(front_n[k] / np.maximum(there_n, 1))}
              for k in range(len(stills_rgb))]
    return plate, trust(seen / max(1, n), agree, n), judged, cv2.resize((there_n / max(1, n)).astype(np.float32), (W, H)), n


def trust(seen, agree, n: int):
    """WHERE THE PLATE IS TRUSTED: seen in [TRUSTED] of the [n] frames, or by [TRUSTED_FRAMES] of them that
    agree ([agree], the share of them near their median)."""
    return (seen >= TRUSTED) | ((seen * n >= TRUSTED_FRAMES - 1e-9) & (agree >= AGREEING))


def texture(gray):
    """How much texture [gray] has round each pixel: its variance over [ALIKE_PATCH] pixels."""
    import cv2
    k = (ALIKE_PATCH, ALIKE_PATCH)
    m = cv2.blur(gray, k)
    return cv2.blur(gray * gray, k) - m * m


def patch_alike(gray, still_gray):
    """Where [gray]'s texture is the still's: the normalized correlation of the patches round each pixel
    past [ALIKE], where the still has texture to correlate - more than [PLAIN] (1 there, else 0)."""
    import cv2
    import numpy as np
    k = (ALIKE_PATCH, ALIKE_PATCH)
    ma, mb = cv2.blur(gray, k), cv2.blur(still_gray, k)
    va = cv2.blur(gray * gray, k) - ma * ma
    vb = cv2.blur(still_gray * still_gray, k) - mb * mb
    cov = cv2.blur(gray * still_gray, k) - ma * mb
    ncc = cov / np.sqrt(np.maximum(va * vb, 1e-6))
    return ((ncc > ALIKE) & (vb > PLAIN)).astype(np.float64)


def outlined(before, still_rgb):
    """The pieces of [before] (uint8, 1 where something stands before them) with AN OUTLINE OF THEIR OWN in the still: at
    least [OUTLINE_SHARE] of the band round each piece's edge a strong edge ([OUTLINE_EDGE]). The rest are a plain
    region of them, still only for being plain."""
    import cv2
    import numpy as np
    gray = cv2.cvtColor(still_rgb, cv2.COLOR_RGB2GRAY).astype(np.float32)
    strong = np.hypot(cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3), cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)) > OUTLINE_EDGE
    count, parts = cv2.connectedComponents(before, connectivity=8)
    out = np.zeros_like(before)
    for c in range(1, count):
        piece = (parts == c).astype(np.uint8)
        band = (cv2.dilate(piece, np.ones((9, 9), np.uint8)) > 0) & (cv2.erode(piece, np.ones((25, 25), np.uint8)) == 0)
        if strong[band].mean() >= OUTLINE_SHARE:
            out[parts == c] = 1
    return out


def still_room(still_rgb, matte, plate, trusted, judged, there, head=None):
    """ONE STILL'S LAYERS: its matte with what never moves taken out - the room, where it is not before them -
    and what stands BEFORE them (`front`, 0..1: drawn over them, never moving), their picture with the
    front filled from round it (`body`), and the room - the still's own where it is not them, the plate's
    (in the still's light) where it is and the plate is [trusted], filled in from round it where their
    motion could uncover it and it is not. Round the [head] (a mask) the plate reaches [CLEAR] past their
    edge, so no hair is left on the wall; elsewhere only where the still is mostly them ([SOFT]), so their
    soft edge is the still's own room (the fourth pass: in a gap between their arm and the chair, a soft
    edge over the plate's wall showed a light sliver where the still showed the chair). `matte, room,
    front, body`."""
    import cv2
    import numpy as np
    H, W = still_rgb.shape[:2]
    rgb = still_rgb.astype(np.float64)
    opened = np.ones((5, 5), np.uint8)
    still = judged["still"] > STILL_SHARE
    them = (matte > 0.5).astype(np.uint8)
    # (near them: a microphone the segmentation left out of them is a hole as wide as it is)
    near = cv2.dilate(them, np.ones((2 * NEAR + 1, 2 * NEAR + 1), np.uint8)) > 0
    before = cv2.morphologyEx(((still & (judged["front"] > STILL_SHARE) & (there >= FRONT_SEEN) & near)
                               .astype(np.uint8)), cv2.MORPH_OPEN, opened)
    before = cv2.morphologyEx(before, cv2.MORPH_CLOSE, opened)
    count, parts, stats, _ = cv2.connectedComponentsWithStats(before, connectivity=8)
    for c in range(1, count):
        if stats[c, cv2.CC_STAT_AREA] < FRONT_LEAST:
            before[parts == c] = 0
    # (grown past what passed: its lit rim, an edge at half size, was left in them and moved with them)
    before = cv2.dilate(before, np.ones((2 * FRONT_GROW + 1, 2 * FRONT_GROW + 1), np.uint8)) & near.astype(np.uint8)
    before = outlined(before, still_rgb)
    # (their edge where the front is not: a hole the segmentation left for the microphone is no edge of them)
    whole = them | cv2.dilate(before, np.ones((2 * EDGE + 1, 2 * EDGE + 1), np.uint8))
    edge = cv2.erode(whole, np.ones((2 * EDGE + 1, 2 * EDGE + 1), np.uint8)) == 0
    behind = cv2.morphologyEx((still & (before == 0) & edge).astype(np.uint8), cv2.MORPH_OPEN, opened)
    matte = matte * (1.0 - cv2.GaussianBlur(behind.astype(np.float32), (0, 0), 1.5))
    front = None
    if np.any(before):
        front = cv2.GaussianBlur(before.astype(np.float32), (0, 0), 1.0) * (before > 0)
        # THEY ARE BEHIND IT: their matte whole there, whatever the segmentation made of it - else a hole
        # in them the front's shape would move with them
        matte = np.maximum(matte, cv2.GaussianBlur(cv2.dilate(before, opened).astype(np.float32), (0, 0), 1.5))
    body = still_rgb
    if front is not None:
        # their picture under it, filled from round it (at half size: a fill is smooth)
        hole = cv2.dilate(before, np.ones((7, 7), np.uint8))
        small = cv2.resize(still_rgb, (W // 2, H // 2), interpolation=cv2.INTER_AREA)
        small_hole = cv2.resize(hole * 255, (W // 2, H // 2), interpolation=cv2.INTER_NEAREST)
        filled = cv2.resize(cv2.inpaint(small, small_hole, 5, cv2.INPAINT_TELEA), (W, H), interpolation=cv2.INTER_LINEAR)
        body = still_rgb.copy()
        body[hole > 0] = filled[hole > 0]
    ker = np.ones((2 * CLEAR + 1, 2 * CLEAR + 1), np.uint8)
    person = cv2.dilate((matte > 0.05).astype(np.uint8), ker) > 0
    if head is not None:
        mostly = cv2.dilate((matte > SOFT).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
        person = np.where(head, person, mostly)
    gain, off = light_fit(plate, still_rgb, trusted & ~person)
    lit = np.clip(plate * gain + off, 0, 255)
    # THE LIGHT ROUND THEM (the fourth pass: a light halo round their head): their shadow on the wall is in
    # the still and not in the plate - made where they are not - so the plate is darkened, or lightened, as
    # the still's room just outside them is against it, spread inward from there
    band = ((cv2.dilate(person.astype(np.uint8), np.ones((2 * SHADE + 1, 2 * SHADE + 1), np.uint8)) > 0) & ~person
            & trusted).astype(np.float32)
    if band.sum() > 100:
        ratio = np.clip((rgb + 8.0) / (lit + 8.0), 0.6, 1.4).astype(np.float32)
        weight = cv2.GaussianBlur(band, (0, 0), SHADE)
        shade = np.ones_like(ratio)
        for c in range(3):
            spread = cv2.GaussianBlur(ratio[:, :, c] * band, (0, 0), SHADE)
            shade[:, :, c] = np.where(weight > 1e-3, spread / np.maximum(weight, 1e-3), 1.0)
        lit = np.clip(lit * shade, 0, 255)
    room = rgb.copy()
    known = person & trusted
    room[known] = lit[known]
    # THE HOLE their motion could uncover: inside them, near their edge, the room not seen there enough
    inside = cv2.distanceTransform(person.astype(np.uint8), cv2.DIST_L2, 5)
    hole = person & ~trusted & (inside < UNCOVER)
    out = np.clip(room, 0, 255).astype(np.uint8)
    if np.any(hole):
        # filled from the room round it - never from them (all of them unknown to the fill, though only
        # the band is kept: from their own pixels, the sweater smeared into the wall) - at half size (a
        # fill is smooth: half size loses nothing it has)
        unknown = person & ~trusted
        small = cv2.resize(out, (W // 2, H // 2), interpolation=cv2.INTER_AREA)
        small_hole = cv2.resize(unknown.astype(np.uint8) * 255, (W // 2, H // 2), interpolation=cv2.INTER_NEAREST)
        filled = cv2.resize(cv2.inpaint(small, small_hole, 5, cv2.INPAINT_TELEA), (W, H), interpolation=cv2.INTER_LINEAR)
        out[hole] = filled[hole]
    return matte, out, front, body


def cmd_stills(a) -> int:
    """A SET'S STILLS: its most typical calm moments facing the camera, each a candidate for the one frame
    a Likeness is drawn on (next/likeness.md, "The second build"). Found in the survey, then looked at
    again at full size - the face found, the eyes open, the mouth closed, sharp. Each with ITS MATTE (them,
    not the room or what stands before them) and ITS ROOM (the room behind them, from the set's frames:
    the third pass), so they are drawn over the room and the room never moves. And all of them on one
    numbered sheet ([SHEET]), for the writer that says which show them at rest (the fourth pass)."""
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
    watch = Watcher(a.face_model, a.pose_model, masks=True, image=True)
    found = []
    for j, i in enumerate(picks):
        v = spec["videos"][R["vid"][i]]
        W, H = int(v["size"][0]), int(v["size"][1])
        rgb = frame_at(a.ffmpeg, v["path"], float(R["time"][i]), W, H)
        progress(a.progress, 0.05 + 0.45 * (j + 1) / len(picks))
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
    chosen = [f for f in found if f["rec"].get("segmentation") is not None and "pose" in f["rec"]][:count]
    if not chosen:
        say("stills: no still had their body found")
        return 2
    for f in found:
        if not any(f is c for c in chosen):
            f.pop("rgb", None)
            f["rec"].pop("segmentation", None)
    # THE ROOM, made once for the set from the first still's light; what never moves, for each still
    first = chosen[0]
    W0, H0 = first["size"]
    people = [soft_matte(f["rec"]["segmentation"], f["size"][1], f["size"][0]) > 0.05 for f in chosen]
    plate, trusted, judged, there, frames_n = room_plate(a, spec, R, [f["rgb"] for f in chosen], people, watch,
                                                      lambda f: progress(a.progress, 0.5 + 0.4 * f))
    out_dir = spec["out"]
    part = out_dir + ".part"
    shutil.rmtree(part, ignore_errors=True)
    os.makedirs(part)
    stills = []
    sheet_tiles, sheet_poses = [], []
    for k, f in enumerate(chosen):
        W, H = f["size"]
        rec = f["rec"]
        bgr = cv2.cvtColor(f["rgb"], cv2.COLOR_RGB2BGR)
        name, thumb = "still_%d.jpg" % k, "still_%d_thumb.jpg" % k
        cv2.imwrite(os.path.join(part, name), bgr, [cv2.IMWRITE_JPEG_QUALITY, 95])
        matte = soft_matte(rec["segmentation"], H, W)
        room, front, body = f["rgb"], None, f["rgb"]
        if [W, H] == [W0, H0]:
            face = np.asarray(rec["points"], dtype=np.float64)[:FACE_POINTS, :2] * np.array([W, H])
            hc = face[OVAL].mean(axis=0)
            hr = float(np.hypot(*(face[OVAL] - hc).T).mean())
            yy, xx = np.mgrid[0:H, 0:W]
            head = np.hypot(xx - hc[0], yy - hc[1]) < HEAD_REACH * hr
            matte, room, front, body = still_room(f["rgb"], matte, plate, trusted, judged[k], there, head)
        cv2.imwrite(os.path.join(part, "room_%d.jpg" % k), cv2.cvtColor(room, cv2.COLOR_RGB2BGR), [cv2.IMWRITE_JPEG_QUALITY, 93])
        cv2.imwrite(os.path.join(part, "matte_%d.png" % k), np.clip(matte * 255 + 0.5, 0, 255).astype(np.uint8))
        layers = {}
        if front is not None:
            bgra = np.dstack([bgr, np.clip(front * 255 + 0.5, 0, 255).astype(np.uint8)])
            cv2.imwrite(os.path.join(part, "front_%d.png" % k), bgra)
            cv2.imwrite(os.path.join(part, "body_%d.jpg" % k), cv2.cvtColor(body, cv2.COLOR_RGB2BGR), [cv2.IMWRITE_JPEG_QUALITY, 95])
            layers = {"front": "front_%d.png" % k, "body": "body_%d.jpg" % k}
        small = cv2.resize(bgr, (STILL_THUMB_W, int(round(STILL_THUMB_W * H / W))), interpolation=cv2.INTER_AREA)
        cv2.imwrite(os.path.join(part, thumb), small, [cv2.IMWRITE_JPEG_QUALITY, 88])
        sheet_tiles.append(bgr)
        sheet_poses.append(rec["pose"])
        i = f["i"]
        stills.append({"file": name, "thumb": thumb, "vid": str(R["vid"][i]), "time": round(float(R["time"][i]), 3),
                       "set": str(R["set"][i]), "size": [W, H],
                       "points": [[round(float(c), 5) for c in p] for p in rec["points"]],
                       "matrix": [round(float(x), 6) for x in rec["matrix"]],
                       "blend": [round(float(x), 4) for x in rec["blend"]],
                       "light": [round(float(x), 4) for x in cheek_light(f["rgb"], rec["points"], W, H)],
                       "yaw": round(f["angles"][0], 2), "pitch": round(f["angles"][1], 2), "roll": round(f["angles"][2], 2),
                       "pose": [round(float(x), 5) for x in rec["pose"]],
                       "room": "room_%d.jpg" % k, "matte": "matte_%d.png" % k, **layers,
                       "sharp": round(f["sharp"], 1), "score": round(f["score"], 3)})
    still_sheet(sheet_tiles, os.path.join(part, SHEET))
    hands_sheet(sheet_tiles, sheet_poses, os.path.join(part, HANDS))
    shutil.rmtree(out_dir, ignore_errors=True)
    os.replace(part, out_dir)
    write_json(spec["index"], {"stills": stills})
    progress(a.progress, 1.0)
    say("stills: %d, the best of %d looked at in %d looks; the room from %d frames" % (len(stills), len(found), n, frames_n))
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


def smooth(e0: float, e1: float, x: float) -> float:
    """0 at [e0] and 1 at [e1] (either way round), eased between."""
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0))) if e1 != e0 else 1.0
    return t * t * (3.0 - 2.0 * t)


# THE BODY'S BONES (the fourth pass, 2026-10-22, the user on the third: "the actor's body is completely
# rigid, and it is just rocking around constantly ... we're not modeling the body - we're just shifting it
# around a bunch"): a skeleton on each still from its pose, and every vertex of its mesh weighed to its
# bones. What a vertex's weights leave is the room's: it stays where it is.
BONES = ["torso", "head", "shoulder_l", "shoulder_r", "upper_l", "fore_l", "hand_l", "upper_r", "fore_r", "hand_r"]
# A SEATED TORSO from the shoulders to the hips, in shoulder widths, where the hips are not seen (behind the
# desk): they are the point it leans and breathes about.
TORSO = 1.35
# How thick each part of an arm is round its bone (its radius, in shoulder widths), and how far out from
# the shoulder's joint the shoulder's own share reaches.
ARM_R = {"upper": 0.18, "fore": 0.15, "hand": 0.14}
SHOULDER_R = 0.42
# How far past the hand's knuckles (the pose's index and pinky) its fingers reach, as a share of the hand.
FINGERS = 0.5
# A HAND RESTS where it is when a point of it (its wrist or knuckles) is seen this surely in the picture -
# hands folded at the desk's edge are seen less surely than an elbow (0.4 to 0.9 on his stills), and their
# wrist can be under the frame with the knuckles in it - or when, not seen, it is within TOGETHER shoulder
# widths of a hand that rests: hands clasped rest together (one moved, the other held, they tore apart).
WRIST_SEEN = 0.3
TOGETHER = 0.6


def skeleton(pose, w: int, h: int):
    """THE STILL'S SKELETON from its pose, in pixels: the shoulders (`l` is theirs, on the picture's
    right), the neck between them, the hips (where they are seen, else [TORSO] shoulder widths under the
    neck), and each arm's shoulder, elbow, wrist and the hand's end - with whether the hand RESTS in the
    picture, where it stays as the body moves ([WRIST_SEEN], [TOGETHER]; a hand unseen, or out of the
    picture, goes with the body). None when the shoulders are not seen."""
    import numpy as np
    p = np.asarray(pose, dtype=np.float64).reshape(33, 4)
    xy = p[:, :2] * np.array([w, h])
    seen = p[:, 3] > 0.5
    if not (seen[11] and seen[12]):
        return None
    neck = (xy[11] + xy[12]) * 0.5
    sw = float(np.hypot(*(xy[11] - xy[12])))
    hip = neck + np.array([0.0, TORSO * sw])
    if seen[23] and seen[24]:
        seen_hip = (xy[23] + xy[24]) * 0.5
        if seen_hip[1] > neck[1] + 0.8 * sw:
            hip = seen_hip
    out = {"neck": neck, "hip": hip, "width": sw}
    for side, (s, e, wr, pk, ix) in {"l": (11, 13, 15, 17, 19), "r": (12, 14, 16, 18, 20)}.items():
        knuckles = (xy[pk] + xy[ix]) * 0.5
        tip = xy[wr] + (knuckles - xy[wr]) * (1.0 + FINGERS)
        rests = any(p[k, 3] > WRIST_SEEN and 0.0 <= xy[k][0] <= w and 0.0 <= xy[k][1] <= h for k in (wr, pk, ix))
        out[side] = {"shoulder": xy[s], "elbow": xy[e], "wrist": xy[wr], "tip": tip, "rests": rests}
    for side, other in (("l", "r"), ("r", "l")):
        if not out[side]["rests"] and out[other]["rests"] \
                and float(np.hypot(*(out[side]["wrist"] - out[other]["wrist"]))) < TOGETHER * sw:
            out[side]["rests"] = True
    return out


def _segment_distance(q, a, b) -> float:
    import numpy as np
    ab = b - a
    t = float(np.clip(np.dot(q - a, ab) / max(float(np.dot(ab, ab)), 1e-9), 0.0, 1.0))
    return float(np.hypot(*(q - (a + t * ab))))


def arm_bones(skel, side: str):
    """Arm [side]'s bones: `[(name, a, b, radius)]` - the upper arm, the forearm and the hand."""
    a = skel[side]
    sw = skel["width"]
    return [("upper_" + side, a["shoulder"], a["elbow"], ARM_R["upper"] * sw),
            ("fore_" + side, a["elbow"], a["wrist"], ARM_R["fore"] * sw),
            ("hand_" + side, a["wrist"], a["tip"], ARM_R["hand"] * sw)]


def body_points(face2d, pose, matte, w: int, h: int, ring1: float, near):
    """THE BODY'S VERTICES on a still: its silhouette every so often, a band 55 px out (their soft edge
    moves with them, never stretched), a grid inside, the shoulders, elbows and wrists, the neck - and each
    ARM along its bones and its two sides, so an arm bends apart from what is behind it (the fourth pass) -
    none within the head's near ring, none crowding another or [near]."""
    import cv2
    import numpy as np
    oval = face2d[OVAL]
    hc = oval.mean(axis=0)
    hr = float(np.hypot(*(oval - hc).T).mean())
    m8 = (matte > 0.5).astype(np.uint8)

    def along(mask, step):
        cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
        got = []
        for c in cnts:
            if cv2.contourArea(c) < 400:
                continue
            c = c[:, 0, :].astype(np.float64)
            d = np.r_[0.0, np.cumsum(np.hypot(*np.diff(c, axis=0).T))]
            for t in np.arange(0.0, d[-1], step):
                got.append(c[min(len(c) - 1, int(np.searchsorted(d, t)))])
        return got

    cand = along(m8, 45.0) + along(cv2.dilate(m8, np.ones((111, 111), np.uint8)), 70.0)
    inner = cv2.erode(m8, np.ones((41, 41), np.uint8))
    for y in range(40, h, 80):
        for x in range(40, w, 80):
            if inner[y, x]:
                cand.append(np.array([x, y], dtype=np.float64))
    p = np.asarray(pose, dtype=np.float64).reshape(33, 4)
    skel = skeleton(pose, w, h)
    # THE ARMS FIRST: along each bone and its two sides, so the grid gives way to them
    arms = []
    if skel is not None:
        for side in ("l", "r"):
            for _, a, b, r in arm_bones(skel, side):
                ab = b - a
                length = float(np.hypot(*ab))
                if length < 1.0:
                    continue
                across = np.array([-ab[1], ab[0]]) / length
                for u in np.arange(0.0, 1.0 + 1e-6, min(1.0, 40.0 / length)):
                    c = a + ab * u
                    arms += [c, c + across * r, c - across * r]
    cand = arms + cand
    for k in (11, 12, 13, 14, 15, 16):
        if p[k, 3] > 0.5:
            cand.insert(0, p[k, :2] * np.array([w, h]))
    if p[11, 3] > 0.5 and p[12, 3] > 0.5:
        shoulders = (p[11, :2] + p[12, :2]) * 0.5 * np.array([w, h])
        for u in (0.35, 0.7):
            cand.append(face2d[CHIN] + (shoulders - face2d[CHIN]) * u)
    out = [np.asarray(q, dtype=np.float64) for q in near]
    first = len(out)
    for q in cand:
        q = np.asarray(q, dtype=np.float64)
        if not (0.0 <= q[0] <= w and 0.0 <= q[1] <= h):
            continue
        if np.hypot(*(q - hc)) < hr * ring1 * 1.12:
            continue
        if any(np.hypot(*(q - o)) < 28.0 for o in out):
            continue
        out.append(q)
    return np.array(out[first:]).reshape(-1, 2)


def skin_weights(pts, face2d, pose, matte, w: int, h: int):
    """EACH VERTEX'S WEIGHT ON EACH OF [BONES] (`[n, len(BONES)]`; what they leave is the room's, which
    stays). THE HEAD: all of it near the head above the neck's foot, none at the shoulders - the neck bends
    between. THE BODY'S share - all of it on them and near them, none out in the room - goes to an ARM
    where the vertex is on one (by how near each of its bones is), to a SHOULDER round its joint, and the
    rest to the TORSO."""
    import cv2
    import numpy as np
    oval = face2d[OVAL]
    hc = oval.mean(axis=0)
    hr = float(np.hypot(*(oval - hc).T).mean())
    p = np.asarray(pose, dtype=np.float64).reshape(33, 4)
    seen = p[11, 3] > 0.5 and p[12, 3] > 0.5
    shoulder_y = float(p[[11, 12], 1].mean() * h) if seen else float(face2d[CHIN][1] + 1.2 * hr)
    neck_y = (float(face2d[CHIN][1]) + shoulder_y) * 0.5
    away = cv2.distanceTransform((matte <= 0.5).astype(np.uint8), cv2.DIST_L2, 5)
    skel = skeleton(pose, w, h)
    col = {b: i for i, b in enumerate(BONES)}
    out = np.zeros((len(pts), len(BONES)))
    for n, q in enumerate(pts):
        q = np.asarray(q, dtype=np.float64)
        wh = smooth(1.9, 1.15, float(np.hypot(*(q - hc))) / hr) * smooth(shoulder_y, neck_y, float(q[1]))
        x, y = int(np.clip(q[0], 0, w - 1)), int(np.clip(q[1], 0, h - 1))
        wb = max(wh, smooth(150.0, 40.0, float(away[y, x])))
        out[n, col["head"]] = wh
        body = wb - wh
        if body <= 0.0:
            continue
        if skel is None:
            out[n, col["torso"]] = body
            continue
        # ON AN ARM: as much as it is inside the arm's nearest bone, shared among its bones by nearness
        arm_total = 0.0
        shares = {}
        for side in ("l", "r"):
            near = [(name, _segment_distance(q, a, b) / r) for name, a, b, r in arm_bones(skel, side)]
            inside = max(smooth(1.6, 0.9, d) for _, d in near)
            if inside <= 0.0:
                continue
            inv = np.array([1.0 / max(d, 0.05) ** 4 for _, d in near])
            inv /= inv.sum()
            for (name, _), f in zip(near, inv):
                shares[name] = shares.get(name, 0.0) + inside * float(f)
            arm_total += inside
        if arm_total > 1.0:
            shares = {k: v / arm_total for k, v in shares.items()}
            arm_total = 1.0
        for name, v in shares.items():
            out[n, col[name]] = body * v
        rest = body * (1.0 - arm_total)
        # ROUND A SHOULDER'S JOINT, the shoulder's own
        sh_total = 0.0
        for side in ("l", "r"):
            s = smooth(SHOULDER_R, SHOULDER_R * 0.3, float(np.hypot(*(q - skel[side]["shoulder"]))) / skel["width"])
            out[n, col["shoulder_" + side]] = rest * s
            sh_total += s
        out[n, col["torso"]] = rest * max(0.0, 1.0 - sh_total)
    return out


def skeleton_json(skel, face2d, w: int, h: int) -> dict:
    """[skel] as the rig keeps it (pixels, rounded); with none seen, a torso under the face whose arms go
    with it."""
    import numpy as np

    def pt(v):
        return [round(float(v[0]), 2), round(float(v[1]), 2)]

    if skel is None:
        c = face2d[CHIN]
        fw = float(face2d[OVAL][:, 0].max() - face2d[OVAL][:, 0].min())
        neck = c + np.array([0.0, 0.6 * fw])
        skel = {"neck": neck, "hip": np.array([neck[0], float(h)]), "width": 2.0 * fw}
        for side, sx in (("l", 1.0), ("r", -1.0)):
            s = neck + np.array([sx * fw, 0.0])
            skel[side] = {"shoulder": s, "elbow": s, "wrist": s, "tip": s, "rests": False}
    out = {"neck": pt(skel["neck"]), "hip": pt(skel["hip"]), "width": round(float(skel["width"]), 2)}
    for side in ("l", "r"):
        a = skel[side]
        out[side] = {k: pt(a[k]) for k in ("shoulder", "elbow", "wrist", "tip")}
        out[side]["rests"] = bool(a["rests"])
    return out


def cmd_rig(a) -> int:
    """THE SET'S MESH, made on its first still: its face, the rings round it, the frame's edge, one
    triangulation - and the face's BOX, where the library keeps its mouths and eyes, with a mask for
    each: the lips with a little round them, and each eye's lids (the beard round the mouth stays the
    still's, bent with the jaw, and never swaps from one mouth to the next). And for EVERY still its
    body's mesh on its skeleton, each vertex weighed to its bones ([skeleton], [body_points],
    [skin_weights])."""
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
    # (no higher than the lids' fold: grown taller, a glance brought another moment's brows with it)
    eye_mask = feathered((img_h, img_w), [grown(r, 1.45, 1.9) for r in rims], eye_w * 0.1)
    out_dir = os.path.dirname(a.out)
    save_mask(os.path.join(out_dir, "mask_mouth.png"), mouth)
    save_mask(os.path.join(out_dir, "mask_eyes.png"), eye_mask)

    # THE TRIANGLES THAT MOVE MOST LAST: a canvas mesh draws in order, so lips and lids are never under a fold
    def moving(t):
        return min(max(weights[i], eyes[i]) if i < FACE_POINTS else 0.0 for i in t) > 0.5
    tris.sort(key=lambda t: 1 if moving(t) else 0)
    # EACH STILL'S BODY: its own mesh - the face's points, its rings, its body's, the frame's edge - and
    # each vertex's following of the head and of the body (the third pass: the whole of them moves)
    import cv2
    still_dir = os.path.join(os.path.dirname(a.stills), "stills")
    bodies = []
    for sk in stills:
        face_k = to_pixels([sk["points"]], W, H)[0]
        path = os.path.join(still_dir, str(sk.get("matte", "")))
        m = cv2.imread(path, 0) if sk.get("matte") and os.path.exists(path) else None
        matte = m.astype(np.float32) / 255.0 if m is not None and m.shape == (H, W) else np.zeros((H, W), np.float32)
        pose = sk.get("pose") or [0.0] * 132
        r1, r2 = ring_of(face_k, a.ring1), ring_of(face_k, a.ring2)
        body = body_points(face_k, pose, matte, W, H, a.ring1, np.vstack([r2, anchors]))
        pts = np.vstack([face_k, r1, r2, body, anchors])
        tris_k = triangulate(pts, W, H)
        tris_k.sort(key=lambda t: 1 if moving(t) else 0)
        skin = skin_weights(np.vstack([r2, body, anchors]), face_k, pose, matte, W, H)
        skin[-anchors.shape[0]:] = 0.0
        skel = skeleton(pose, W, H)
        bodies.append({"body": [[round(float(x), 2), round(float(y), 2)] for x, y in body],
                       "skin": {b: [round(float(x), 3) for x in skin[:, i]] for i, b in enumerate(BONES)},
                       "skeleton": skeleton_json(skel, face_k, W, H), "triangles": tris_k})
    rig = {
        "size": [W, H], "points": int(allpts.shape[0]), "face": FACE_POINTS, "oval": OVAL,
        "ring1": a.ring1, "ring2": a.ring2, "ring_moves": a.ring_moves,
        "layout": [[round(float(x), 3), round(float(y), 3)] for x, y in layout],
        "mean": [[round(float(x), 2), round(float(y), 2)] for x, y in allpts],
        "anchors": [[round(x / W, 5), round(y / H, 5)] for x, y in anchors],
        "triangles": tris, "moving_triangles": sum(1 for t in tris if moving(t)), "stills": bodies,
        "weights": [round(float(x), 3) for x in weights],
        "eye_weights": [round(float(x), 3) for x in eyes],
        "box": [round(x0, 3), round(y0, 3), round(x1, 3), round(y1, 3)], "image": [img_w, img_h],
        "masks": {"mouth": "mask_mouth.png", "eyes": "mask_eyes.png"},
        "lips": LIPS_OUTER + LIPS_INNER, "cheeks": [CHEEK_LEFT, CHEEK_RIGHT],
    }
    write_json(a.out, rig)
    say("rig: %d points, %d triangles, %d body vertices, the face's box %dx%d" % (
        allpts.shape[0], len(tris), len(bodies[0]["body"]) if bodies else 0, img_w, img_h))
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
    at the class's phones - where their words (captions, or what Transcribe heard) give enough of them -
    else the class's place in their own range (each class's `range`: a percentile of their range per
    blendshape)."""
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
    # DO THE WORDS SHOW IN THEIR MOUTH? The jaw the sounds' medians span, over the jaw their range spans:
    # a mouth hidden by a beard, or words timed only to the word, give each sound nearly the same median
    # (2026-10-22, his: "open" 0.095, P B M 0.072, his range 0.01 to 0.31) - and drawn from those the
    # mouth would scarcely move. Below [WORDS_SHOW] every sound keeps its place in their range.
    jaw = MOUTH_NAMES.index("jawOpen")
    medians = [np.median(np.array(g), axis=0)[jaw] for g in hits.values() if len(g) >= least]
    span = float(pct[95][jaw] - pct[5][jaw]) or 1.0
    shows = (max(medians) - min(medians)) / span if len(medians) > 1 else 0.0
    for cls, row in spec["classes"].items():
        got = hits.get(cls, [])
        if len(got) >= least and shows >= WORDS_SHOW:
            med = np.median(np.array(got), axis=0)
            out[cls] = {"blend": [round(float(x), 4) for x in med], "n": len(got), "from": "words"}
            continue
        from_range = pct[50].copy()
        for name, q in (row.get("range") or {}).items():
            if name in MOUTH_NAMES:
                from_range[MOUTH_NAMES.index(name)] = pct[min(pct, key=lambda p: abs(p - int(q)))][MOUTH_NAMES.index(name)]
        out[cls] = {"blend": [round(float(x), 4) for x in from_range], "n": len(got), "from": "range"}
    write_json(a.out, {"names": MOUTH_NAMES, "classes": out, "words_show": round(shows, 3),
                       "range": {str(q): [round(float(x), 4) for x in v] for q, v in pct.items()}})
    learned = sum(1 for c in out.values() if c["from"] == "words")
    if learned:
        say("visemes: %d sounds, %d learned from their words, the rest from their range" % (len(out), learned))
    elif medians:
        say("visemes: %d sounds, from their own range (their words scarcely show in their mouth: %.2f)" % (len(out), shows))
    else:
        say("visemes: %d sounds, from their own range (no words)" % len(out))
    return 0


# The share of their jaw's range the sounds' medians must span before the words, not the range, place
# each sound's mouth ([cmd_visemes]); the range's own places span about 0.85 of it.
WORDS_SHOW = 0.4


# --- motion ----------------------------------------------------------------------------------------

# THEIR MOTION, a row per look (the third pass: the head turns on the body, the body carries it): the
# head's yaw, pitch and roll against the shoulders (degrees); where the shoulders are across and down (in
# face widths), how near they lean (the log of the face's width) and the shoulders' tilt (degrees, as the
# picture turns: the right of the picture lower is more).
AXES = ["yaw", "pitch", "roll", "x", "y", "near", "tilt"]
# A run is at least this many seconds; its quick part is what moves within this many.
LEAST_RUN = 8.0
DRIFT = 4.0
# A look this many of their own spreads off on any axis ends a run there: a turn to a screen, a lean out.
WILD = 4.0
# A blink is caught by a look only when it falls in one: about the share of the spacing a blink lasts.
CAUGHT = 0.55
# THEIR POSTURE (the fourth pass, 2026-10-22: "rocking weirdly back and forth" - the body played its quick
# part, 2-4 s swings that are mostly their gestures pulling at their shoulders): where the shoulders sit,
# averaged over this many seconds, against the shot's own middle - how far they lean and settle, which
# ways go together, and how long a posture holds (the lag their posture's likeness to itself falls to 1/e).
POSTURE_S = 6.0
# THEIR FACE'S OWN MOTION (2026-10-24, the user on the head of splats: "when the actor is not talking - the face
# is not moving at all"; his brows, cheeks and lids move three quarters as much silent as speaking): every score
# but what a Likeness plays itself - the blinks and the gaze (its blinks and glances) and the lips' opening and
# protrusion (the voice's sounds; a beard reads as a pucker besides, his 90th percentile 0.71) - its quick part
# (as the head's), smoothed to what a face does slowly (a Gaussian of FACE_SMOOTH seconds: MediaPipe's scores
# jitter from look to look, the slow part of them going on from one look to the next), as the principal
# components holding FACE_SHARE of it, at most FACE_MOST.
FACE_LEAVES = ("_neutral", "eyeBlink", "eyeLook", "jawOpen", "mouthClose", "mouthFunnel", "mouthPucker", "mouthRoll",
               "mouthLowerDown", "mouthUpperUp")
FACE_SMOOTH = 0.4
FACE_SHARE = 0.9
FACE_MOST = 6


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


def motion_rows(R, idx, aspect, roll_sign: float):
    """THEIR MOTION at looks [idx], [AXES]: the head's turn, its roll as the picture turns ([roll_sign]
    makes it so) less the shoulders' tilt, and the shoulders' place, nearness and tilt."""
    import numpy as np
    box = R["box"][idx].astype(np.float64)
    bw = np.maximum(box[:, 2] - box[:, 0], 1e-4)
    fw = float(np.median(bw))
    pose = np.asarray(R["pose"][idx], dtype=np.float64).reshape(-1, 33, 4)
    left, right = pose[:, 11, :2], pose[:, 12, :2]
    tilt = np.degrees(np.arctan2((left[:, 1] - right[:, 1]) * aspect, np.maximum(left[:, 0] - right[:, 0], 1e-4)))
    ang = R["angles"][idx]
    x = (left[:, 0] + right[:, 0]) * 0.5 / fw
    y = (left[:, 1] + right[:, 1]) * 0.5 * aspect / fw
    return np.column_stack([ang[:, 0], ang[:, 1], ang[:, 2] * roll_sign - tilt, x, y, np.log(bw / fw), tilt])


def face_names():
    """The scores their face moves on its own ([FACE_LEAVES] left out), in MediaPipe's order."""
    return [n for n in BLEND_NAMES if not n.startswith(FACE_LEAVES)]


def smooth_looks(X, sigma: float):
    """[X] ([n, d]) under a Gaussian of [sigma] looks, its ends held."""
    import numpy as np
    X = np.asarray(X, dtype=np.float64)
    h = max(1, int(math.ceil(2.5 * sigma)))
    g = np.exp(-0.5 * (np.arange(-h, h + 1) / max(sigma, 1e-6)) ** 2)
    g /= g.sum()
    pad = np.concatenate([np.repeat(X[:1], h, axis=0), X, np.repeat(X[-1:], h, axis=0)], axis=0)
    return np.stack([np.convolve(pad[:, j], g, mode="valid") for j in range(X.shape[1])], axis=1)


def face_components(F):
    """THE WAYS THEIR FACE MOVES in [F] ([n, len(face_names())], its slow part): the principal components holding
    [FACE_SHARE] of it, at most [FACE_MOST] - `(basis [K, d], sd [K])`, each row a unit direction."""
    import numpy as np
    F = np.asarray(F, dtype=np.float64)
    w, V = np.linalg.eigh(np.cov((F - F.mean(axis=0)).T))
    o = np.argsort(w)[::-1]
    w, V = np.maximum(w[o], 0.0), V[:, o]
    share = np.cumsum(w) / max(float(w.sum()), 1e-12)
    k = int(min(FACE_MOST, np.searchsorted(share, FACE_SHARE) + 1))
    return V[:, :k].T, np.sqrt(w[:k])


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


def posture_of(R, runs, rate: float, roll_sign: float, spec):
    """THEIR POSTURE over [runs]: the shoulders' place, nearness and tilt ([AXES] 3 on) averaged over
    [POSTURE_S] seconds, each run's own middle taken out: `{sd, corr, tau}` - each axis's spread, how the
    axes go together, and the seconds a posture holds."""
    import numpy as np
    k = max(3, int(round(POSTURE_S * rate)) | 1)
    slow, lags = [], []
    for idx in runs:
        v = spec["videos"].get(R["vid"][idx[0]], {})
        size = v.get("size", [16, 9])
        X = motion_rows(R, idx, float(size[1]) / float(size[0]), roll_sign)[:, 3:]
        S = X - high_pass(X, k)
        S = S - np.median(S, axis=0)
        slow.append(S)
        if S.shape[0] >= 4 * k:
            c = S - S.mean(axis=0)
            for j in range(c.shape[1]):
                var = float(c[:, j].var())
                if var < 1e-12:
                    continue
                for lag in range(1, S.shape[0] // 2):
                    if float((c[:-lag, j] * c[lag:, j]).mean()) / var < 1.0 / math.e:
                        lags.append(lag / rate)
                        break
    S = np.concatenate(slow) if slow else np.zeros((0, 4))
    if S.shape[0] < 10:
        return {"sd": [0.0] * 4, "corr": np.eye(4).tolist(), "tau": 5.0}
    sd = S.std(axis=0)
    corr = np.corrcoef(S.T) if np.all(sd > 0) else np.eye(4)
    return {"sd": [round(float(x), 5) for x in sd], "corr": [[round(float(x), 3) for x in r] for r in corr],
            "tau": round(float(np.median(lags)), 2) if lags else 5.0}


def cmd_motion(a) -> int:
    """THEIR HEAD'S OWN MOTION, from every video's survey where they face the camera: its quick part (the
    slow drift out), in runs a Likeness plays back in pieces, which looks are speech, and how often they
    blink (next/likeness.md, "The second build"); THEIR POSTURE - how far and which ways their body
    settles, and how long it holds ([posture_of], the fourth pass); and THEIR FACE'S OWN MOTION at the same
    looks ([face_components]: `face` - its scores' names, the directions, their spreads - and each run's
    `face` rows, how far along each the face is), so a piece moves their head and face as they moved together."""
    import numpy as np
    spec = read_json(a.spec)
    rate = float(spec.get("rate", 5.0))
    R = survey_records(spec["videos"], spec["shots"])
    if R["count"] < LEAST_RUN * rate:
        say("motion: too little usable footage (%d looks)" % R["count"])
        return 2
    ang = R["angles"]
    pose = np.asarray(R["pose"], dtype=np.float64).reshape(-1, 33, 4)
    shoulders = (pose[:, 11, 3] > 0.5) & (pose[:, 12, 3] > 0.5)
    facing = (np.abs(ang[:, 0]) < FACING) & (np.abs(ang[:, 1]) < FACING) & shoulders
    # THE HEAD'S ROLL AS THE PICTURE TURNS: the head and the shoulders lean together, so the roll's sign
    # is whichever goes with the shoulders' tilt in their own looks
    tilt = np.degrees(np.arctan2(pose[:, 11, 1] - pose[:, 12, 1], np.maximum(pose[:, 11, 0] - pose[:, 12, 0], 1e-4)))
    roll_sign = 1.0 if facing.sum() < 50 or np.corrcoef(ang[facing, 2], tilt[facing])[0, 1] >= 0 else -1.0
    runs = runs_of(R, rate, facing)
    k = max(3, int(round(DRIFT * rate)) | 1)
    trim = int(round(rate))
    jaw = R["blend"][:, JAW].astype(np.float64)
    names = face_names()
    cols = [BLEND_NAMES.index(n) for n in names]
    blend = np.asarray(R["blend"], dtype=np.float64)
    pieces = []
    for idx in runs:
        v = spec["videos"].get(R["vid"][idx[0]], {})
        size = v.get("size", [16, 9])
        X = high_pass(motion_rows(R, idx, float(size[1]) / float(size[0]), roll_sign), k)[trim:-trim]
        j = jaw[idx]
        spread = np.array([j[max(0, i - 5): i + 6].std() for i in range(j.size)])[trim:-trim]
        F = smooth_looks(high_pass(blend[idx][:, cols], k), FACE_SMOOTH * rate)[trim:-trim]
        pieces.append((idx[trim:-trim], X, spread, F))
    if not pieces:
        say("motion: no run of %d seconds facing the camera" % int(LEAST_RUN))
        return 2
    allx = np.concatenate([p[1] for p in pieces])
    sd = 1.4826 * np.median(np.abs(allx - np.median(allx, axis=0)), axis=0)
    sd = np.maximum(sd, 1e-6)
    talking = float(np.median(np.concatenate([p[2] for p in pieces])))
    basis, face_sd = face_components(np.concatenate([p[3] for p in pieces]))
    # A LOOK FAR OUT ON ANY AXIS ENDS ITS RUN: what is kept is how they move while they talk to the camera
    out = []
    for idx, X, spread, F in pieces:
        C = F @ basis.T
        wild = (np.abs(X) > WILD * sd).any(axis=1)
        start = 0
        for i in range(X.shape[0] + 1):
            if i == X.shape[0] or wild[i]:
                if i - start >= LEAST_RUN * rate:
                    out.append({"vid": str(R["vid"][idx[start]]), "t0": round(float(R["time"][idx[start]]), 2),
                                "talk": "".join("1" if s > talking else "0" for s in spread[start:i]),
                                "rows": [[round(float(x), 4) for x in r] for r in X[start:i]],
                                "face": [[round(float(x), 4) for x in r] for r in C[start:i]]})
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
    posture = posture_of(R, runs, rate, roll_sign, spec)
    face = {"names": names, "basis": [[round(float(x), 5) for x in r] for r in basis],
            "sd": [round(float(x), 5) for x in face_sd]}
    write_json(a.out, {"rate": rate, "axes": AXES, "sd": [round(float(x), 5) for x in sd],
                       "roll_sign": roll_sign, "blinks_per_min": round(blinks, 1), "posture": posture, "face": face,
                       "runs": kept})
    say("motion: %.0f minutes of their head in %d runs, %.0f blinks a minute; a posture holds %.0f s; their face "
        "moves %d ways of its own" % (total / rate / 60.0, len(kept), blinks, posture["tau"], len(face_sd)))
    return 0


# --- learn -----------------------------------------------------------------------------------------

# THEIR MOUTH, LEARNED (the third pass, 2026-10-22, the user: "true learning of some sort. Some internal
# neurons, updated via a simple rule, and informed by ALL sets of videos. Maybe even some kind of ensemble
# method."): from the sounds heard round a moment - which class at each of these offsets (seconds) - to
# their mouth's shape at it.
OFFSETS = [-0.24, -0.18, -0.12, -0.06, 0.0, 0.06, 0.12, 0.18, 0.24]
# Each offset's window (seconds): the windows touch, so every sound in reach is counted once.
WINDOW = 0.06
# The ensemble: this many members, each this many neurons, trained this many passes on its own resample.
MEMBERS = 8
HIDDEN = 32
EPOCHS = 40
# A look this far (seconds) from every word heard is outside what was transcribed, and teaches nothing.
NEAR_WORDS = 1.5


def class_line(phones):
    """[phones] (`[{vid, t0, t1, class}]`) as each video's line, in order: `{vid: (starts, ends, classes)}`, a
    phone held until the next begins when the gap is short (as Visemes.timeline does)."""
    import numpy as np
    by = {}
    for ph in phones:
        if ph.get("class"):
            by.setdefault(str(ph["vid"]), []).append((float(ph["t0"]), float(ph["t1"]), str(ph["class"])))
    out = {}
    for vid, ps in by.items():
        ps.sort()
        t0 = np.array([p[0] for p in ps])
        t1 = np.array([p[1] for p in ps])
        nxt = np.r_[t0[1:], np.inf]
        t1 = np.where((nxt - t1 < 0.12) & (nxt > t1), nxt, t1)
        out[vid] = (t0, t1, [p[2] for p in ps])
    return out


def contexts(line, vid, times, classes):
    """THE INPUTS: for each moment in [times], how much of each of [classes] is heard in the window of
    [WINDOW] seconds round each of [OFFSETS] from it (the rest wherever none is), window by window: [n,
    len(OFFSETS) * len(classes)]. Shares, not a class at a point, so the mouth they make moves smoothly
    as the sounds pass (LikenessPlan reads them so)."""
    import numpy as np
    k = len(classes)
    rest = classes.index("rest")
    times = np.asarray(times, dtype=np.float64)
    X = np.zeros((len(times), len(OFFSETS) * k), dtype=np.float32)
    got = line.get(vid)
    for j, o in enumerate(OFFSETS):
        a0 = times + o - WINDOW * 0.5
        a1 = a0 + WINDOW
        heard = np.zeros(len(times))
        if got is not None:
            t0, t1, cl = got
            first = np.clip(np.searchsorted(t1, a0, side="right"), 0, len(t0))
            for n in range(len(times)):
                i = first[n]
                while i < len(t0) and t0[i] < a1[n]:
                    over = min(a1[n], t1[i]) - max(a0[n], t0[i])
                    if over > 0:
                        c = classes.index(cl[i]) if cl[i] in classes else rest
                        X[n, j * k + c] += over / WINDOW
                        heard[n] += over / WINDOW
                    i += 1
        X[:, j * k + rest] += np.clip(1.0 - heard, 0.0, 1.0)
    return X


def train_member(X, Y, seed: int, epochs=EPOCHS, hidden=HIDDEN, lr=3e-3, decay=1e-4, batch=256):
    """ONE NETWORK: [X] to [Y] through [hidden] tanh neurons, trained by gradient descent (Adam, a little
    weight decay) on mean squared error: `(w1, b1, w2, b2)`."""
    import numpy as np
    rng = np.random.default_rng(seed)
    n, d = X.shape
    m = Y.shape[1]
    w1 = rng.normal(0, 1.0 / math.sqrt(len(OFFSETS)), (d, hidden)).astype(np.float64)
    b1 = np.zeros(hidden)
    w2 = rng.normal(0, 1.0 / math.sqrt(hidden), (hidden, m))
    b2 = np.zeros(m)
    params = [w1, b1, w2, b2]
    mom = [np.zeros_like(p) for p in params]
    vel = [np.zeros_like(p) for p in params]
    step = 0
    for _ in range(epochs):
        order = rng.permutation(n)
        for b0 in range(0, n, batch):
            idx = order[b0:b0 + batch]
            x, y = X[idx], Y[idx]
            h = np.tanh(x @ w1 + b1)
            err = (h @ w2 + b2) - y
            g2 = h.T @ err / len(idx) + decay * w2
            gb2 = err.mean(axis=0)
            dh = (err @ w2.T) * (1.0 - h * h)
            g1 = x.T @ dh / len(idx) + decay * w1
            gb1 = dh.mean(axis=0)
            step += 1
            for p, g, mo, ve in zip(params, [g1, gb1, g2, gb2], mom, vel):
                mo *= 0.9
                mo += 0.1 * g
                ve *= 0.999
                ve += 0.001 * g * g
                p -= lr * (mo / (1 - 0.9 ** step)) / (np.sqrt(ve / (1 - 0.999 ** step)) + 1e-8)
    return w1, b1, w2, b2


def ensemble_predict(members, X):
    """The members' mean: what the ensemble says."""
    import numpy as np
    out = 0.0
    for w1, b1, w2, b2 in members:
        out = out + np.tanh(X @ w1 + b1) @ w2 + b2
    return out / len(members)


def r2(pred, Y, weights):
    """The share of [Y]'s spread [pred] explains, each column weighed by [weights]."""
    import numpy as np
    ss = ((Y - pred) ** 2).sum(axis=0)
    st = ((Y - Y.mean(axis=0)) ** 2).sum(axis=0)
    return float(1.0 - (ss * weights).sum() / max(1e-9, (st * weights).sum()))


def cmd_learn(a) -> int:
    """THEIR MOUTH FOR THE VOICE'S SOUNDS, LEARNED FROM EVERY VIDEO: an ensemble of small networks from the
    sounds round a moment to their mouth's shape at it ([contexts], [train_member]), each member trained on
    its own resample of every survey look near the words heard. One video is held out first, to say how
    much of their mouth the ensemble explains there beside the plainest model (each sound's mean mouth),
    then every video trains the ensemble kept."""
    import numpy as np
    spec = read_json(a.spec)
    classes = list(spec["classes"])
    R = survey_records(spec["videos"], spec["shots"])
    line = class_line(spec.get("phones", []))
    if R["count"] < 200 or not line:
        say("learn: no words to learn from (%d looks, %d videos with words)" % (R["count"], len(line)))
        return 2
    ang = R["angles"]
    facing = (np.abs(ang[:, 0]) < FACING) & (np.abs(ang[:, 1]) < FACING) & ~hands_at_mouth_all(R["pose"], R["box"])
    # only the looks near words heard: elsewhere nothing was transcribed, and silence would be a lie
    near = np.zeros(R["count"], dtype=bool)
    for vid, (t0, t1, _cl) in line.items():
        sel = np.nonzero(R["vid"] == vid)[0]
        if sel.size == 0:
            continue
        tt = R["time"][sel]
        j = np.clip(np.searchsorted(t0, tt), 1, len(t0) - 1)
        gap = np.minimum(np.abs(tt - t0[j - 1]), np.minimum(np.abs(tt - t1[j - 1]), np.abs(tt - t0[j])))
        near[sel] = (gap < NEAR_WORDS) | ((tt >= t0[j - 1]) & (tt <= t1[j - 1]))
    use = np.nonzero(facing & near)[0]
    if use.size < 500:
        say("learn: too few looks near their words (%d)" % use.size)
        return 2
    X = np.zeros((use.size, len(OFFSETS) * len(classes)), dtype=np.float32)
    for vid in set(R["vid"][use].tolist()):
        rows = np.nonzero(R["vid"][use] == vid)[0]
        X[rows] = contexts(line, vid, R["time"][use][rows], classes)
    raw = R["blend"][use][:, MOUTH_INDEX].astype(np.float64)
    mean, sd = raw.mean(axis=0), np.maximum(raw.std(axis=0), SPREAD_FLOOR)
    # EACH VIDEO AGAINST ITS OWN MEAN AND SPREAD: a camera, a light, a distance each measure their mouth
    # at a level of their own (their jaw while speaking 0.08 in one video, 0.16 in another), and what is
    # learned is how it moves with the sounds, not where a video sits
    Y = np.zeros_like(raw)
    for vid in set(R["vid"][use].tolist()):
        rows = R["vid"][use] == vid
        Y[rows] = (raw[rows] - raw[rows].mean(axis=0)) / np.maximum(raw[rows].std(axis=0), SPREAD_FLOOR)
    weights = np.array([KEY_WEIGHT.get(n, 0.5) for n in MOUTH_NAMES])
    vids = R["vid"][use]
    # HOW MUCH IT EXPLAINS, on a video it never saw: the one with the most looks held out
    counts = {v: int((vids == v).sum()) for v in set(vids.tolist())}
    held = max(counts, key=counts.get) if len(counts) > 1 else None
    scores = {}
    if held is not None:
        tr, te = vids != held, vids == held
        centre = OFFSETS.index(0.0) * len(classes)
        # the plainest model: each sound's mean mouth, for whichever fills the middle window most
        by_class = {}
        for c in range(len(classes)):
            rows = np.nonzero(tr & (X[:, centre + c] > 0))[0]
            by_class[c] = Y[rows].mean(axis=0) if rows.size else np.zeros(Y.shape[1])
        plain = np.array([by_class[int(np.argmax(x[centre:centre + len(classes)]))] for x in X[te]])
        members = [train_member(X[tr][idx], Y[tr][idx], seed=k)
                   for k, idx in enumerate(np.random.default_rng(7 + k).integers(0, int(tr.sum()), int(tr.sum())) for k in range(MEMBERS))]
        jaw = MOUTH_NAMES.index("jawOpen")
        ens = ensemble_predict(members, X[te])
        one = ensemble_predict(members[:1], X[te])
        scores = {"held_out": held, "looks": int(te.sum()),
                  "each_sound_mean": round(r2(plain, Y[te], weights), 3), "one_network": round(r2(one, Y[te], weights), 3),
                  "ensemble": round(r2(ens, Y[te], weights), 3),
                  "ensemble_jaw": round(r2(ens[:, jaw:jaw + 1], Y[te][:, jaw:jaw + 1], np.ones(1)), 3)}
        progress(a.progress, 0.5)
    # THE ENSEMBLE KEPT: every look of every video, each member its own resample
    rng = np.random.default_rng(11)
    members = [train_member(X[idx], Y[idx], seed=100 + k) for k, idx in
               enumerate(rng.integers(0, X.shape[0], X.shape[0]) for _ in range(MEMBERS))]
    write_json(a.out, {"classes": classes, "offsets": OFFSETS, "window": WINDOW, "names": MOUTH_NAMES,
                       "weights": [float(x) for x in weights], "pushed": [MOUTH_NAMES[i] for i in PUSHED],
                       "mean": [round(float(x), 6) for x in mean], "sd": [round(float(x), 6) for x in sd],
                       "members": [{"w1": [[round(float(v), 5) for v in row] for row in w1], "b1": [round(float(v), 5) for v in b1],
                                    "w2": [[round(float(v), 5) for v in row] for row in w2], "b2": [round(float(v), 5) for v in b2]}
                                   for w1, b1, w2, b2 in members],
                       "looks": int(use.size), "scores": scores})
    progress(a.progress, 1.0)
    if scores:
        say("learn: %d looks; on a video it never saw it explains %.0f%% of their mouth (each sound's mean mouth %.0f%%)" % (
            use.size, 100 * scores["ensemble"], 100 * scores["each_sound_mean"]))
    else:
        say("learn: %d looks of one video" % use.size)
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
# THE EYES' GLANCES, as the picture turns (the third pass: "The eyes never look around"): each the
# blendshapes that carry it, both eyes - their left eye looking out is the picture's right.
GLANCES = {"look_right": ["eyeLookOutLeft", "eyeLookInRight"], "look_left": ["eyeLookInLeft", "eyeLookOutRight"],
           "look_up": ["eyeLookUpLeft", "eyeLookUpRight"], "look_down": ["eyeLookDownLeft", "eyeLookDownRight"]}
# How far a glance looks (the blendshapes' mean) in the library's.
GLANCE = 0.55


def color_like(img, ring, still_img):
    """[img] in the still's colors round the part it is drawn into: its mean and spread in Lab on [ring]
    taken to [still_img]'s there (the spread's ratio within 0.8..1.25), the whole image moved so (2026-10-22:
    matched by the cheeks alone, every mouth came out a color of its own - "blurry flickering patterns")."""
    import cv2
    import numpy as np
    a_ = cv2.cvtColor(img, cv2.COLOR_RGB2LAB).astype(np.float64)
    b_ = cv2.cvtColor(still_img, cv2.COLOR_RGB2LAB).astype(np.float64)
    where = ring & (img.sum(axis=2) > 0) & (still_img.sum(axis=2) > 0)
    if where.sum() < 50:
        return img
    for c in range(3):
        ma, sa = a_[..., c][where].mean(), a_[..., c][where].std()
        mb, sb = b_[..., c][where].mean(), b_[..., c][where].std()
        k = float(np.clip(sb / max(sa, 1e-3), 0.8, 1.25))
        a_[..., c] = (a_[..., c] - ma) * k + mb
    return cv2.cvtColor(np.clip(a_, 0, 255).astype(np.uint8), cv2.COLOR_LAB2RGB)


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


def glance_cost(blend, looks, g):
    """How far each look's eyes are from glancing [g]: its own blendshapes at [GLANCE], the others' and the
    blink low, both eyes alike."""
    import numpy as np
    bl = np.asarray(blend, dtype=np.float64).reshape(-1, 52)
    mine = bl[:, looks[g]]
    others = sum(bl[:, looks[o]].mean(axis=1) for o in looks if o != g)
    return (((mine.mean(axis=1) - GLANCE) / 0.12) ** 2 + ((mine[:, 0] - mine[:, 1]) / 0.2) ** 2
            + (others / 0.15) ** 2 + (bl[:, BLINK].mean(axis=1) / 0.12) ** 2)


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
    closed and glancing aside - from any video, at the still's turn, found in the surveys, then looked at
    again at full size, unwrapped into the rig's box and matched to the still's colors (next/likeness.md,
    the second build and the third pass). Silence and open eyes are the still's own."""
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
    looks = {g: [BLEND_NAMES.index(n) for n in names] for g, names in GLANCES.items()}
    for g in GLANCES:
        d = glance_cost(R["blend"], looks, g) + turn
        d[~near] = np.inf
        for i in spaced(np.argsort(d), R, 1.5, CANDIDATES):
            if np.isfinite(d[i]):
                wants.append({"kind": "eye", "name": g, "target": GLANCE, "i": i})
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
        elif w["name"] in GLANCES:
            cost += float(glance_cost(bl.reshape(1, -1), looks, w["name"])[0])
            region = EYE_RIGHT + EYE_LEFT
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
    # IN THE STILL'S COLORS: each image matched to the still's own face round the lips or the lids
    still_rgb = cv2.cvtColor(cv2.imread(os.path.join(os.path.dirname(spec["stills"]), "stills", still["file"])), cv2.COLOR_BGR2RGB)
    sh, sw = still_rgb.shape[:2]
    still_face = to_pixels([still["points"]], sw, sh)[0]
    still_img = unwrap(still_rgb, still_face, rig, tris)
    rings = {}
    for kind, name in (("mouth", "mask_mouth.png"), ("eye", "mask_eyes.png")):
        mk = cv2.imread(os.path.join(os.path.dirname(spec["rig"]), name), 0)
        inside = (mk > 25) if mk is not None else np.zeros((rig.img_h, rig.img_w), bool)
        rings[kind] = (cv2.dilate(inside.astype(np.uint8), np.ones((31, 31), np.uint8)) > 0) & ~inside
    for g in kept:
        g["image"] = color_like(g["image"], rings[g["kind"]], still_img)
        g["light"] = still["light"]
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
            e["look"] = {k: round(float(g["blend"][[BLEND_NAMES.index(n) for n in v]].mean()), 3) for k, v in GLANCES.items()}
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

    for name, fn in (("visemes", cmd_visemes), ("motion", cmd_motion), ("learn", cmd_learn)):
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
