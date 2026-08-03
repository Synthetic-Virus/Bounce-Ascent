extends CharacterBody2D

## The player. Climbs by bouncing between platforms.
##
## The launch fires whenever the player presses; what is quantised is the
## LANDING. Given a press at time t, the arc is solved to touch down on the grid
## beat nearest one nominal hop later. A late press gets a shorter flight, an
## early press a longer one, and both land on the beat, so timing error is
## corrected every hop instead of accumulating.
##
## Firing the jump exactly on the beat instead would make late presses
## unrewardable, halving the effective window. See docs/ARCHITECTURE.md.

signal jumped(judgement: int, error: float, tiers: int)
signal landed(platform: Node2D)

## Emitted when an upward arc is stopped by a solid block. The hop is ruined:
## the player will now fall early and off the beat, so listeners that measure
## timing should discard the landing that follows.
signal bonked
signal died

const RADIUS: float = 22.0

## Standard platformer input buffering and coyote time. Coyote is kept small
## because a large value would let the player rescue a genuine horizontal miss,
## which is the game's only fail condition.
const INPUT_BUFFER: float = 0.22
const COYOTE_TIME: float = 0.08

## Bounds on the solved flight time, guarding against a pathological clock
## reading producing an absurd launch velocity.
const FLIGHT_MIN_SCALE: float = 0.45
const FLIGHT_MAX_SCALE: float = 1.60

var active: bool = false

## Set by Game each frame. Below this world y, the player is dead.
var death_y: float = INF

## Tier currently stood on. The spawner and HUD key off this.
var current_tier: int = 0

## All times here are song time, not wall clock, so pausing the music cannot
## silently expire a buffered input.
var _press_time: float = -1.0
var _press_expiry: float = 0.0
var _left_ground_at: float = -999.0
var _auto_jump_at: float = INF
var _grounded: bool = false

var _flash: float = 0.0
var _flash_color: Color = Color.WHITE

## Soft-body deformation, driven by a damped spring. Positive is stretched tall
## and thin, negative is squashed wide and flat. See Tuning.BLOB_STIFFNESS.
var _deform: float = 0.0
var _deform_vel: float = 0.0

## Gravity for the hop currently in flight, derived from that hop's ACTUAL
## solved flight time. See _launch().
var _hop_gravity: float = Tuning.GRAVITY

# --- Launch diagnostics -----------------------------------------------------
#
# Written once per hop, read only by tests. Four assignments per launch, so the
# cost is not worth guarding behind a flag.
#
# These exist because an arc is SOLVED in audio time and SIMULATED in physics
# time, and those are two different clocks. When a landing misses its beat, the
# only way to tell which of the two was wrong is to record both at the launch
# and compare them at the touchdown. Reconstructing the values afterwards would
# mean re-reading the very clock under suspicion.

## Song time the hop was solved from.
var last_launch_time: float = 0.0

## Wall clock at the same instant, in microseconds. Independent of the audio
## clock ON PURPOSE: it is the reference the audio clock is checked against.
var last_launch_usec: int = 0

## Flight time the solver asked for, in seconds.
var last_flight_solved: float = 0.0

## World y at launch, and the rise the arc was solved for. A hop that starts
## above where the solver thinks it does arrives early with a perfect clock.
var last_launch_y: float = 0.0
var last_launch_rise: float = 0.0

## Vertical speed going INTO the last landing, sampled before move_and_slide.
##
## Screen y grows downward, so a legitimate landing is positive (descending).
## NEGATIVE means the floor caught a body that was still going up, which is the
## signature of the snag being chased: a hop that ends a fifth of the way through
## its arc, embedded a few pixels in a platform it should have passed through.
##
## Sampled before the move because the move destroys it: move_and_slide cancels
## the velocity component into the floor, so by the time _on_land runs this reads
## 0.0 on every landing and answers nothing. That was the first attempt.
var last_land_vy: float = 0.0

## Physics frames spent airborne before the last landing. Counted rather than
## derived from the clock, because it is the count of integration steps that
## decides where the arc actually got to, and comparing it against the solved
## flight in steps is exact where comparing seconds is not.
var last_land_frames: int = 0
var _airborne_frames: int = 0

