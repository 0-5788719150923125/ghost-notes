# Rendering in the cloud: a show cut into spans, rendered side by side

Asked 2026-10-30. Nothing is built, and nothing has been measured on AWS. The user: "Renders often take many
hours to complete, on my PC. I'm wondering: if we were to spawn ephemeral EC2 instances up on AWS, and do the
rendering there, how fast do you think we could get render times down to? I 'might' choose to leverage
'../platformer' for the infrastructure provisioning, just to make the setup and teardown reliable and repeatable."

## The answer, in short

A faster machine buys 1.5 to 2.5x. A show cut into time SPANS rendered at once on many machines buys far more, for
about the same money. Instance-hours cost the same whether one machine renders the whole show or twenty render a
twentieth each, so wall-clock time is almost free:

| A 30-minute video | Wall clock | Cost, spot | Cost, on-demand |
|---|---|---|---|
| This PC, today | about 4.6 h | - | - |
| 1 x g7.2xlarge | about 2-3 h | about $1.10 | about $6 |
| 10 x g7.2xlarge, 3-minute spans | about 20 min | about $1.50 | about $8 |
| 30 x g7.2xlarge, 1-minute spans | about 11 min | about $2.15 | about $12 |
| Any number | at least about 8 min | | |

The figures assume a cloud render at 5x real time (4-6x is the range, see below), a 10 s warm-up per span, about
3.5 minutes of fixed cost per worker (boot from a golden image, fetch, Godot start, the table built), a g7.2xlarge at
$0.45/h spot and $2.52/h on-demand, and a few minutes moving files to and from the PC. The 8-minute floor is that
fixed cost plus the PC's upload and download, and no number of workers moves it. Egress is about $0.09 per GB of
video.

## Where the time goes today

Measured from the two latest exports (the output MP4's birth time, when ffmpeg starts with the render, against
its last write), both True Tarot, the 1080p60 preset rendered at 2880x1620 (`ss` 1.5), no table physics:

- 626717, "Lightworkers Were Never Meant to Shine Alone": 557 s of video in 86.7 min - 6.4 fps, 9.3x real time.
- 274854, "If You Can't Sleep, I'll Keep You Company": 963 s in 146 min - 6.6 fps, 9.1x.

That is about 154 ms a frame. A work show bakes its physics on the render's own thread
(`TablePhysics.bake_until`), so expect it to be slower.

A render is ONE Godot process drawing every frame in order (`Exporter._start_render`: Movie Maker,
`--fixed-fps`, under `xvfb-run`), and each frame's costs ADD rather than overlap:

- Movie Maker reads the frame back from the GPU, so the CPU waits on the GPU every frame.
- Its MJPEG encode runs on the main thread: about 50 of 87 ms a frame at 2880x1620 when it was measured in the
  vortex days (a raw ffmpeg pipe was 2.5x faster; it was built and reverted, Godot's own writer kept).
- Xvfb's presentation costs about 13 ms a frame on its own (the medium frame-cost measurement, 2026-10-27).
- The medium's own frame: GDScript on the main thread, then the GPU (the table's 8192 shadow atlas, filtered
  shadows, candles).
- x264 (`medium`, `-tune grain`, lanczos down from 2880x1620) encodes beside it on the same 4 cores.

So the machine's age shows in every part. The i7-4790K is from 2014, and only the GPU (RTX 5060 Ti) is modern. A
G7's Xeon 6 (Granite Rapids) core might be 1.4-1.6x the 4790K's, its RTX PRO 4500 Blackwell has about twice the
5060 Ti's shader cores, and its spare cores take x264 off the critical path. All of that together is about 4-6x
real time: a 30-minute video still takes 2-3 hours. Step 1 measures the split instead of guessing it.

## What a span needs

