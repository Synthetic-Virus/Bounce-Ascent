class_name Tuning
extends RefCounted

## Every game-feel constant, plus the maths that ties jumping to the beat.
##
## Tuning the game should be a single-file activity, so nothing here belongs
## anywhere else. The reasoning behind the numbers is in docs/ARCHITECTURE.md.
##
## The core idea: flight time is chosen first, as a whole number of beats, and
## the launch velocity is solved to match. Landings therefore fall on beats by
## construction. See quantise_landing_time() and solve_launch_velocity().

# --- World geometry ---------------------------------------------------------

const PLAYFIELD_WIDTH: float = 720.0
const PLAYFIELD_HEIGHT: float = 1280.0

## Vertical distance between platform tiers.
const TIER_RISE: float = 190.0

const PLATFORM_HALF_WIDTH: float = 78.0

## Platforms are thin because they are one-way: the player passes up through
## them and only lands on the way down.
const PLATFORM_HALF_HEIGHT: float = 10.0

# --- Jump physics -----------------------------------------------------------

## Arc shape constant. Gravity is DERIVED from this as g = GRAVITY_SHAPE / t^2,
## which cancels t in the apex equation and makes arc shape independent of
## tempo. At 1550 a one-tier hop apexes at 300px and a PERFECT at 430px, at
## every BPM, against tier+2 and tier+3 floors of 380px and 570px.
##
## Those margins are load-bearing, not cosmetic: platforms are one-way, so the
## apex decides which tiers a hop can physically land on. Asserted for every
## song by smoke_test.gd::test_arc_tier_separation.
const GRAVITY_SHAPE: float = 1550.0

## Fallback gravity, used only before a song is bound to the Conductor. Equal to
## the derived value at 128 BPM.
const GRAVITY: float = 1763.0

## Beats per single-tier hop. Two beats reads as a jump; one is too fast to see.
const HOP_BEATS: float = 2.0

const MAX_FALL_SPEED: float = 2000.0

# --- Blob deformation -------------------------------------------------------
#
# The player reads as a soft body rather than a moving circle. Deformation is a
# single signed value driven by a damped spring: +1 is stretched tall and thin,
# -1 is squashed wide and flat.
#
# The spring matters more than the amounts. A linear decay looks like a sprite
# being scaled; a spring overshoots and settles, which is what the eye reads as
# something soft recovering its shape.

## Spring pull back toward round. Higher is snappier and more rubbery.
const BLOB_STIFFNESS: float = 340.0

## Velocity damping per second. Low enough to allow one visible wobble past
## centre, high enough that it settles well inside a single hop.
const BLOB_DAMPING: float = 11.0

## Impulse applied on touchdown (squash) and on launch (stretch).
const BLOB_LAND_SQUASH: float = -0.95
const BLOB_LAUNCH_STRETCH: float = 0.80

## Extra stretch from vertical speed, per pixel per second. Keeps the blob
## elongated while it is genuinely moving fast, which sells the weight of a fall.
const BLOB_VELOCITY_STRETCH: float = 0.00022

## Hard limit, so a pathological velocity cannot turn the player into a needle.
const BLOB_MAX_DEFORM: float = 0.62

# --- Horizontal steering ----------------------------------------------------

## One hop covers about 536px including acceleration from rest, comfortably more
## than the 360px maximum the player ever needs (wrapping halves the worst-case
## distance). Steering should never be what kills you; timing should.
const AIR_SPEED: float = 620.0
const AIR_ACCEL: float = 4200.0
const AIR_FRICTION: float = 2600.0

# --- Judgement --------------------------------------------------------------

## Declared here rather than on the Conductor so scripts can reference it
## without touching the audio subsystem, which matters for headless tests.
enum Judgement {
	PERFECT,
	GREAT,
	GOOD,
	MISS,
}

## Absolute error from the nearest beat, in seconds. Generous compared to a
## dedicated rhythm game because the player is steering at the same time:
## difficulty should come from the two-axis demand, not frame-perfect timing.
const WINDOW_PERFECT: float = 0.045
const WINDOW_GREAT: float = 0.090
const WINDOW_GOOD: float = 0.160

# --- Scoring ----------------------------------------------------------------

const SCORE_PERFECT: int = 300
const SCORE_GREAT: int = 200
const SCORE_GOOD: int = 100
const SCORE_MISS: int = 0

## Multiplier is 1 + floor(combo / COMBO_STEP), capped so a long run does not
## make the early game irrelevant.
const COMBO_STEP: int = 10
const COMBO_MAX_MULT: int = 8

## Tiers climbed by a PERFECT, in the SAME flight time as a normal hop. Double
## ascent rate is the skill reward; the flight time must not change or landings
## would stop falling on beats.
const PERFECT_TIER_SKIP: int = 2

# --- Difficulty -------------------------------------------------------------

## Horizontal drift between consecutive platforms, as a fraction of playfield
## width, at the start of a run and at full difficulty.
const SPREAD_START: float = 0.22
const SPREAD_MAX: float = 0.78

## Tiers climbed before the ramp reaches maximum.
const RAMP_TIERS: float = 240.0