## Illegitimate floor contacts caught and undone, and any that got through.
##
## The first is DIAGNOSTIC and a non-zero value is fine: it counts how often the
## engine resolved an ascending body as standing on a one-way platform, which is
## the underlying engine behaviour and is not going away. The guard below undoes
## each one.
##
## The second MUST be zero. It counts contacts that reached _on_land while the
## player was still rising, which is the bug itself: a hop ending a fifth of the
## way through its arc, far off the beat, for a reason the player cannot see.
##
## Counted rather than hunted. The event is rare, roughly one hop in twenty five,
## and it defeated two hand-built probes across 237 controlled launches, one of
## which scored the failure as a pass because its detector looked for the body
## being stopped at the platform's UNDERSIDE when the snag happens at its TOP.
## A counter asserted by the gameplay test makes every run a hunt.
var rising_contacts_rejected: int = 0
var rising_landings: int = 0

## How fast upward a contact has to be before it is treated as illegitimate.
##
## Not zero. A body within a few pixels per second of its apex is genuinely
## settling onto a surface, and rejecting those would fight ordinary landings at
## the top of an arc. 40 px/s is five pixels a second at 120Hz, well under any
## real ascent and well over apex noise.
const RISING_LANDING_LIMIT: float = -40.0

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	_shape.shape = circle
	collision_layer = 1
	collision_mask = 2


func reset(start_position: Vector2) -> void:
	global_position = start_position
	velocity = Vector2.ZERO
	current_tier = 0
	# MUST be cleared. death_y is only refreshed by Game while the run is
	# PLAYING, so without this a restart inherits the PREVIOUS run's death line,
	# which after any real climb sits far above the fresh spawn point. The first
	# physics tick after the count-in then kills the player instantly.
	death_y = INF
	_press_time = -1.0
	_grounded = false
	_left_ground_at = -999.0
	_auto_jump_at = INF
	rising_landings = 0
	rising_contacts_rejected = 0
	_airborne_frames = 0
	_flash = 0.0
	_deform = 0.0
	_deform_vel = 0.0
	_hop_gravity = _current_gravity()
	active = true


## Arm the first jump, called by Game the instant the count-in ends (which is
## itself on a beat). Without it the run would open with an unquantised free
## fall and spend several hops correcting.
func arm_first_jump() -> void:
	_grounded = true
	velocity = Vector2.ZERO
	_hop_gravity = _current_gravity()
	_auto_jump_at = Conductor.now() + Tuning.WINDOW_GOOD


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("jump"):
		# The press time is what gets judged, so it must be the moment of input,
		# not the moment the jump is allowed to fire.
		_press_time = Conductor.now()
		_press_expiry = _press_time + INPUT_BUFFER
		_try_jump()


func _physics_process(delta: float) -> void:
	if not active:
		return

	if _press_time >= 0.0 and Conductor.now() > _press_expiry:
		_press_time = -1.0

	# A player who never presses still launches, on the grid, so inaction never
	# breaks the rhythm.
	if _grounded and Conductor.now() >= _auto_jump_at:
		_launch(Tuning.Judgement.MISS, 0.0, 1)

	velocity.y += _hop_gravity * delta
	velocity.y = minf(velocity.y, Tuning.MAX_FALL_SPEED)

	_apply_horizontal(delta)

	var was_grounded := _grounded
	# SAMPLED BEFORE THE MOVE, both of them, because the move destroys both.
	#
	# move_and_slide resolves the collision and cancels the velocity component
	# into the floor, so reading velocity.y inside _on_land reports 0.0 on every
	# landing and says nothing about which way the body was travelling. The
	# airborne count has the same problem in reverse: it is reset below, before
	# _on_land is reached.
	var vy_before_move := velocity.y
	var frames_before_move := _airborne_frames

	move_and_slide()
	_grounded = is_on_floor()

	# REJECT A FLOOR CONTACT THAT HAPPENED WHILE THE PLAYER WAS RISING.
	#
	# One-way platforms exist so an ascending body passes through them; that is
	# the whole contract, and it is what lets a PERFECT climb two tiers through
	# the platform in between. It fails at the top edge. A body whose CENTRE has
	# just crossed the platform's upper surface while its lower half is still
	# below can be resolved as standing on it, and the hop ends a fifth of the
	# way through its arc, far off the beat, for a reason the player cannot see.
	#
	# Measured, not guessed: caught at -737 px/s, 22 frames into a hop, 182.9px
	# above the launch point. The surface sits at 168 and the body's radius is 22,
	# so its centre was 15px clear of the surface while its bottom was still 7px
	# under it. In the same run the worst landing was 132.7ms off the beat, and
	# runs without a rising landing had no such outlier.
	#
	# Undone here rather than tuned away in the collision shape. one_way_collision
	# _margin controls how thick the catch region is, so shrinking it would trade
	# this bug for fast falling bodies passing straight through a platform, which
	# is worse. The rule above is exact: an ascending body must not be stopped by
	# a one-way surface, so if it was, put the ascent back.
	#
	# SOLID blocks are excluded, because for them it is legitimate. They cannot be
	# entered at all and the intended play is to rise BESIDE one and slide over
	# the top, which lands while still moving upward.
	if _grounded and not was_grounded and vy_before_move < RISING_LANDING_LIMIT:
		var caught := _current_platform()
		if caught != null and caught.type != Tuning.PlatformType.SOLID:
			rising_contacts_rejected += 1
			_grounded = false
			# Restore the ascent the contact cancelled. move_and_slide has already
			# nudged the body a few pixels, which is a small position error; the
			# alternative is losing 130ms of the hop.
			velocity.y = vy_before_move

	_airborne_frames = 0 if _grounded else _airborne_frames + 1

	# Hitting the underside of a solid block. Kill the remaining upward speed
	# rather than letting the body scrape along it, so the fall starts cleanly.
	if is_on_ceiling() and velocity.y < 0.0:
		velocity.y = 0.0
		_deform = Tuning.BLOB_LAND_SQUASH * 0.6
		_deform_vel = 0.0
		_flash = 1.0
		_flash_color = Tuning.judgement_color(Tuning.Judgement.MISS)
		bonked.emit()

	if _grounded and not was_grounded:
		last_land_vy = vy_before_move
		last_land_frames = frames_before_move
		if vy_before_move < RISING_LANDING_LIMIT:
			# Reached _on_land while still going up, so the guard above did not
			# catch it. Loud, because this is the bug and it is hard to see.
			rising_landings += 1
			push_warning(("Player LANDED while rising at %.0f px/s, %d frames into"
				+ " the hop, %.1f px above the launch point.")
				% [vy_before_move, frames_before_move,
					last_launch_y - global_position.y])
		_on_land()
	elif was_grounded and not _grounded:
		_left_ground_at = Conductor.now()

	_wrap_horizontally()

	if global_position.y > death_y:
		active = false
		died.emit()

	_flash = maxf(_flash - delta * 4.0, 0.0)
	_update_deform(delta)
	queue_redraw()


