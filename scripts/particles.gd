extends Node2D

## Event particles: landings, PERFECTs and deaths.
##
## HAND ROLLED, deliberately, for two reasons.
##
## The engine's own particles are awkward here: this project renders with
## gl_compatibility, and the Compatibility renderer does not support manually
## emitting particles, which is exactly the operation a burst-on-an-event system
## needs. Working around that means keeping pools of pre-armed emitters, which is
## more machinery than the thing it replaces.
##
## The stronger reason is cost. Adding the engine's glow pass to this game
## intermittently cost 124 to 129ms of landing accuracy against a 25ms tolerance,
## and was parked for it. In a game whose entire premise is that landings fall on
## beats, a visual feature that can silently move timing is not worth having.
## A fixed-size array of points, updated in _process and drawn in one _draw, has
## a cost I can bound and measure.
##
## SYNCHRONISED, not layered. Every burst here fires from the same event that
## already plays a sound and, on a phone, a haptic. The research on game feel is
## consistent that visual, audio and tactile feedback have to arrive together as
## one event; adding a fourth independent channel is how juice becomes noise.
## See docs/DESIGN_RESEARCH.md.

## Hard cap on live particles.
##
## A bound, not a target. The pool is allocated once and reused, so a screen full
## of simultaneous landings costs the same as a quiet one and there is no
## allocation during play.
const MAX_PARTICLES: int = 240

var _pos: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _life_max: PackedFloat32Array = PackedFloat32Array()
var _size: PackedFloat32Array = PackedFloat32Array()
var _colour: PackedColorArray = PackedColorArray()

## Next slot to overwrite. Oldest-first reuse: when the pool is full the longest
## lived particle is the least interesting one to keep.
var _cursor: int = 0

## Downward pull, in pixels per second squared. Unrelated to the player's
## gravity, which is solved against the beat and must not be borrowed for
## decoration.
const DRAG: float = 2.4
const FALL: float = 520.0


func _ready() -> void:
	_pos.resize(MAX_PARTICLES)
	_vel.resize(MAX_PARTICLES)
	_life.resize(MAX_PARTICLES)
	_life_max.resize(MAX_PARTICLES)
	_size.resize(MAX_PARTICLES)
	_colour.resize(MAX_PARTICLES)
	for i in MAX_PARTICLES:
		_life[i] = 0.0
	set_process(true)


## Spray `count` particles from `origin`.
##
## `spread` is the half-angle in radians about `direction`; TAU/2 is a full
## circle. Speeds and lifetimes vary per particle so a burst reads as debris
## rather than as a shape expanding.
func burst(origin: Vector2, count: int, colour: Color, speed: float,
		direction: float = -PI * 0.5, spread: float = PI * 0.5,
		life: float = 0.5, size: float = 3.0) -> void:
	if not Settings.flash_effects:
		# Accessibility: this is the same category of thing as the screen flash,
		# so it answers to the same switch. Halved rather than removed, because
		# feedback that an input registered is not decoration.
		count = int(count * 0.35)

	for _i in count:
		var a := direction + randf_range(-spread, spread)
		var s := speed * randf_range(0.45, 1.0)
		var slot := _cursor
		_cursor = (_cursor + 1) % MAX_PARTICLES

		_pos[slot] = origin
		_vel[slot] = Vector2(cos(a), sin(a)) * s
		_life_max[slot] = life * randf_range(0.7, 1.15)
		_life[slot] = _life_max[slot]
		_size[slot] = size * randf_range(0.6, 1.3)
		_colour[slot] = colour


func _process(delta: float) -> void:
	var any := false
	for i in MAX_PARTICLES:
		if _life[i] <= 0.0:
			continue
		any = true
		_life[i] -= delta
		_vel[i] = _vel[i] * (1.0 - DRAG * delta) + Vector2(0.0, FALL * delta)
		_pos[i] += _vel[i] * delta

	# Only redraw while something is alive. A HUD that redraws every frame is
	# fine; a particle layer that does so while empty is pure waste.
	if any or _was_drawing:
		_was_drawing = any
		queue_redraw()


var _was_drawing: bool = false


func _draw() -> void:
	for i in MAX_PARTICLES:
		if _life[i] <= 0.0:
			continue
		var t := _life[i] / _life_max[i]
		var c := _colour[i]
		# Fade and shrink together: either alone reads as a sprite being
		# animated, both together read as something dissipating.
		draw_circle(_pos[i], _size[i] * t,
			Color(c.r, c.g, c.b, c.a * t))


## Clear everything, for a restart. Without this the debris of the previous run
## hangs in the air over the first frame of the new one.
func clear() -> void:
	for i in MAX_PARTICLES:
		_life[i] = 0.0
	queue_redraw()


## Live count. Exposed for tests: a bounded pool is only bounded if something
## checks.
func live_count() -> int:
	var n := 0
	for i in MAX_PARTICLES:
		if _life[i] > 0.0:
			n += 1
	return n
