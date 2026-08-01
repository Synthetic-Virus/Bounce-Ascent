extends StaticBody2D

## A single platform.
##
## One-way, which is essential: a PERFECT climbs two tiers and must pass
## straight through the intervening platform without snagging.
##
## Behaviour varies by Tuning.PlatformType, but only horizontally or in
## availability. Nothing here may change a platform's y, because fixed tier
## spacing is what makes flight time solvable against the beat.

## Tier of the climb this belongs to. Tier 0 is the start, increasing upward.
var tier: int = 0

var type: Tuning.PlatformType = Tuning.PlatformType.NORMAL

var half_width: float = Tuning.PLATFORM_HALF_WIDTH
var half_height: float = Tuning.PLATFORM_HALF_HEIGHT

## Set by the spawner so consecutive platforms cycle through the palette.
var hue_offset: float = 0.0

## MOVING: sway amplitude in pixels, and the x the sway is centred on.
var move_amplitude: float = 0.0
var _home_x: float = 0.0

## MOVING/PHASING read the beat clock, so each platform needs its own phase
## offset or every platform on screen would move as one block.
var _phase_offset: float = 0.0

var _flash: float = 0.0
var _visited: bool = false

## CRUMBLING: song time at which it collapses, or INF while intact.
var _crumble_at: float = INF
var _crumbled: bool = false

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(half_width * 2.0, half_height * 2.0)
	_shape.shape = rect
	_shape.one_way_collision_margin = 8.0
	collision_layer = 2
	collision_mask = 0
	set_process(true)


## Called by the spawner on creation and on recycle, so it must fully reset
## transient state.
func setup(
	new_tier: int,
	pos: Vector2,
	width_scale: float = 1.0,
	new_type: Tuning.PlatformType = Tuning.PlatformType.NORMAL,
	amplitude: float = 0.0
) -> void:
	tier = new_tier
	type = new_type
	global_position = pos
	_home_x = pos.x
	move_amplitude = amplitude
	half_width = Tuning.PLATFORM_HALF_WIDTH * width_scale
	hue_offset = fposmod(float(new_tier) * 0.021, 1.0)
	# Derived from the tier so a recycled platform does not inherit a phase and
	# suddenly jump. Deterministic, unlike randf().
	_phase_offset = fposmod(float(new_tier) * 0.37, 1.0) * TAU

	_flash = 0.0
	_visited = false
	_crumble_at = INF
	_crumbled = false

	if _shape != null and _shape.shape is RectangleShape2D:
		(_shape.shape as RectangleShape2D).size = Vector2(
			half_width * 2.0, half_height * 2.0)

	_set_solid(true)
	# SOLID is the only type that is not one-way. Everything else must be
	# passable from below or the player could never land on it, since they
	# always approach from the tier beneath.
	if _shape != null:
		_shape.one_way_collision = new_type != Tuning.PlatformType.SOLID

	visible = true
	queue_redraw()


func on_landed() -> void:
	_flash = 1.0
	_visited = true
	if type == Tuning.PlatformType.CRUMBLING:
		_crumble_at = Conductor.now() \
			+ Tuning.CRUMBLE_BEATS * Conductor.sec_per_beat


## True when the player can currently land on this. PHASING platforms spend
## every other bar intangible.
func is_solid() -> bool:
	if _crumbled:
		return false
	if type != Tuning.PlatformType.PHASING or not Conductor.running:
		return true
	return _phase_cycle() < 1.0


## Position within the phase cycle, 0..2. Below 1.0 is solid.
func _phase_cycle() -> float:
	var bars := Conductor.song_beats / float(Conductor.beats_per_bar)
	return fposmod(bars / Tuning.PHASE_BARS + float(tier % 2), 2.0)