## Steering applies only while airborne.
##
## Deliberate: holding a direction to line up the next platform is the natural
## instinct, and if grounded input moved the player they would walk off the edge
## and die. A full hop gives far more horizontal travel than is ever needed.
func _apply_horizontal(delta: float) -> void:
	if _grounded:
		velocity.x = move_toward(velocity.x, 0.0, Tuning.AIR_FRICTION * 3.0 * delta)
		return

	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) > 0.01:
		velocity.x = move_toward(velocity.x, dir * Tuning.AIR_SPEED,
			Tuning.AIR_ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, Tuning.AIR_FRICTION * delta)


## Wrap rather than wall. With the spread ramping up, the shortest route to the
## next platform is sometimes around the edge, and wrapping halves the greatest
## possible distance between two platforms.
func _wrap_horizontally() -> void:
	var w := Tuning.PLAYFIELD_WIDTH
	if global_position.x < -RADIUS:
		global_position.x += w + RADIUS * 2.0
	elif global_position.x > w + RADIUS:
		global_position.x -= w + RADIUS * 2.0


func _on_land() -> void:
	velocity.y = 0.0
	_deform = Tuning.BLOB_LAND_SQUASH
	_deform_vel = 0.0

	var platform := _current_platform()
	if platform != null:
		current_tier = platform.tier
		platform.on_landed()
	landed.emit(platform)

	# A short grace, NOT a full hop: landings are already on a beat, so the next
	# press is due immediately. The grace only lets a slightly late press
	# register before the automatic launch pre-empts it.
	_auto_jump_at = Conductor.now() + Tuning.WINDOW_GOOD

	_try_jump()


func _try_jump() -> void:
	if not active or _press_time < 0.0:
		return

	var can_jump := _grounded \
		or (Conductor.now() - _left_ground_at) <= COYOTE_TIME
	if not can_jump:
		return

	var result := Conductor.judge(_press_time)
	var judgement: int = result["judgement"]
	var tiers: int = Tuning.PERFECT_TIER_SKIP \
		if judgement == Tuning.Judgement.PERFECT else 1

	_launch(judgement, result["error"], tiers)
	_press_time = -1.0


