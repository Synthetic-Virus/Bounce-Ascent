extends Control

## The beat ruler: a live tick strip down the left edge of every screen.
##
## The one bold element in the interface, and the only one allowed to be loud.
## It encodes the thing the whole game is built on rather than decorating: ticks
## march downward in time with the music, downbeats run full width, and the
## current beat burns bright.
##
## Present on the menu, the calibration screen and during a run, so the tempo
## you are about to play is visible before you commit to it and the same spine
## runs through every screen.

## How many ticks are drawn top to bottom.
const TICKS: int = 32

## Beats represented per tick. A quarter means one bar spans 16 ticks, so the
## strip shows two bars at a time.
const BEATS_PER_TICK: float = 0.25


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var h := size.y
	if h <= 0.0:
		return

	var spacing := h / float(TICKS)
	var beats := Conductor.song_beats if Conductor.running else 0.0
	var bpb := float(Conductor.beats_per_bar)

	# Scroll the strip by song position so it reads as time passing, not as a
	# static ornament that happens to blink.
	var offset := fposmod(beats / BEATS_PER_TICK, 1.0) * spacing

	for i in TICKS + 1:
		var y := float(i) * spacing - offset
		if y < -spacing or y > h:
			continue

		# Which absolute beat this tick represents.
		var tick_beat := floorf(beats / BEATS_PER_TICK) - float(i) + float(TICKS)
		var beat_pos := tick_beat * BEATS_PER_TICK

		var is_beat := is_equal_approx(fposmod(beat_pos, 1.0), 0.0)
		var is_bar := is_equal_approx(fposmod(beat_pos, bpb), 0.0)

		var width := 5.0
		var col := UIKit.VIOLET
		var alpha := 0.22

		if is_bar:
			width = UIKit.RULER_WIDTH
			col = UIKit.GOLD
			alpha = 0.55
		elif is_beat:
			width = 12.0
			col = UIKit.CYAN
			alpha = 0.40

		# The playhead: ticks near the top of the strip are "now".
		var distance := absf(y - h * 0.5)
		var proximity := clampf(1.0 - distance / (spacing * 2.0), 0.0, 1.0)
		if Conductor.running and Settings.flash_effects:
			alpha = minf(alpha + proximity * 0.55, 1.0)
			width += proximity * 6.0

		draw_rect(Rect2(0.0, y - 1.0, width, 2.0),
			Color(col.r, col.g, col.b, alpha), true)

	# A hairline spine so the strip still reads when the music is stopped.
	draw_rect(Rect2(0.0, 0.0, 1.0, h), Color(UIKit.VIOLET.r, UIKit.VIOLET.g,
		UIKit.VIOLET.b, 0.25), true)
