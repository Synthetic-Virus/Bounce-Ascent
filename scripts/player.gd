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
	_flash = 0.0
	_deform = 0.0
	_deform_vel = 0.0
	active = true


## Arm the first jump, called by Game the instant the count-in ends (which is
## itself on a beat). Without it the run would open with an unquantised free
## fall and spend several hops correcting.
func arm_first_jump() -> void:
	_grounded = true
	velocity = Vector2.ZERO
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

	velocity.y += _current_gravity() * delta
	velocity.y = minf(velocity.y, Tuning.MAX_FALL_SPEED)

	_apply_horizontal(delta)

	var was_grounded := _grounded
	move_and_slide()
	_grounded = is_on_floor()

	if _grounded and not was_grounded:
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
	var flight := Tuning.quantise_landing_time(now, Conductor.sec_per_beat) - now
	var nominal := Tuning.HOP_BEATS * Conductor.sec_per_beat
	flight = clampf(flight, nominal * FLIGHT_MIN_SCALE, nominal * FLIGHT_MAX_SCALE)

	var launch_speed := Tuning.solve_launch_velocity(
		Tuning.TIER_RISE * float(tiers), flight, _current_gravity())

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

func _draw() -> void:
	var pulse := Conductor.beat_pulse(4.0) if Conductor.running else 0.0

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

	# Fake bloom: concentric translucent ellipses, largest and faintest first.
	# Cheaper than a glow pass for a handful of objects, and it lets the glow
	# breathe with the music.
	var glow_scale := 1.0 + pulse * 0.25 + _flash * 0.6
	for i in range(4, 0, -1):
		var r := RADIUS * (1.0 + float(i) * 0.32) * glow_scale
		_draw_blob(centre, r * scale_v.x, r * scale_v.y, 0.0,
			Color(col.r, col.g, col.b, 0.10 * _flash + 0.055))

	_draw_blob(centre, RADIUS * scale_v.x, RADIUS * scale_v.y, _deform, col)
	# Bright core, so the player reads against a busy background. Offset
	# slightly against the deformation, like the highlight on a water droplet.
	_draw_blob(centre - Vector2(0.0, _deform * 3.0),
		RADIUS * 0.45 * scale_v.x, RADIUS * 0.45 * scale_v.y, 0.0,
		Color(1, 1, 1, 0.9))


## An ellipse with an optional surface ripple.
##
## `wobble` bulges the sides out as the body flattens, so a squashed blob
## belays outward at its equator rather than staying a clean ellipse. Small, but
## it is what stops the shape reading as a rigid oval.
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
