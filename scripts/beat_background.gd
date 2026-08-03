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

## Horizon drift, as a fraction of camera travel.
##
## A tenth of the grid's rate, which is nearly nailed down. A run climbs
## thousands of pixels, so anything back here moving at a plausible speed would
## be gone within two hops and the climb would lose its only fixed reference.
## The small amount that remains is what keeps it from looking painted on.
const HORIZON_PARALLAX: float = 0.045

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
	_draw_horizon(top, w, h, pulse, bar)
	_draw_particles(top)
	_draw_grid(top, w, h, pulse)


## The synthwave horizon: a slitted sun and a ridge line, far behind everything.
##
## PARALLAXED ALMOST TO STILLNESS, at a tenth of the grid's rate, so it reads as
## distance rather than as scenery sliding past. The player climbs thousands of
## pixels in a run; anything back here that moved at a believable speed would
## have left the screen within two hops and the climb would have no fixed
## reference at all.
##
## Drawn rather than imported for the same reason everything else here is: it
## reads the Conductor directly, so the sun breathes on the beat and the ridge
## catches the bar, and a texture would need a shader with its own copy of the
## beat phase that can disagree by a frame.
func _draw_horizon(top: float, w: float, h: float, pulse: float, bar: float) -> void:
	# NO ALTITUDE FADE, and not for want of trying.
	#
	# The obvious idea was to fade the horizon out as the player climbed, on the
	# grounds that this is the ground being left behind. It was implemented by
	# scaling the emissive gain, which is where it went wrong: dropping the gain
	# below 1.0 takes the colour back under the glow threshold, and a saturated
	# pink at low brightness over a near-black sky is brown. The screenshot
	# showed a muddy olive smear where a neon sun should be.
	#
	# Brightness is not the same axis as presence. Fading would have to be done
	# on alpha, keeping the gain above the threshold.
	#
	# But it should not be done at all. The horizon is infinitely distant, which
	# is the whole convention the genre rests on, and in an endless vertical
	# climb it is the only fixed thing on screen. Sitting it low, at 0.86 of the
	# screen height, keeps it clear of the play area without needing to
	# disappear, and the death wash covers it exactly when the player has more
	# urgent things to look at.
	var drift := _scroll_y * HORIZON_PARALLAX
	var base := top + h * 0.86 - drift

	# Small, and sitting ON the horizon rather than floating behind the play
	# area. Most of it is below the ridge; what shows is the top of a setting
	# sun, which is the shape the genre is actually built on.
	var sun_r := w * 0.20 * (1.0 + bar * 0.04)
	# Half of it above the ridge line, not a sliver.
	#
	# A first pass sat the centre BELOW the base and left only the top third
	# showing, which mattered more than it sounds: the bands run amber at the top
	# to magenta at the bottom, so clipping the bottom two thirds threw away the
	# magenta entirely and the sun read as a flat yellow smudge rather than a
	# gradient. The gradient IS the effect.
	var centre := Vector2(w * 0.5, base - sun_r * 0.10)

	# A stack of bars rather than a disc, with the gaps widening downward. The
	# banding is the genre's signature and it is also what keeps a bright shape
	# from reading as a solid mass: most of its area is holes.
	var bands := 14
	for i in bands:
		var t := float(i) / float(bands)
		var y := centre.y - sun_r + t * sun_r * 2.0
		var dy := (y - centre.y) / sun_r
		var half := sun_r * sqrt(maxf(1.0 - dy * dy, 0.0))
		if half <= 1.0:
			continue
		var duty := clampf(1.0 - t * 1.2, 0.08, 1.0)
		var band_h := (sun_r * 2.0 / float(bands)) * duty
		if band_h < 0.6:
			continue
		# EMISSIVE, like everything else neon in this game.
		#
		# The first attempt drew these at alpha 0.3 over a near-black sky, which
		# is how you get brown: a saturated colour at low alpha over black is
		# just a dark desaturated version of itself. Full alpha and a gain past
		# the glow threshold is what makes it read as a light source.
		var col := Color(1.0, 0.30, 0.58).lerp(Color(1.0, 0.72, 0.30), 1.0 - t)
		draw_rect(Rect2(centre.x - half, y, half * 2.0, band_h),
			UIKit.emissive(col, 1.35 + pulse * 0.30))

	# The ridge, drawn as one quad per segment.
	#
	# NOT as a single polygon: a skyline is concave, and draw_colored_polygon
	# expects convex input, so the first version triangulated into a mess that
	# let the sun show through the mountains.
	var steps := 14
	for i in range(steps):
		var x0 := (float(i) / float(steps)) * w
		var x1 := (float(i + 1) / float(steps)) * w
		var y0 := base - _ridge_height(i)
		var y1 := base - _ridge_height(i + 1)
		# Bottom corners first, so each quad is wound consistently and convex.
		var quad := PackedVector2Array([
			Vector2(x0, y0), Vector2(x1, y1),
			Vector2(x1, base + h), Vector2(x0, base + h)])
		# Just light enough to read as mass against the sky rather than as a hole
		# cut in it, and still dark enough that nothing here competes with a
		# platform.
		draw_colored_polygon(quad, Color(0.07, 0.03, 0.16, 1.0))
		# Rim light on the bar rather than the beat, so the horizon marks the
		# music at a slower rate than the playfield does.
		draw_line(Vector2(x0, y0), Vector2(x1, y1),
			UIKit.emissive(Color(1.0, 0.40, 0.82), 1.25 + bar * 0.40), 2.0)


## Skyline height at a step. Two summed sines, deterministic, so the ridge is
## identical every run and any visual change is a real one.
func _ridge_height(step: int) -> float:
	return 18.0 + absf(sin(float(step) * 1.7) * 26.0 + sin(float(step) * 0.6) * 40.0)


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