The show is very nearly a function of show time already: the table is (`TablePlan`, "the table is a pure
function of show time"), a part a show mounts reads its clock from its `feed`, and scrubbing works live. The rest:

- **A render that starts part way through.** `--until` exists (`main._until`); `--from` does not. Spectrum's
  render clock counts show time from frames, from zero.
- **A warm-up.** What carries state from frame to frame needs time to settle before a span's first kept frame.
  Known candidates: `SubtitleSea`'s waves and the words' settle, `LetterMedium`'s camera springs (4.2 s) and
  `_letting_go`, `DeskMedium`'s elastic pen clock, the comic camera's follower, Spectrum's smoothing, and the
  Director's walk (each scene picked from the seed in order - `schedule` and `forecast` can walk it). A span
  starts its render at T - P and keeps frames from T.
- **The physics, to the span's start.** A work show's bake begins at frame 0 and keeps its checkpoints in memory
  (`TablePhysics._ck`). Either each worker bakes to T - P before it records (exact, no new format, but the last
  worker pays for nearly the whole show's bake), or the bake is made once and its checkpoints written to a file
  every worker restores from. Live, the grind baked at 1.14x real time.
- **Seams that are proved.** The warm-up IS the check: span k's warm-up frames overlap span k-1's last frames, so
  their hashes are compared frame for frame, and the first one that matches says how long a warm-up has to be.
  Exact hashes hold only on one GPU and one Godot binary, so every span of a job runs on one instance type, and
  the official Godot build (this PC runs Arch's package; seams compare cloud to cloud).
- **A stitch.** Each span is encoded on its own with the export's own x264 settings and color tags, video only,
  with a keyframe at its first frame (the 2 s GOP, so spans fall on 2 s boundaries). The spans are joined with
  `-c copy`, and the take's audio is laid over the whole once (AAC per span would leave a gap at every join).
- **Its inputs.** Everything the render reads: the working tree (`git ls-files -co --exclude-standard`, about
  27 MB), `ghost.cfg` (read-only in a render), the note and its episode folder (626717 is 91 MB), the take, the
  bake spec, whatever else of user:// it opens; an actor's folder for Likeness (gigabytes - later). The shader
  caches (`user://shader_cache` 106 MB, `user://vulkan` 110 MB) belong to a GPU and its driver, so they are kept in
  S3 by instance type, driver and Godot version, warmed as the image is built.

## The steps

Each step is worth having without the next one.

### 1. Measure the frame, and list what a render reads (no code)

A short render of 626717 with the Exporter's own argv and `--until 20`: `top -H` and `nvidia-smi` beside it for
the main thread's share against the GPU's, and `strace -f -e trace=openat` for every file it opens under res://
and user://.

Status: not started.

### 2. One instance, by hand

One g7.2xlarge spot instance (about $0.20-0.50 including the setup), with the NVIDIA driver, Xvfb, ffmpeg and the
official Godot 4.7.2 build, renders 30 s of 626717 from step 1's files. It answers the questions that decide
whether anything after it is worth building: the per-instance speed, whether Vulkan under Xvfb works on AWS's
driver (the GRID driver or NVIDIA's datacenter driver), and what a cold shader cache costs. A g6.4xlarge (L4,
16 vCPU) beside it, if G7 capacity is thin.

Status: not started.

### 3. A span: `--from`, the warm-up, the seam gate

`--from T` in the render path: the render clock begins at T - P, the Director walked to it, the medium handed it,
frames before T dropped at the encoder (`trim=start_frame`, so the count is exact). The gate renders a short show
whole and as two spans and compares the frames at the seam, exact on one GPU; the control is a warm-up of 0 on a
show with subtitles, which must fail. What the first runs turn up as stateful is either made a function of time
or given a longer warm-up.

Status: not started.

### 4. Physics to the span's start

Each worker bakes to T - P first. Measure it on a work show (the-quiet-crucible); write checkpoints to a file only
if the bake eats the gain.

Status: not started.

### 5. Spans on this PC

The Exporter renders N spans as N processes here and stitches them. That measures whether two at once beat one on
the 4790K and the 5060 Ti (a guess: 1.3-1.6x, if the GPU waits on the CPU), and it makes the cloud a change of WHERE
spans run, never of how.

Status: not started.

### 6. Platformer: the scaffolding that stays

Platformer holds what lives between renders; it never runs a render. A `terraform apply` per job takes minutes,
holds the state lock, and leaves a half-made fleet if the PC sleeps mid-apply. A workspace of its own (as arcbot
has), so one `terraform destroy` takes everything away:

- **build/**: a golden AMI class (Packer, as `build/` already does): Ubuntu 24.04, the NVIDIA driver with Vulkan
  (step 2 says which), Xvfb, ffmpeg, the official Godot build. Rebuilt when Godot moves - the project rides in each
  job's bundle, so a code change never needs a new image.
- **storage**: a bucket, its jobs expiring after 7 days.
- **networking**: a public subnet, a public IP, nothing inbound, an S3 gateway endpoint (free). No NAT gateway,
  which costs about $32 a month to sit there.
- **compute**: a new type that makes a launch template and no instances (zero at rest) - one of the "future
  compute platforms" its README names. Today it runs only long-lived instances: no spot, no fleet.
- **access**: one principal for ghost's launcher - `ec2:CreateFleet` and `RunInstances` on that template, the
  bucket, nothing else. Presigned S3 links in each instance's user data, so an instance needs no role beyond SSM's.
- **budget**: BUDGET.md's planned module (its `stop_instances`), or a plain monthly budget with an alert. Each
  instance's own timer (step 7) is the fast guard; a budget reacts in hours.
- **quota**: "All G and VT Spot Instance Requests" counts vCPUs. Ten g7.2xlarge are 80; ask for 128-256 before
  the first real job.

Status: not started.

### 7. ghost's launcher

The PC makes the take (as today) and the bake spec, writes the bundle to the job's S3 folder, and starts an
instant spot fleet (`aws ec2 create-fleet --type instant`), one span to a worker, the span's number and its
presigned links in its user data. A worker fetches, renders its span under Xvfb, uploads it with its warm-up
hashes and its log, and shuts down (terminate on shutdown); it sets `shutdown -h +<limit>` as it boots, so nothing
outlives a hung render. The PC watches the job's folder on a timer (as the Exporter watches its PIDs), starts a
span again when spot takes its machine back (two minutes' notice; short spans make that cheap), checks the seams,
stitches, and uploads to YouTube from here - the tokens never leave the PC. The aws CLI is a `Deps` row, fetched as
ffmpeg and uv are; the credentials are the user's own AWS profile, named, never kept by ghost.

Status: not started.

## Not taken, or later

- **A bigger single machine**: 1.5-2.5x, above.
- **AWS Batch**: array jobs map straight onto spans, with retries and scale-to-zero, but it needs a container with
  Vulkan through nvidia-container-toolkit's graphics capability. Docker was weighed for the helpers' sandbox and not
  taken (supply_chain.md - a different question). The fallback if a plain fleet turns fiddly.
- **Several spans per large instance** (a g6e.12xlarge has 4 GPUs and 48 vCPU): fewer boots, worth it only if
  boot time comes to dominate.
- **NVENC**: on a known GPU it would free the CPU; x264 stays unless step 2 shows the encode is the bottleneck.
- **Replacing MJPEG with a raw pipe**: 2.5x faster in the vortex measurement, built and reverted for Godot's own
  writer. Not reopened here; in the cloud it would multiply every worker, which is the only reason it is listed.

## Open questions for the user

- Where the choice lives. A row on the Environment panel ("Render on: this PC / AWS") is the guess - where renders
  run is a fact about the machine, like the sandbox checkbox, not about a note.
- The region: G7 launched in us-east-2 and us-west-2, and us-east-1 had it from July 10.
- A monthly spend cap.
- Likeness renders, whose actor folders are gigabytes: now or later.

## Prices

Third-party listings read 2026-10-30, not AWS's own page:
- g7.2xlarge (RTX PRO 4500 Blackwell, 32 GB; 8 vCPU of Xeon 6 Granite Rapids; 32 GiB): $2.52/h on-demand, about
  $0.32-0.75 spot. [Vantage](https://instances.vantage.sh/aws/ec2/g7.2xlarge),
  [Spare Cores](https://sparecores.com/server/aws/g7.2xlarge),
  [DevZero](https://www.devzero.io/instances/aws/g7.2xlarge),
  [Classmethod](https://dev.classmethod.jp/articles/ec2-g7-blackwell-gpu-instance-launch/) (regions).
- g6.4xlarge (L4; 16 vCPU of EPYC Milan): $1.32/h on-demand, about $0.67-0.95 spot.
  [Vantage](https://instances.vantage.sh/aws/ec2/g6.4xlarge),
  [Holori](https://calculator.holori.com/aws/ec2/g6.4xlarge).
- g7e (RTX PRO 6000 Blackwell): from about $3.36/h on-demand for one GPU - more than a render needs.
  [runs-on](https://go.runs-on.com/instances/ec2/g7e).
