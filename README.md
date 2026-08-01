# Bounce Ascent

A beat-synced vertical climb, built in Godot 4.7 with GDScript.

This is a **complete ground-up rebuild**. The original 2025 build was a Doodle
Jump clone with no rhythm mechanics of any kind: no beat clock, no timing
windows, no music. None of that code survives, and none of it was available to
salvage anyway (the source was lost with the machine it was written on; only the
shipped `.exe` remained).

---

## The one idea everything rests on

In an ordinary jumping game you pick a jump velocity and the flight time falls
out of the physics. This game does the opposite: it picks the **flight time
first**, as an exact multiple of the beat interval, then solves for the launch
velocity that lands you on the next platform at exactly that moment.

```
v0 = (rise + 0.5*g*t^2) / t        where t is a whole number of beats
```

Because every landing is engineered to occur on a beat, the player's natural
instinct (*press jump the moment I touch down*) **is** pressing on the beat. The
rhythm is not decoration layered over the movement; it is a property of the
movement.

Two refinements make it hold up in practice:

- **The landing is quantised, not the launch.** If the jump fired exactly on the
  beat, a player pressing 40ms late could never be rewarded, because they would
  already have launched. Instead the launch happens whenever they press, and the
  arc is solved so that the *landing* falls on the grid. A late press gets a
  slightly shorter flight, an early press a slightly longer one, and both touch
  down on the beat. Timing error self-corrects every hop instead of accumulating.
- **Gravity is derived from tempo**, as `g = GRAVITY_SHAPE / t^2`. This makes the
  `t` terms cancel in the apex equation, so arc *shape* is identical at every
  BPM and only the speed changes.

Verified, not assumed: `tests/smoke_test.gd` simulates 400 hops at three tempos
with the player mistiming every single press, and measures **0.0000 ms** of
drift. `tests/gameplay_test.gd` then measures real physics-resolved landings in
the running game, across repeated runs, at **within +/-3 ms mean and under 18 ms
worst**, with hop cadence landing on 1.072s against a 1.071s target.

---

## Running it

The project lives on the Windows filesystem (not WSL) because the Godot editor
runs on Windows and reading a project over `\\wsl.localhost` is slow and flaky.

```
C:\Users\aalex\bounce-ascent
```