func _launch(judgement: int, error: float, tiers: int) -> void:
	var now := Conductor.now()

	# Solved in SONG seconds: the target is a beat, and beats live on the music's
	# clock.
	var flight_song := Tuning.quantise_landing_time(now, Conductor.sec_per_beat) - now
	var nominal := Tuning.HOP_BEATS * Conductor.sec_per_beat
	flight_song = clampf(flight_song,
		nominal * FLIGHT_MIN_SCALE, nominal * FLIGHT_MAX_SCALE)

	# Simulated in REAL seconds, so it has to be converted before it is used.
	#
	# This one line is the whole beat lock. The arc below runs on the physics
	# clock, and the beat it is aimed at arrives on the audio clock. Handing a
	# song-time duration straight to a real-time simulation silently assumes the
	# two run at the same speed, and they do not: measured at 8.6% apart on the
	# test host, which put EVERY landing 85ms early against a 25ms tolerance and
	# looked for a long time like a frame-rate problem, because the error was
	# large, the frames were all healthy, and nothing in the game reported that
	# the two clocks disagreed.
	#
	# When the clocks do agree the conversion is a no-op, so this costs nothing
	# on hardware that behaves.
	var flight := Conductor.song_to_real(flight_song)

	# Gravity is derived from THIS hop's flight time, not the nominal one.
	#
	# g = GRAVITY_SHAPE / t^2 makes the apex independent of t, which is the
	# whole point of deriving it. Using the nominal t while solving for a longer
	# one breaks that: the quantiser rounds to the nearest grid beat, so a hop
	# can legitimately ask for 2.6 beats instead of 2, and under nominal gravity
	# that pushed the apex from 300px to 429px -- past the 380px tier+2 floor.
	# The player then clipped the tier ABOVE their target on the way down and
	# landed a tier early, 115ms off the beat.
	_hop_gravity = Tuning.gravity_for_flight(flight)

	var rise := Tuning.TIER_RISE * float(tiers)
	var launch_speed := Tuning.solve_launch_velocity(rise, flight, _hop_gravity)

	last_launch_time = now
	last_launch_usec = Time.get_ticks_usec()
	last_flight_solved = flight
	last_launch_y = global_position.y
	last_launch_rise = rise

	# Screen y grows downward, so climbing is negative.
	velocity.y = -launch_speed
	_grounded = false
	_left_ground_at = now
	_auto_jump_at = INF

	_flash = 1.0
	_flash_color = Tuning.judgement_color(judgement)
	_deform = Tuning.BLOB_LAUNCH_STRETCH
	_deform_vel = 0.0

	jumped.emit(judgement, error, tiers)


## Advance the soft-body spring.
##
## A damped harmonic oscillator rather than a decay: it overshoots past round
## and settles, which is what makes the blob read as something soft recovering
## its shape instead of a sprite being scaled back to 1.0.
##
## While airborne it also holds a stretch proportional to vertical speed, so the
## body elongates through the fast part of an arc and rounds out at the apex.
func _update_deform(delta: float) -> void:
	var target := 0.0
	if not _grounded:
		target = -velocity.y * Tuning.BLOB_VELOCITY_STRETCH

	# Spring toward the velocity-driven target, not toward zero.
	_deform_vel += (target - _deform) * Tuning.BLOB_STIFFNESS * delta
	_deform_vel *= exp(-Tuning.BLOB_DAMPING * delta)
	_deform += _deform_vel * delta
	_deform = clampf(_deform, -Tuning.BLOB_MAX_DEFORM, Tuning.BLOB_MAX_DEFORM)


## Recomputed per call rather than cached: a stale value would disagree with the
## tempo the Conductor is running and desynchronise every arc.
func _current_gravity() -> float:
	return Tuning.gravity_for_tempo(Conductor.sec_per_beat)


func _current_platform() -> Node2D:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider == null or not collider.has_method("on_landed"):
			continue
		# Must be a floor contact. A glancing side hit would otherwise reassign
		# current_tier.
		if collision.get_normal().y < -0.7:
			return collider
	return null


# --- Rendering --------------------------------------------------------------

## Draw the body, and draw it AGAIN across the wrap seam when it straddles one.
##
## The playfield wraps horizontally, but the body was drawn once, at its single
## position, so crossing an edge made the player vanish: a screenshot caught it
## sliced in half at x=710 of 720 with nothing on the left edge, and another
## caught the same at x=10 with nothing on the right.
##
## That is not cosmetic. Wrapping is a real route to the next platform, so the
## player is asked to steer through the one region where they cannot see
## themselves. The fix is a second draw one playfield width away, which is where
## the body already is as far as the world is concerned.
func _draw() -> void:
	_draw_body()

	var w := Tuning.PLAYFIELD_WIDTH
	var x := global_position.x
	# Only when actually overlapping a seam, so the ordinary case costs nothing.
	if x < RADIUS:
		draw_set_transform(Vector2(w, 0.0))
		_draw_body()
		draw_set_transform(Vector2.ZERO)
	elif x > w - RADIUS:
		draw_set_transform(Vector2(-w, 0.0))
		_draw_body()
		draw_set_transform(Vector2.ZERO)


