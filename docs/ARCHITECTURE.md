# Bounce Ascent architecture

Written for the version of me (or you) who picks this up in six months with no
memory of building it. It covers *why* things are shaped the way they are, since
the *what* is readable from the code.

---

## 1. The timing chain

Everything in this game hangs off one number: where we are in the song, in
seconds. Four layers turn that into gameplay.

```
AudioStreamPlayer (native, playing a pre-rendered AudioStreamWAV)
        |
        v
Music.get_audio_time()      raw position + latency corrections
        |
        v
Conductor                   seconds -> beats, bars, judgements
        |
        v
Player                      solves jump arcs against the beat grid
```

### Why the clock is read, never accumulated

The tempting implementation is to add `delta` every frame and call that the song
position. It drifts. Frame delta measures how long the *renderer* took; the
audio hardware runs on its own crystal, and the two disagree by a small but
relentless amount that compounds into obvious desync over a few minutes.

Reading the audio clock every frame means error never accumulates: each frame is
an independent absolute measurement.

### The three corrections

`Music.get_audio_time()` applies all of these, and the reasoning is worth
keeping because getting them wrong does not produce an obvious bug. It produces
a game that "feels off", which is far harder to diagnose.

| Term | Sign | Why |
|---|---|---|
| `get_playback_position()` | base | where the stream is |
| `AudioServer.get_time_since_last_mix()` | `+` | position only updates once per mix block, so it is stale by up to one block between mixes; this interpolates the gap |
| `AudioServer.get_output_latency()` | `-` | audio that has been mixed has not been *heard* yet; it is sitting in the driver buffer, and the player reacts to what they hear |
| `Settings.audio_offset_seconds()` | `-` | everything downstream of Godot: OS mixer, Bluetooth, TV audio processing. Godot cannot see any of this. Measured by the calibration screen |

The clock is also monotonic by construction (`_last_time = maxf(t, _last_time)`)
because a single backwards step would repeat a beat index and fire a duplicate
beat signal.

### `Conductor.now()` versus `Conductor.song_time`

`song_time` is refreshed once per rendered frame in `_process`. That is fine for
visuals and wrong for judgement, because neither timing-critical reader runs in
`_process`:

- input is sampled in `_unhandled_input`, which runs **before** `_process`, so
  `song_time` is a full frame stale there (16.7 ms at 60fps, a third of the
  PERFECT window, and worse on slower hardware);
- landings are detected in `_physics_process` at 120Hz, which can be ahead of
  the last `_process` update.

`Conductor.now()` samples `Music.get_audio_time()` on demand instead, which
decouples judgement accuracy from the render frame rate. Everything in
`player.gd` uses it; only visual pulsing uses the cached value.

### Physics must keep up

Arcs are solved against the audio clock but simulated in physics time. If
physics falls behind real time, landings arrive late, and because each hop is
re-solved from the audio clock the lag **compounds** rather than self-correcting.
A stalled run was observed drifting from 48 ms to 220 ms over 26 seconds.

`max_physics_steps_per_frame` is therefore raised to 24 (from the default 8),
which covers 200 ms of catch-up per frame at 120Hz instead of 67 ms. The
gameplay test measures the ratio of simulated to real time and explicitly skips
its timing assertions when the host failed to keep up, rather than reporting an
environment stall as a game regression.

Loop wraps are counted, not ignored: `get_playback_position()` resets to zero
each loop, so `_loop_count` is incremented on a large backwards jump and added
back on, giving a clock that only ever increases.

---

## 2. Beat-quantised jump arcs

### The problem

A rhythm game needs the player's timed action to matter. In a climber the
obvious timed action is the jump, but jumps are gated by *landing*, and landings
happen whenever physics says they do. If landings are arbitrary, so is the
rhythm.

### The solution

Invert the projectile equation. For displacement `rise` after time `t` under
gravity `g`:

```
rise = v0*t - 0.5*g*t^2      ->      v0 = (rise + 0.5*g*t^2) / t
```

Choose `t` first, as a whole number of beats. Then every landing is on a beat by
construction, and "press jump when you land" and "press jump on the beat" become
the same action.

### Refinement A: quantise the landing, not the launch

Firing the jump exactly on the beat breaks late presses: the launch has already
happened when the input arrives, so only early presses can ever score. The
window is effectively halved and the whole game biases toward pressing early.

Instead the launch fires on the press, and the *target landing time* is snapped
to the grid:

```
target = round((t_press / spb) + HOP_BEATS) * spb
flight = target - t_press
v0     = solve_launch_velocity(rise, flight, g)
```

`round` rather than `floor` is what makes early and late symmetric: a press 40ms
early and one 40ms late resolve to the same target beat, the late one simply
getting 80ms less flight time to reach it.

The consequence worth stating plainly: **no matter how badly the player times
their input, the game never desynchronises from the music.** Error is corrected
on every hop rather than accumulating.

This lives in `Tuning.quantise_landing_time()` as a pure static function
specifically so it can be tested without instantiating a scene.

### Refinement B: gravity derived from tempo

Gravity is free for *timing* (the solver compensates for any value) but not for
*geometry*. Because platforms are one-way, the apex decides which tiers a hop
can land on during descent:

- a normal one-tier hop must apex **below tier+2**, or a mistimed jump climbs
  two tiers by luck and PERFECT's reward is meaningless;
- a PERFECT two-tier hop must apex **comfortably above tier+2 but below
  tier+3**, or it either overshoots or arrives with no downward velocity (and
  one-way collision may not register at all).

With fixed gravity, `t` varies with tempo, so arc shape does too and the
invariants hold only by luck. Setting `g = GRAVITY_SHAPE / t^2` cancels `t`:

```
apex = (rise + GRAVITY_SHAPE/2)^2 / (2 * GRAVITY_SHAPE)
```

which is independent of tempo. At `GRAVITY_SHAPE = 1550` this yields a 300px
normal apex and a 430px PERFECT apex at 112, 128 and 150 BPM alike, against
floors of 380px and 570px.

`tests/smoke_test.gd::test_arc_tier_separation` asserts these bounds for every
song, so a future tempo or spacing change cannot silently break them.

---

## 3. Layout and reachability

Platforms sit on a strict tier grid, one per tier, `TIER_RISE` apart. That
regularity is required: irregular spacing would make flight time depend on where
the next platform happened to be, and the rhythm would collapse.

All variety is therefore horizontal, and difficulty comes from how far
consecutive platforms drift apart (`SPREAD_START` to `SPREAD_MAX`) plus
platforms narrowing with altitude.

**Reachability is free because of screen wrapping.** Since the player can cross
either edge, the greatest possible distance between two x positions is *half*
the playfield (360px), not the full 720. One hop covers roughly 536px including
acceleration from rest. 536 > 360, so every platform is reachable from every
other at every difficulty, and no spread constraint is needed.

This is load-bearing. With walls instead of wrapping, the maximum distance would
be 720px and late-game spawns at `SPREAD_MAX` would be genuinely impossible.

Platforms are pooled rather than freed. An endless climb would otherwise churn
thousands of nodes per run, and the resulting GC pauses are exactly the frame
hitches a rhythm game cannot afford.

---

## 4. The death line

A world-space y value that only ever rises, at a rate ramping from
`SCROLL_START` to `SCROLL_MAX` tiers per beat. Falling below it ends the run.

**It must be world-space, not camera-relative.** An earlier version computed it
as `camera_top + screen - accumulated_scroll`. Because the camera follows the
player, the line rose *with* the player and then had the scroll subtracted on
top, so the gap closed at a fixed rate regardless of climb speed. Every run died
at about ten seconds no matter how well it was played, and climbing faster, the
player's only defence, did nothing at all.

The difficulty curve is entirely contained in two numbers:

- ordinary play (GREAT/GOOD/MISS) climbs at **0.5 tiers/beat**
- PERFECT play climbs at **1.0 tiers/beat**
- the death line ramps from **0.18** to **0.62 tiers/beat**

Below 0.5 the line is survivable by timing merely well. Above it, only PERFECTs
keep you alive. `MAX_DEATH_LEAD` caps how far the line can trail behind so that
a strong player cannot build an unbounded, permanently safe lead.

---

## 5. Audio synthesis

### Offline, not live

`AudioStreamGenerator` looks like the natural fit for procedural music and is
the wrong tool here:

- a single frame hitch starves the ring buffer and clicks audibly;
- the playback clock must be reconstructed by counting pushed frames and
  subtracting the unplayed remainder, which is fiddly and easy to get subtly
  wrong;
- all mixing happens on the main thread, every frame, forever.

Rendering once into an `AudioStreamWAV` avoids all three. Playback is then plain
native streaming, so the standard `get_playback_position()` clock works exactly
as documented.

Cost is about 1.3s per song (measured, `tests/perf_probe.gd`), paid on a
background thread during the menu, then cached.

### Cache invalidation

The cache path embeds `JSON.stringify(song).hash()`, so any edit to a song
definition produces a different path and the stale render is ignored
automatically. Header magic and a length check reject truncated files from an
interrupted first launch, falling back to a re-render rather than playing noise.

### Determinism

Noise uses a seeded LCG rather than `randf()`, so a cached render and a fresh
render are bit-identical.

---

## 6. Conventions worth preserving

- **No assets.** Every visual is `_draw()` from Godot primitives. Keeps the
  export tiny, removes an import pipeline, and lets visuals read the Conductor
  directly rather than through a shader uniform that can lag by a frame.
- **UI built in code**, not authored in `.tscn`. Scene files full of anchor
  offsets are hard to read and easy to corrupt; a single script shows the whole
  layout at once.
- **Typed locals everywhere.** The project treats "inferred from Variant" as an
  error, so prefer `floorf`/`roundf`/`fposmod`/`absf` over the untyped globals
  `floor`/`round`/`fmod`/`abs`, which return Variant and will fail the build.
- **`Tuning` owns every feel constant.** Tuning the game should be a single-file
  activity, and pure static helpers there are directly testable.
- **Accessibility toggles are real.** `flash_effects` and `screen_shake` are
  checked at every use site. A rhythm game pulses the screen several times per
  second, which is a genuine problem for some players.
- **Audio responsibilities are split three ways.** `music.gd` owns buses,
  playback and the clock; `song_cache.gd` owns background rendering and the disk
  cache; `sfx_bank.gd` owns procedural one-shots. Keep it that way: the clock is
  the part that must stay easy to reason about, and it should not share a file
  with threading and file IO.
- **Comments carry what the code cannot say.** Density sits near a third of code
  lines; long-form reasoning belongs in this document instead. `tuning.gd` runs
  higher because it is almost entirely constants, where a bare number is
  meaningless without its "why".

---

## 7. Known characteristics

- Semi-implicit Euler at 120Hz lands about **4.2ms early** versus the analytic
  solution. It is a constant bias, well inside the +/-45ms PERFECT window, and
  the calibration offset absorbs it. Measured, not assumed
  (`test_launch_velocity_numeric`).
- Real in-game landings measure **-1.6ms mean, 10.9ms worst** across a 26s run.
- Headless Godot **does not exit on a parse error**; it idles forever. Always
  use `timeout`.

---

## 8. Obvious next steps

Not built, deliberately, since the brief was a working rhythm jumper:

- more songs (add entries to `SongLibrary.all_songs()`; nothing else changes)
- moving / breaking / one-shot platform variants on the same tier grid
- an in-run timing histogram on the results screen
- gamepad bindings (the input map already abstracts the actions)
- a Godot export preset and CI wiring for the two headless suites
