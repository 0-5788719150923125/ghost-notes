# Harmonic content-addressed seeding

**Goal.** Reproduce the same show from the same *music*, not the same *file*. Audio here is lossy, so byte or file hashes break
on re-encode. The same musical content should also reconstruct similar geometries after cut-up, rearrangement and overlay
(speech, mashup). The seed comes from the harmonics themselves.

**What it is.** Locality-sensitive hashing of a perceptual harmonic descriptor (cosine-LSH, SimHash, random-hyperplane
hashing). The similarity search is over the *audio*, not over geometries; the geometry follows deterministically from where the
audio lands. The alternative is vector quantization (a seeded codebook of geometry prototypes, nearest by cosine). SimHash is
the codebook-free streaming version and is preferred, so no codebook ships.

## The two layers (this distinction is the whole thing)

1. **Perceptual harmonic signature** - a small, loudness-invariant descriptor of the *recent* audio:
   - 12-bin **chroma** (the 64 log-bands folded onto octave-wrapped pitch classes): timbre- and octave-robust, survives
     re-encoding, and tonal content dominates over overlaid noise.
   - A few coarse shape scalars (low/mid/high tilt, onset flux) for discrimination.
   - **L2-normalised** (removes gain and compression differences), **EMA-smoothed** over a few seconds (stable, not jittery)
     and **local** (depends only on a recent window, so a cut-out segment carries its own signature).

2. **Two ways to consume it:**
   - **Discrete structure** (which scene, which behavior) via a **SimHash bucket**: project the signature onto a fixed bank of
     random hyperplanes, take the signs, get a bit-bucket, then a seed. Only a few coarse bits are used so buckets are wide and
     re-encode or overlay rarely crosses a boundary. This snaps: same bucket is identical, a crossed boundary is unrelated.
   - **Continuous expression** (colors, rates, the dynamics within a scene) by feeding the raw signature vector into the
     scene's modulation. A perturbed signature gives a slightly perturbed look, not a different one.

   Robustness lives in wide buckets (the hash); the smooth part keeps the *character* (palette, motion energy) tracking the
   audio even when the discrete pick changes.

## Honestly graded

- **Re-encode (mp3<->wav, bitrate):** essentially identical; the signature barely moves.
- **Cut the song / rebuild a video:** each surviving segment reproduces its own visuals, because the seed is local content,
  not file-hash plus scene-index. A byte fingerprint cannot give this.
- **Speak over it / light mashup:** graceful. While the original's harmony dominates the window the show stays in the same
  buckets and palette; as the overlay takes over it drifts, correctly, since it is different content.
- **Hard limits:** a key transposition rotates chroma (a different show unless shift-invariance is added, e.g. CENS or the
  magnitude of chroma's DFT); time-stretch changes the window. Identical visuals cannot be forced from substantially different
  audio. The guarantee is monotonic: more harmonic similarity gives more visual similarity.

Ties to the harmonic-latent / Koopman framing: the signature is a point in harmonic-feature space, the show is a trajectory, and
neighborhoods in harmonic space map to neighborhoods in visual space.

## The chosen shape: a live `seed_bias`, not a replacement (Ryan's refinement)

Content-addressing and history are both used. Every existing seed (session identity, scene index, history/swaps) stays, and a
**`seed_bias`** is threaded through it: a value that would normally be a fixed constant is driven live by the harmonic channels.
The harmonics are a continuous steering signal layered onto the whole seeding fabric.

    scene_seed = session_seed ^ (index*A) ^ (swaps*B) ^ Spectrum.seed_bias()   // additive bias

Two consumption points for the same live signal:
- **Snapshotted into discrete seeds** at the instant a thing is instanced (a scene build reads `seed_bias()` once, at the cut).
  A value used as an RNG seed avalanches, so this is where the harmonics pick structure.
- **Read continuously** where things modulate every frame (`harmonic_signature()`, the channel vector). This is where graceful
  similarity lives.

## Status / where it lives

- `src/audio/harmonic_signature.gd` - `HarmonicSignature` (chroma + coarse shape, L2-norm, EMA; `vector()`, `bucket(bits)`,
  `seed()`). The hyperplane bank comes from a baked seed (global, reproducible).
- `src/audio/spectrum.gd` - builds it from band centres and updates it each analysed frame; exposes `harmonic_signature()`
  (continuous channel vector), `harmonic_bucket(bits)` and **`seed_bias()`** (the coarse bucket spread across the seed bits,
  for XOR-mixing).
- `src/show/director.gd` - the auto scene seed XORs in `Spectrum.seed_bias()` at each cut and prints the bucket as telemetry.

**Threaded so far:**
- Discrete / seed_bias: scene build seed (`_next_entry`), transition style (`_choose_style`), trigger arming (`_arm`), and the
  novelty scene pick (`_pick_index`, draw point rotated by a bias fraction). Director helpers `_biased(n)` (bag index) and
  `_bias_frac()` ([0,1)).
- Continuous / signature: `GhostScene.chroma_hue()` returns Vector2(tonal hue, strength) from the 12 chroma bins on the colour
  wheel. `harmonic_lattice` (each column maps to a pitch class that lights it, palette pulled toward the tonal hue) and `embers`
  (cloud tinted toward the tonal hue) use it, as do many other scenes in `src/scenes/`. `orbits` is wired but is not in the
  scene catalogue.

Caveat: live (variable fps) and export (fixed fps) can give slightly different EMA trajectories, so a bucket could flip at a cut.
Coarse buckets and smoothing keep this rare, but it is not bit-exact across the two paths.
