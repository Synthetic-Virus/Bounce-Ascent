extends Node2D

## Reactive synthwave backdrop: gradient wash, parallax particles, pulsing grid.
##
## Drawn in code rather than shaded so it reads the Conductor directly. A shader
## uniform would be a second copy of the beat phase that can lag by a frame, and
## everything on screen needs to agree about where the beat is.
##
## All flashing respects Settings.flash_effects.

const PARTICLE_COUNT: int = 90
const PARTICLE_PARALLAX: float = 0.25
const GRID_PARALLAX: float = 0.45
const GRID_SPACING: float = 150.0

var _scroll_y: float = 0.0
var _particles: PackedVector2Array = PackedVector2Array()
var _particle_sizes: PackedFloat32Array = PackedFloat32Array()
## Vertical wrap distance for the parallax particles, set in _ready() from the
## REAL viewport height. Initialised from the constant only as a fallback: a
## member initialiser runs before the node is in the tree, where the viewport
## size is not yet knowable.
var _band: float = Tuning.PLAYFIELD_HEIGHT * 2.0


func _ready() -> void:
	# Sized to the real screen, so particles wrap across the whole viewport
	# rather than a 1280-tall slice of it and leave the bottom band empty.
	_band = UIKit.screen_height() * 2.0

	# Fixed seed: there is no gameplay reason for the backdrop to differ between
	# runs, and a stable layout makes visual regressions obvious.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20251007

	for i in PARTICLE_COUNT:
		_particles.append(Vector2(
			rng.randf_range(0.0, Tuning.PLAYFIELD_WIDTH),
			rng.randf_range(0.0, _band)
		))
		_particle_sizes.append(rng.randf_range(1.0, 3.4))

	z_index = -100
	set_process(true)


func set_scroll(camera_top_y: float) -> void:
	_scroll_y = camera_top_y


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse := Conductor.beat_pulse(4.0) if Conductor.running else 0.0
	var bar := Conductor.bar_pulse(2.5) if Conductor.running else 0.0
	if not Settings.flash_effects:
		# Keep a trace of motion but remove the strobing.
		pulse *= 0.15
		bar *= 0.15

	# The REAL viewport, not the reference layout. At 1280 this painted only the
	# top 82% of a tall phone's screen and left a black band below.
	var size := UIKit.screen_size()
	var w := size.x
	var h := size.y
	var top := _scroll_y

	_draw_gradient(top, w, h, bar)
	_draw_particles(top)
	_draw_grid(top, w, h, pulse)


## Deep violet fading to near-black, so the player's cyan body always has
## contrast beneath it.
func _draw_gradient(top: float, w: float, h: float, bar: float) -> void:
	var bands := 16
	for i in bands:
		var t := float(i) / float(bands)
		var col := Color(0.10, 0.03, 0.20).lerp(Color(0.02, 0.01, 0.05), t)
		col = col.lightened(bar * 0.10 * (1.0 - t))
		draw_rect(Rect2(0, top + t * h, w, h / float(bands) + 1.0), col, true)


func _draw_particles(top: float) -> void:
	var offset := _scroll_y * PARTICLE_PARALLAX
	for i in _particles.size():
		var p := _particles[i]
		var y := fposmod(p.y - offset, _band) + top \
			- (_band - UIKit.screen_height()) * 0.5
		var size := _particle_sizes[i]
		draw_circle(Vector2(p.x, y), size,
			Color(0.65, 0.85, 1.0, 0.10 + size * 0.055))


func _draw_grid(top: float, w: float, h: float, pulse: float) -> void:
	var offset := _scroll_y * GRID_PARALLAX
	# floorf, not floor: the untyped global returns Variant and fails the build.
	var y: float = floorf((top + offset) / GRID_SPACING) * GRID_SPACING - offset

	while y < top + h + GRID_SPACING:
		# Fading toward the top gives a horizon feel without perspective maths.
		var depth := clampf((y - top) / h, 0.0, 1.0)
		var alpha := (0.05 + pulse * 0.16) * depth
		if alpha > 0.004:
			draw_line(Vector2(0, y), Vector2(w, y),
				Color(0.45, 0.95, 1.0, alpha), 1.0 + pulse * 1.5)
		y += GRID_SPACING

	var columns := 8
	for i in range(columns + 1):
		var x := (float(i) / float(columns)) * w
		draw_line(Vector2(x, top), Vector2(x, top + h),
			Color(0.55, 0.35, 1.0, 0.025 + pulse * 0.05), 1.0)