# --- Platform types ---------------------------------------------------------

## Platform behaviours. NORMAL is always available; the rest unlock with height.
##
## All of them vary HORIZONTAL difficulty or availability only. None may change
## a platform's y, because tier spacing is what makes flight time solvable
## against the beat.
enum PlatformType {
	NORMAL,
	MOVING,     ## sways horizontally, in time with the music
	CRUMBLING,  ## collapses once you leave it, so it cannot rescue a fall
	PHASING,    ## solid for one bar, intangible the next
	SOLID,      ## blocks from every side; must be climbed around, not through
}

## Tier at which each type starts appearing.
const UNLOCK_MOVING: int = 12
const UNLOCK_CRUMBLING: int = 30
const UNLOCK_PHASING: int = 55

## SOLID blocks are the late-game shift, so they arrive last and then take over.
##
## Every other platform is ONE-WAY: the player passes up through it and lands on
## the way down. A solid block cannot be entered at all, and since the player
## always approaches from the tier below, it cannot be landed on by jumping at
## it. The move is to rise BESIDE it and slide over the top, which is why it
## belongs to the higher levels.
const UNLOCK_SOLID: int = 80

## Share of platforms that are SOLID, at unlock and at full difficulty. Above
## 0.5 it is the primary type, which is the requested late-game character.
const SOLID_SHARE_START: float = 0.12
const SOLID_SHARE_MAX: float = 0.68

## Minimum horizontal offset between a solid block and the platform below it.
##
## Load-bearing for fairness. If a solid block sat directly above the player's
## launch point they would rise into its underside with no way past. This forces
## enough clearance that the ascent passes beside it and the player can move
## over the top. One platform half-width plus the player's diameter.
const SOLID_MIN_OFFSET: float = PLATFORM_HALF_WIDTH + 56.0

## Chance of a special (non-NORMAL) platform, just after everything has
## unlocked and at full difficulty. Capped well below 1.0: a climb of nothing
## but hazards stops reading as a rhythm game and starts reading as noise.
const SPECIAL_CHANCE_START: float = 0.18
const SPECIAL_CHANCE_MAX: float = 0.62

## MOVING platforms sway on a sine tied to song position, so their motion is
## musical and predictable rather than arbitrary. Amplitude in pixels, at
## unlock and at full difficulty.
const MOVE_AMPLITUDE_START: float = 40.0
const MOVE_AMPLITUDE_MAX: float = 150.0

## Beats for one complete sway. Four keeps a full cycle to one bar, so the
## platform is back where it started every downbeat.
const MOVE_BEATS_PER_CYCLE: float = 4.0

## Beats a CRUMBLING platform survives after the player leaves it.
const CRUMBLE_BEATS: float = 0.75

## Bars in a PHASING platform's solid/intangible cycle. One bar solid then one
## intangible gives the player a full bar of warning, and a hop is two beats,
## so the state on arrival is always visible before committing.
const PHASE_BARS: float = 1.0

# --- Touch sizing -----------------------------------------------------------
#
# The viewport is 720 wide and scales to the device width, so viewport pixels
# are roughly 0.5x physical pixels on a 1440-wide phone and 0.67x on a 1080-wide
# one. A 88px viewport control is therefore about 9-11mm tall in the hand, above
# Apple's 44pt and Google's 48dp minimums with margin for a moving thumb.

## Minimum height for any tappable control.
const TOUCH_MIN: float = 88.0

## Track rows, which carry more text and are the main browsing target.
const TOUCH_ROW: float = 96.0

## Primary actions. Deliberately much larger than the minimum: on a phone the
## main action should be findable without looking.
const TOUCH_PRIMARY: float = 120.0

## Tilt steering. Accelerometer x beyond DEAD is full steer at TILT_FULL, so the
## player never has to tip the device further than a comfortable wrist angle.
const TILT_DEAD: float = 0.05
const TILT_FULL: float = 0.45

## On-screen steer pads, used when tilt is off. Bottom corners, large.
const PAD_SIZE: float = 150.0
const PAD_MARGIN: float = 24.0


# --- Camera and the death line ----------------------------------------------

## Player's screen position as a fraction of viewport height. Below centre,
## because seeing where you are going matters more than where you have been.
const CAMERA_ANCHOR: float = 0.62

## Catch-up rate as a fraction of remaining distance per second. Finite so a
## PERFECT reads as the player surging upward rather than the world lurching.
const CAMERA_LERP: float = 7.0

## Where the death line starts, in screen heights below the player.
const DEATH_LINE: float = 1.02

## The furthest the death line may ever trail behind the player.
##
## MUST stay close to 1 - CAMERA_ANCHOR (0.38), which is how much screen is
## visible below the player. At 0.45 the line sits just past the bottom edge, so
## falling off the screen kills you, which is the rule this genre trains players
## to expect.
##
## Was 1.2, which put the line 1050px below the visible area with 5.5 tiers of
## platforms in the gap. Since one-way platforms catch a falling player from
## above, you were rescued almost every time and the game had no fail condition
## at all. The value has two jobs (cap a strong player's lead, and decide how far
## you fall before dying) and only the first was considered.
const MAX_DEATH_LEAD: float = 0.45