func _draw_body() -> void:
	var pulse := Conductor.beat_pulse(4.0) if Conductor.running else 0.0

	_draw_beat_ring()

	# Volume-preserving squash and stretch: the horizontal scale is the exact
	# inverse of the vertical one, so the blob keeps its area as it deforms.
	# This is the single detail that separates "soft body" from "scaled circle";
	# scaling one axis alone just looks like the sprite is being resized.
	var stretch := 1.0 + _deform
	var scale_v := Vector2(1.0 / stretch, stretch)
	var col := Color(0.45, 0.95, 1.0).lerp(_flash_color, _flash)

	# Keep the blob planted. A squashed body drawn about its centre would float
	# above the platform by however much it flattened, so shift it down by the
	# height it lost.
	var centre := Vector2(0.0, RADIUS * (1.0 - scale_v.y))

	# The body is drawn ONCE, above white, and the glow pass does the bloom.
	#
	# This used to be five concentric translucent ellipses, largest and faintest
	# first, imitating a blur. That cost five draws per frame for one object and
	# still looked like stacked alpha rather than light, because a stack of flat
	# shapes has hard edges no matter how faint each one is.
	#
	# The beat still breathes through the brightness rather than the size: a
	# pulse pushes the colour further past the glow threshold, so the halo grows
	# because there is more light, which is how a real one behaves.
	var gain := Tuning.GLOW_PLAYER * (1.0 + pulse * 0.30 + _flash * 0.75)
	_draw_blob(centre, RADIUS * scale_v.x, RADIUS * scale_v.y, _deform,
		UIKit.emissive(col, gain))

	# Bright core, so the player reads against a busy background. Offset
	# slightly against the deformation, like the highlight on a water droplet.
	_draw_blob(centre - Vector2(0.0, _deform * 3.0),
		RADIUS * 0.45 * scale_v.x, RADIUS * 0.45 * scale_v.y, 0.0,
		UIKit.emissive(Color(1, 1, 1), Tuning.GLOW_PLAYER_CORE * (1.0 + _flash * 0.5)))


## An ellipse with an optional surface ripple.
##
## `wobble` bulges the sides out as the body flattens, so a squashed blob
## belays outward at its equator rather than staying a clean ellipse. Small, but
## it is what stops the shape reading as a rigid oval.
## A ring that closes onto the player exactly ON the beat. Tap when it lands.
##
## THE GAME MUST BE PLAYABLE WITH THE SOUND OFF. Family testers reported that it
## was not, and they are right: the beat existed only in the music. Everything
## visual pulsed AFTER the beat, which tells you where the beat was, not where
## the next one is coming. You cannot time an input to a cue that arrives late.
##
## Phones are muted constantly, on transit, in bed, in company, so "turn the
## sound on" is not an answer. It rules out a large share of all sessions.
##
## This is the genre-standard fix, an approach circle: the ring starts wide just
## after a beat and contracts, meeting the body at the moment of the next one, so
## the beat becomes something you can SEE arriving rather than only hear having
## happened. It also runs through the count-in, which turns those four beats into
## a silent lesson in the tempo before anything is at stake.
##
## Always on, not a setting. A player who never opens Settings is exactly the
## player who needs it.
func _draw_beat_ring() -> void:
	if not Conductor.running:
		return

	# beat_progress is 0 at the beat and approaches 1 just before the next, so
	# the ring's radius falls as the beat nears and is at its tightest on it.
	var progress := Conductor.beat_progress()
	var radius := Tuning.beat_ring_radius(RADIUS, progress)

	# Sharpen as it closes. A ring that is equally faint all the way round its
	# travel reads as decoration; one that resolves reads as an approach.
	var focus := pow(progress, 2.2)
	var alpha := Tuning.BEAT_RING_ALPHA * (0.35 + 0.65 * focus)
	var width := 2.0 + focus * 2.5

	if not Settings.flash_effects:
		alpha *= 0.65

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40,
		Color(1.0, 1.0, 1.0, alpha), width, true)


func _draw_blob(centre: Vector2, rx: float, ry: float, wobble: float,
		color: Color) -> void:
	var points := PackedVector2Array()
	var segments := 28
	for i in segments:
		var a := TAU * float(i) / float(segments)
		# Bulge peaks at the sides (cos 2a is +1 at 0 and PI) and vanishes at
		# the poles, which is how a real soft body deforms.
		var bulge := 1.0 - wobble * 0.18 * cos(a * 2.0)
		points.append(centre + Vector2(cos(a) * rx * bulge, sin(a) * ry))
	draw_colored_polygon(points, color)