Open `project.godot` in **Godot 4.7** (the Mono build in `Downloads` works; the
project itself is pure GDScript and does not need C#).

Press F5 to run. `scenes/Game.tscn` is also safe to run directly with F6,
because it waits for audio synthesis rather than erroring.

### Controls

| Input | Action |
|---|---|
| `SPACE` / `W` / `UP` / left click | jump, and **time this to the beat** |
| `A` `D` / `LEFT` `RIGHT` | steer horizontally (in the air only) |
| `ESC` | pause / back |
| `R` | restart |
| `C` (menu) | audio calibration |
| `F` / `K` (menu) | toggle flash effects / screen shake |

Steering is deliberately disabled while you are standing on a platform. Holding
a direction to line up your next platform is the natural thing to do, and if
grounded input moved you, you would simply walk off the edge and die.

---

## Scoring

| Judgement | Window | Base points | Effect |
|---|---|---|---|
| PERFECT | +/-45 ms | 300 | **climbs two tiers**, combo +1 |
| GREAT | +/-90 ms | 200 | climbs one tier, combo +1 |
| GOOD | +/-160 ms | 100 | climbs one tier, combo +1 |
| MISS | beyond | 0 | climbs one tier, combo reset |

The multiplier is `1 + floor(combo / 10)`, capped at x8.

A PERFECT climbs two tiers **in the same flight time** as a normal hop, i.e.
double the ascent rate. That is the whole skill expression, because a death line
rises through the world from below at a rate that ramps from 0.18 to 0.62 tiers
per beat. Ordinary play climbs at 0.5 tiers/beat, so late in a run, timing
merely *well* stops being enough and you have to start landing PERFECTs to
survive.

**Falling below the death line ends the run.** It is drawn as a glowing hazard
band and sits just past the bottom of the view, so falling off the screen kills
you. It climbs into frame as the run gets harder, which is the only warning you
get that it is catching up.

## Platform types

Types unlock with height and grow more frequent, so the climb gets harder in
kind as well as in degree. Colour tells you which is which at a glance, because
you have to read it while airborne.

| Type | Colour | From tier | Behaviour |
|---|---|---|---|
| Plain | cyan | 0 | nothing special |
| Moving | amber | 12 | sways horizontally, one full cycle per bar |
| Crumbling | red | 30 | collapses shortly after you leave, so it cannot catch you on the way back down |
| Phasing | violet | 55 | solid for one bar, intangible the next; it fades out so you can see the change coming |

Two fairness rules: tiers 0 and 1 are always plain, and two special platforms
never spawn back to back, since consecutive hazards can demand a route that is
not reachable in one hop. Plain platforms stay the majority at every height
(capped at 62% special), because a climb of nothing but hazards stops reading as
a rhythm game.

Every type varies horizontal difficulty or availability only. **None of them
changes a platform's y**, because fixed tier spacing is what makes flight time
solvable against the beat.

---

## Audio

There are no audio assets. All three tracks are **synthesised from note tables
at runtime** by `scripts/audio/synth.gd`, rendered once on a background thread
during the menu (about 2s per song) and cached to `user://cache/`. Subsequent
launches load instantly.

The cache key combines a hash of the song definition with
`Synth.RENDER_VERSION`, so editing a melody in `song_library.gd` invalidates the
stale render automatically. **If you change the synthesis maths in `synth.gd`,
bump `RENDER_VERSION`** or every cached render stays stale forever and your
change will appear to do nothing. That is the one piece of manual bookkeeping in
the audio pipeline.

**Calibrate first.** Press `C` on the menu and tap sixteen times to the kick
drum. Audio latency varies by more than 200 ms between wired headphones and a
Bluetooth soundbar, far wider than the +/-45 ms PERFECT window, so without
calibration a player on high-latency output cannot score well no matter how good
their timing is.

---

## Project layout

```
autoload/
  settings.gd      persisted settings; audio_offset_ms is the important one
  music.gd         buses, playback, THE AUDIO CLOCK
  conductor.gd     audio time -> beats, bars, and timing judgements
  scores.gd        per-song high score tables
scripts/
  tuning.gd        every game-feel constant, plus the quantisation maths
  player.gd        beat-quantised jump arcs, input buffering, judgement
  platform.gd      one-way neon platform
  platform_spawner.gd  endless tier grid with pooling
  game_camera.gd   follow-up-only camera and the rising death line
  game.gd          run lifecycle and scoring
  game_ui.gd       HUD (built in code)
  game_over.gd     results overlay
  main_menu.gd     song select, settings
  calibration.gd   audio latency measurement
  beat_background.gd   reactive synthwave backdrop
  death_zone.gd    the visible rising hazard
  audio/
    synth.gd       offline chiptune synthesiser
    song_cache.gd  background rendering + disk cache
    sfx_bank.gd    procedural one-shots
    song_library.gd  three songs built from pattern primitives
tests/
  smoke_test.gd    pure logic, synthesis, audio pipeline, difficulty curve
  ui_test.gd       widget layout, pause lifecycle, focus loss
  gameplay_test.gd end-to-end: does the assembled game land on beats?
  perf_probe.gd    dev tool: measure synthesis cost
```

No texture or audio assets, by design. Every visual is drawn in code from Godot
primitives, which keeps the export tiny and lets everything react to the beat
directly rather than through animation clips.

---

## Tests

All three suites run headless and exit non-zero on failure.

```bash
GODOT="/mnt/c/Users/aalex/Downloads/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe"
PROJ="C:\\Users\\aalex\\bounce-ascent"

timeout 170 "$GODOT" --headless --path "$PROJ" res://tests/SmokeTest.tscn;    echo "rc=$?"
timeout 150 "$GODOT" --headless --path "$PROJ" res://tests/UITest.tscn;       echo "rc=$?"
timeout 190 "$GODOT" --headless --path "$PROJ" res://tests/GameplayTest.tscn; echo "rc=$?"
```

`UITest` is worth calling out. Godot computes Control layout in headless mode
even though it renders nothing, so "is this widget actually on screen" is
answerable by assertion rather than by squinting at a screenshot. It caught a
label sitting 500px off the right edge of the viewport, invisible in game, with
no error reported anywhere. It also covers the pause lifecycle including focus
loss.

## Building

Export templates are not in the repo (1.2GB). Install them once, then:

```bash
timeout 400 "$GODOT" --headless --path "$PROJ" \
  --export-release "Windows Desktop" "C:\\Users\\aalex\\bounce-ascent\\build\\BounceAscent.exe"
```

`export_presets.cfg` is checked in deliberately. It embeds the PCK into a single
`.exe` and excludes `tests/` and `docs/` from the shipped build.

> **Always wrap headless Godot in `timeout`.** If a script fails to parse, Godot
> does not exit. It sits idle forever with the failed scene. During development
> this looked exactly like "synthesis is slow" and burned a nine minute run
> before the real cause (a parse error) surfaced. It also means a CI job without
> a timeout will hang rather than fail.

There are no mocked subsystems. The tests exercise the real synthesiser, the
real Conductor, the real autoloads and the real physics. A mocked synthesiser
would only confirm that the mock returns what it was told to, and the entire
question is whether the real one produces audible, correctly timed audio.

---

## Bugs the tests caught during the build

Recording these because each was invisible to inspection and only surfaced by
measurement.

1. **Half-speed cadence.** The fallback jump was scheduled a full hop after
   landing, so the player rested two beats and then flew two more: four beats
   per tier instead of two. Half the game was spent standing still, and it
   silently invalidated the death-line tuning.
2. **Arc far too tall.** `GRAVITY = 2200` gave a 417px apex for a 190px hop, so
   an ordinary MISS could reach tier+2 by luck. That made PERFECT's two-tier
   climb, the game's only skill reward, something bad players got for free.
3. **Tempo-dependent arc shape.** A fixed gravity left a PERFECT at 150 BPM with
   3px of margin over its target, arriving with near-zero downward velocity
   where one-way collision may not register at all.
4. **The death line was unbeatable.** It was computed relative to the camera,
   which follows the player, so it rose *with* the player and then had the
   forced scroll added on top. The gap closed at a fixed rate regardless of
   climb speed, and every run died at about 10s no matter how well it was
   played.
5. **Walking off platforms.** Grounded steering slid the player off the edge to
   their death, punishing the most natural possible instinct.
6. **The pause screen soft-locked the game.** `get_tree().paused` stops PAUSABLE
   nodes receiving input, and `Game` owns the pause key. So ESC paused and then
   the node stopped listening: no way out but Alt+F4. `Game.process_mode` is now
   `PROCESS_MODE_ALWAYS`. Missed at first because the test called
   `_toggle_pause()` directly, which cannot see it. The test now fires real
   `InputEventAction`s, which is the only way this class of bug is visible.
7. **No pause on focus loss.** Alt-tabbing left the run going: the death line
   kept rising and the auto-launch kept firing, so you came back dead. Fatal in
   a rhythm game and completely invisible in testing until someone asked.
8. **A HUD label rendered off screen.** `_height_label` used
   `PRESET_TOP_RIGHT` *and* an absolute position, which makes the position an
   offset from the right edge: it sat 500px past the viewport, invisible, with
   no error. Anchor presets and absolute coordinates do not mix.
9. **The track name never displayed.** It was written into the score label,
   which `_process` overwrote with the score on the very next frame.
10. **Landing detection ignored the surface normal.** The comment claimed only
   top-surface contacts counted; the code accepted any contact with a platform,
   so a glancing side hit could reassign `current_tier`.
11. **The audio cache could not see synthesiser changes.** The key hashed the
    song definition only, so editing `synth.gd` left every cached render stale
    forever and the change appeared to do nothing. `Synth.RENDER_VERSION` is now
    part of the key, and must be bumped when the synthesis maths changes.
12. **The game had no working fail condition.** `MAX_DEATH_LEAD` was 1.2 screen
    heights while only 0.38 screens are visible below the player, putting the
    death line 1050px off screen with 5.5 tiers of one-way platforms in the gap
    that caught a falling player almost every time. The constant has two jobs
    (cap a strong player's lead, and decide how far you fall before dying) and
    only the first was considered. Now 0.45, and the line is drawn.
13. **Judgement read a stale clock.** `Conductor.song_time` refreshes in
   `_process`, but input is sampled in `_unhandled_input`, which runs *before*
   `_process`. Every press was judged against a value up to a full frame old:
   16.7 ms at 60fps, a third of the PERFECT window, and worse on a slow machine.
   `Conductor.now()` samples the audio clock fresh and decouples judgement
   accuracy from frame rate entirely.

### What the tests assert, and what they only report

Worth knowing before trusting a red result. The gameplay test drives the game
with a crude bang-bang steering robot, which occasionally misses a platform in a
way a human would not. So it **asserts** only what does not depend on the
robot's competence: hop cadence, beat alignment on successful hops, that
landings and judgements occur, and that the host actually simulated physics at
real time. Survival and tier reached are **reported only**, because the robot's
failure distribution overlaps the signature of the death-line bug and a
threshold there could not tell the two apart without failing roughly a third of
the time for no reason.

The difficulty curve is instead asserted deterministically from constants in
`smoke_test.gd::test_difficulty_curve`, which is exact and never flaky:
`SCROLL_START < 0.5 < SCROLL_MAX < 1.0`, i.e. the opening is survivable by
ordinary timing, the late game demands PERFECTs, and perfect play always
outruns the line.

Landings that end a *fall* are excluded from the beat-alignment measurement.
A fall is a free fall rather than a solved arc, so it is unquantised by nature;
counting it as a rhythm failure would measure the wrong thing. The quantiser
snaps the following launch back onto the grid, so a fall costs one landing of
alignment rather than causing accumulating drift.

See `docs/ARCHITECTURE.md` for the reasoning behind the current design.