## Death line rise rate in tiers per beat, start and maximum.
##
## The ordering is the entire difficulty curve: ordinary play climbs at 0.5
## tiers/beat and PERFECT play at 1.0, so 0.18 is survivable by timing merely
## well and 0.62 is not. Asserted by smoke_test.gd::test_difficulty_curve.
const SCROLL_START: float = 0.18
const SCROLL_MAX: float = 0.62

# --- Maths ------------------------------------------------------------------

static func sec_per_beat(bpm: float) -> float:
	return 60.0 / bpm


## Gravity for a nominal flight time. Pass the same flight time used to solve
## the launch velocity, or the arc will not close on the beat.
static func gravity_for_flight(flight_time: float) -> float:
	if flight_time <= 0.0:
		return GRAVITY
	return GRAVITY_SHAPE / (flight_time * flight_time)


static func gravity_for_tempo(
	seconds_per_beat: float, hop_beats: float = HOP_BEATS
) -> float:
	return gravity_for_flight(hop_beats * seconds_per_beat)


## Launch velocity (positive = up) that gains exactly `rise` pixels in exactly
## `flight_time` seconds. The inverse of the usual projectile setup, and what
## makes landings fall on beats.
##
## `gravity` is explicit rather than read from a constant because it must match
## what the simulation actually applies; a mismatch puts every landing off the
## beat by a fixed amount.
## The timestep the arcs are actually simulated at.
##
## Not a constant, because project.godot owns the tick rate and two copies of
## that number would eventually disagree.
static func physics_step() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)


## Launch velocity that lands `rise` pixels up after exactly `flight_time`.
##
## SOLVED AGAINST THE DISCRETE INTEGRATOR, not the continuous equation, which is
## what removes the landing bias.
##
## The textbook answer is (rise + g*t^2/2) / t. That is correct for continuous
## motion and slightly wrong for a game, because Godot integrates with
## semi-implicit Euler at a fixed step h:
##
##     v <- v - g*h          then     y <- y + v*h        (NEW v, not the old)
##
## Summing n = t/h of those gives y_n = n*h*v0 - g*h^2*n(n+1)/2, whereas the
## continuous curve gives v0*t - g*t^2/2. Subtracting, the simulated arc sits a
## constant
##
##     g*h*t/2
##
## BELOW the ideal one at every t. On the way down, being low means crossing the
## landing height early, so every landing arrives slightly ahead of its beat.
##
## At 128 BPM that is 6.9px of shortfall against a 624px/s descent, i.e. 11ms
## early, which is exactly the bias gameplay_test.gd was measuring. It was
## always a systematic offset rather than noise, which is why no amount of
## smoothing would have removed it.
##
## Carrying the h term through the algebra gives the discrete solution:
##
##     v0 = (rise + g*t*(t + h) / 2) / t
##
## i.e. the same formula with t^2 replaced by t*(t+h). One extra term, derived
## rather than tuned, so it stays correct if the tick rate ever changes.
static func solve_launch_velocity(
	rise: float, flight_time: float, gravity: float = GRAVITY,
	step: float = -1.0
) -> float:
	if flight_time <= 0.0:
		push_error("Tuning.solve_launch_velocity: flight_time must be positive")
		return 0.0
	var h := physics_step() if step < 0.0 else step
	return (rise + 0.5 * gravity * flight_time * (flight_time + h)) / flight_time


static func apex_height(launch_velocity: float, gravity: float = GRAVITY) -> float:
	return (launch_velocity * launch_velocity) / (2.0 * gravity)


## Time of the grid beat nearest one nominal hop after `from`.
##
## Rounding (not flooring) is what makes early and late presses symmetric: a
## press 40ms early and one 40ms late resolve to the same target beat, the late
## one simply getting 80ms less flight. Timing error therefore self-corrects
## every hop instead of accumulating.
static func quantise_landing_time(
	from: float, seconds_per_beat: float, hop_beats: float = HOP_BEATS
) -> float:
	if seconds_per_beat <= 0.0:
		push_error("Tuning.quantise_landing_time: seconds_per_beat must be positive")
		return from
	return roundf(from / seconds_per_beat + hop_beats) * seconds_per_beat


static func score_for(judgement: int) -> int:
	match judgement:
		Judgement.PERFECT: return SCORE_PERFECT
		Judgement.GREAT: return SCORE_GREAT
		Judgement.GOOD: return SCORE_GOOD
		_: return SCORE_MISS


static func judgement_label(judgement: int) -> String:
	match judgement:
		Judgement.PERFECT: return "PERFECT"
		Judgement.GREAT: return "GREAT"
		Judgement.GOOD: return "GOOD"
		_: return "MISS"


static func judgement_color(judgement: int) -> Color:
	match judgement:
		Judgement.PERFECT: return Color(1.0, 0.92, 0.30)
		Judgement.GREAT: return Color(0.36, 1.0, 0.85)
		Judgement.GOOD: return Color(0.60, 0.72, 1.0)
		_: return Color(1.0, 0.32, 0.45)