func _process(delta: float) -> void:
	if type == Tuning.PlatformType.MOVING and Conductor.running:
		# Tied to song position, not delta, so the sway stays locked to the
		# music and is identical on every machine.
		var t := Conductor.song_beats / Tuning.MOVE_BEATS_PER_CYCLE
		global_position.x = _home_x \
			+ sin(t * TAU + _phase_offset) * move_amplitude

	if type == Tuning.PlatformType.CRUMBLING and not _crumbled:
		if Conductor.now() >= _crumble_at:
			_crumbled = true
			_set_solid(false)

	if type == Tuning.PlatformType.PHASING:
		_set_solid(is_solid())

	if _flash > 0.0:
		_flash = maxf(_flash - delta * 3.5, 0.0)

	if _flash > 0.0 or Conductor.running:
		queue_redraw()


## Collision is disabled rather than the node hidden, so a phased-out platform
## still draws its outline and the player can see where it will return.
func _set_solid(solid: bool) -> void:
	if _shape != null:
		_shape.set_deferred("disabled", not solid)


func _draw() -> void:
	var pulse := Conductor.beat_pulse(5.0) if Conductor.running else 0.0
	var col := _colour()
	var alpha := _alpha()
	if alpha <= 0.01:
		return

	var glow := 1.0 + pulse * 0.35 + _flash * 1.2
	var w := half_width
	var h := half_height

	for i in range(4, 0, -1):
		var expand := float(i) * 5.0 * glow
		draw_rect(
			Rect2(-w - expand, -h - expand,
				(w + expand) * 2.0, (h + expand) * 2.0),
			Color(col.r, col.g, col.b, (0.045 + _flash * 0.09) * alpha), true)

	if type == Tuning.PlatformType.SOLID:
		# Drawn as a slab with a hard edge, so "you cannot pass through this"
		# is legible at a glance and at speed.
		var slab := Rect2(-w, -h * 1.8, w * 2.0, h * 3.6)
		draw_rect(slab, Color(col.r * 0.35, col.g * 0.38, col.b * 0.5, alpha), true)
		draw_rect(slab, Color(col.r, col.g, col.b, alpha * 0.9), false, 2.0)
		draw_rect(Rect2(-w, -h * 1.8, w * 2.0, 4.0),
			Color(col.r, col.g, col.b, alpha), true)
	elif is_solid():
		draw_rect(Rect2(-w, -h, w * 2.0, h * 2.0),
			Color(col.r, col.g, col.b, alpha), true)
	else:
		# Outline only, so an intangible platform is obviously not a floor while
		# still showing where it will come back.
		draw_rect(Rect2(-w, -h, w * 2.0, h * 2.0),
			Color(col.r, col.g, col.b, alpha * 0.85), false, 2.0)

	# The top edge is the surface actually landed on, so it gets the highest
	# contrast. Readability, not decoration.
	if is_solid() and type != Tuning.PlatformType.SOLID:
		draw_rect(Rect2(-w, -h, w * 2.0, 3.0),
			Color(1, 1, 1, (0.55 + _flash * 0.45) * alpha), true)


## Type is communicated by hue, because the player has to read it at a glance
## while airborne: cyan is safe, amber moves, red crumbles, violet phases.
func _colour() -> Color:
	var col: Color
	match type:
		Tuning.PlatformType.MOVING:
			col = Color(1.0, 0.72, 0.25)
		Tuning.PlatformType.CRUMBLING:
			col = Color(1.0, 0.38, 0.42)
		Tuning.PlatformType.PHASING:
			col = Color(0.72, 0.45, 1.0)
		Tuning.PlatformType.SOLID:
			# Pale steel, deliberately unlike the neon types: it is scenery you
			# must respect rather than a surface you can pass through.
			col = Color(0.88, 0.93, 1.0)
		_:
			col = Color.from_hsv(fposmod(0.52 + hue_offset, 1.0), 0.55, 1.0)

	if _visited and type == Tuning.PlatformType.NORMAL:
		# Dim visited platforms, leaving a readable trail without clutter.
		col = col.darkened(0.45)
	return col


func _alpha() -> float:
	if _crumbled:
		return 0.0
	if type != Tuning.PlatformType.PHASING or not Conductor.running:
		return 1.0

	# Fade across the cycle rather than snapping, so the player can see the
	# change coming and plan the hop before committing to it.
	var cycle := _phase_cycle()
	if cycle < 1.0:
		return lerpf(1.0, 0.55, cycle)
	return lerpf(0.28, 0.9, cycle - 1.0)
