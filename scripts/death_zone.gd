extends Node2D

## The rising hazard below the player. Falling into it ends the run.
##
## Drawn rather than merely computed: a fail condition the player cannot see is
## barely better than none. It sits just past the bottom of the view during
## normal play and climbs into frame as the run gets harder, which is the only
## warning the player gets that they are being caught.

## How far below the line to fill, so the band never ends in mid-air.
const DEPTH: float = 900.0

var _line_y: float = 0.0


func _ready() -> void:
	# Above the background and the platforms, below the player.
	z_index = -10
	set_process(true)


func set_line(world_y: float) -> void:
	_line_y = world_y


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse := Conductor.beat_pulse(3.0) if Conductor.running else 0.0
	if not Settings.flash_effects:
		pulse *= 0.2

	var w := Tuning.PLAYFIELD_WIDTH
	var edge := Color(1.0, 0.25, 0.42)

	# Body, fading downward so it reads as depth rather than a solid wall.
	var bands := 10
	for i in bands:
		var t := float(i) / float(bands)
		draw_rect(
			Rect2(0.0, _line_y + t * DEPTH, w, DEPTH / float(bands) + 1.0),
			Color(edge.r * 0.5, 0.03, 0.12, 0.55 * (1.0 - t)),
			true
		)

	# Glow above the edge, so the hazard announces itself before it arrives.
	for i in range(5, 0, -1):
		var h := float(i) * 9.0 * (1.0 + pulse * 0.5)
		draw_rect(Rect2(0.0, _line_y - h, w, h),
			Color(edge.r, edge.g, edge.b, 0.05 + pulse * 0.04), true)

	# The edge itself, the thing the player must stay above.
	draw_rect(Rect2(0.0, _line_y - 3.0, w, 6.0),
		Color(1.0, 0.55, 0.65, 0.85 + pulse * 0.15), true)
