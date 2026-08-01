extends Control

## Audio latency calibration.
##
## get_output_latency() covers only Godot's own buffering, not the OS mixer,
## Bluetooth or display processing, which differ by over 200ms between setups.
## Without correcting for that, a player on high-latency output cannot score
## well however good their timing is.
##
## Method: tap along to the kick, take the MEDIAN signed error. Median rather
## than mean because one fumbled tap half a beat out would drag an average
## enough to make the calibration worse than none.
##
## The screen is written as a sequence with visible progress, because "tap
## sixteen times and trust us" is not a thing a player can follow. The ring, the
## counter and the running verdict all say the same thing in different ways.

const MenuScene: String = "res://scenes/MainMenu.tscn"

const TAPS_REQUIRED: int = 16

## Taps in the first bars are discarded: players need a moment to lock on, and
## their first couple are always poor.
const WARMUP_BEATS: float = 4.0

## A median beyond this is far more likely to be tapping on the offbeat than
## genuine latency, so it is rejected with an explanation rather than applied.
const MAX_REASONABLE_OFFSET_MS: float = 400.0

var _errors: Array[float] = []
var _song: Dictionary = {}
var _finished: bool = false
var _flash: float = 0.0
var _result_ms: float = 0.0
var _rejected: bool = false
var _done: Button
var _retry: Button


func _ready() -> void:
	_song = SongLibrary.get_song(Settings.last_song_id)
	_build()

	if Music.is_song_ready(_song["id"]):
		Conductor.start(_song)
		Music.play_song(_song)

	set_process(true)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# NO background ColorRect child here. This screen paints its content in
	# _draw(), and a CanvasItem draws itself BEFORE its children, so an opaque
	# background child would cover everything this screen draws. The background
	# is painted as the first thing in _draw() instead.
	var ruler := preload("res://scenes/BeatRuler.tscn").instantiate()
	ruler.position = Vector2(18.0, 0.0)
	ruler.size = Vector2(UIKit.RULER_WIDTH, Tuning.PLAYFIELD_HEIGHT)
	add_child(ruler)

	# Real buttons, not keyboard hints. "Press ESC when done" is meaningless on
	# a phone, and this screen is the first thing a new player is told to visit.
	var actions := VBoxContainer.new()
	actions.position = Vector2(UIKit.MARGIN, Tuning.PLAYFIELD_HEIGHT - 250.0)
	actions.size = Vector2(Tuning.PLAYFIELD_WIDTH - UIKit.MARGIN * 2.0, 190.0)
	actions.add_theme_constant_override("separation", 12)
	add_child(actions)

	_done = UIKit.button("Done", UIKit.GOLD, 26, true)
	_done.custom_minimum_size = Vector2(0, Tuning.TOUCH_PRIMARY)
	_done.pressed.connect(_back_to_menu)
	actions.add_child(_done)

	_retry = UIKit.button("Start over", UIKit.CYAN, 20)
	_retry.custom_minimum_size = Vector2(0, Tuning.TOUCH_MIN)
	_retry.pressed.connect(_restart_taps)
	actions.add_child(_retry)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 3.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var w := Tuning.PLAYFIELD_WIDTH
	var h := Tuning.PLAYFIELD_HEIGHT
	var display := UIKit.display_font()
	var data := UIKit.data_font()

	draw_rect(Rect2(0.0, 0.0, w, h), UIKit.BG, true)

	draw_string(display, Vector2(UIKit.MARGIN, 150.0),
		"CALIBRATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, UIKit.CYAN)
	draw_string(data, Vector2(UIKit.MARGIN + 3.0, 184.0),
		"tap anywhere, or press space",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UIKit.DIM)

	if not Conductor.running:
		draw_string(data, Vector2(UIKit.MARGIN, 300.0),
			"building audio, one moment", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIKit.GOLD)
		return

	# The instruction, stated once, as an action.
	draw_string(display, Vector2(0.0, 300.0),
		"TAP ON EVERY KICK DRUM",
		HORIZONTAL_ALIGNMENT_CENTER, w, 24, UIKit.TEXT)

	_draw_ring(w, h)
	_draw_progress(data, w, h)
	_draw_footer(data, w, h)


## A ring that snaps out on each beat, giving something to tap against by eye
## as well as by ear.
func _draw_ring(w: float, h: float) -> void:
	var centre := Vector2(w * 0.5, h * 0.46)
	var pulse := Conductor.beat_pulse(4.0)
	var radius := 54.0 + pulse * 52.0

	draw_arc(centre, radius, 0.0, TAU, 56,
		Color(UIKit.CYAN.r, UIKit.CYAN.g, UIKit.CYAN.b, 0.30 + pulse * 0.55),
		3.0, true)
	draw_arc(centre, 54.0, 0.0, TAU, 56,
		Color(UIKit.VIOLET.r, UIKit.VIOLET.g, UIKit.VIOLET.b, 0.35), 1.5, true)

	if _flash > 0.0:
		draw_circle(centre, 30.0 * _flash,
			Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, _flash * 0.8))


## Progress as filled pips, so remaining taps are countable at a glance.
func _draw_progress(data: Font, w: float, h: float) -> void:
	var y := h * 0.46 + 150.0
	var collected := _errors.size()
	var start_x := w * 0.5 - float(TAPS_REQUIRED - 1) * 9.0

	for i in TAPS_REQUIRED:
		var c := Vector2(start_x + float(i) * 18.0, y)
		if i < collected:
			draw_circle(c, 5.0, UIKit.CYAN)
		else:
			draw_arc(c, 5.0, 0.0, TAU, 12,
				Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, 0.6), 1.5)

	if _finished:
		var verdict := "offset now %+d ms" % int(Settings.audio_offset_ms)
		draw_string(data, Vector2(0.0, y + 46.0),
			"measured %+d ms" % int(_result_ms),
			HORIZONTAL_ALIGNMENT_CENTER, w, 26, UIKit.GOLD)
		draw_string(data, Vector2(0.0, y + 76.0), verdict,
			HORIZONTAL_ALIGNMENT_CENTER, w, 18, UIKit.DIM)
		draw_string(data, Vector2(0.0, y + 112.0), "that is it, you are calibrated",
			HORIZONTAL_ALIGNMENT_CENTER, w, 18, UIKit.TEXT)
	elif _rejected:
		# An error explains what happened and how to fix it, in the interface's
		# own voice, without apologising or being vague.
		draw_string(data, Vector2(0.0, y + 46.0),
			"that came out %+d ms" % int(_result_ms),
			HORIZONTAL_ALIGNMENT_CENTER, w, 22, UIKit.RED)
		draw_string(data, Vector2(0.0, y + 76.0),
			"too far out to be latency, so nothing changed",
			HORIZONTAL_ALIGNMENT_CENTER, w, 17, UIKit.DIM)
		draw_string(data, Vector2(0.0, y + 100.0),
			"you were probably tapping between the kicks",
			HORIZONTAL_ALIGNMENT_CENTER, w, 17, UIKit.DIM)
	else:
		draw_string(data, Vector2(0.0, y + 46.0),
			"%d of %d" % [collected, TAPS_REQUIRED],
			HORIZONTAL_ALIGNMENT_CENTER, w, 24, UIKit.TEXT)
		draw_string(data, Vector2(0.0, y + 76.0), _live_hint(),
			HORIZONTAL_ALIGNMENT_CENTER, w, 18, UIKit.DIM)


func _draw_footer(data: Font, w: float, h: float) -> void:
	draw_string(data, Vector2(0.0, h - 270.0),
		"current offset  %+d ms" % int(Settings.audio_offset_ms),
		HORIZONTAL_ALIGNMENT_CENTER, w, 17, UIKit.DIM)


## A running read on which way the player is drifting, so the screen is useful
## while it collects rather than only at the end.
func _live_hint() -> String:
	if _errors.size() < 3:
		return "keep going"
	var med := _median(_errors) * 1000.0
	if absf(med) < 12.0:
		return "dead on"
	return "you are tapping %s" % ("late" if med > 0.0 else "early")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_back_to_menu()
	elif event.is_action_pressed("restart"):
		_restart_taps()
	elif event.is_action_pressed("jump") and not _finished and Conductor.running:
		_register_tap()


func _restart_taps() -> void:
	_errors.clear()
	_finished = false
	_rejected = false
	Music.play_sfx("ui_move")


func _register_tap() -> void:
	if Conductor.song_beats < WARMUP_BEATS:
		_flash = 0.4
		return

	_errors.append(Conductor.judge_now()["error"])
	_flash = 1.0
	_rejected = false
	Music.play_sfx("ui_move")

	if _errors.size() >= TAPS_REQUIRED:
		_finish()


func _finish() -> void:
	var median_ms := _median(_errors) * 1000.0
	_result_ms = median_ms

	if absf(median_ms) > MAX_REASONABLE_OFFSET_MS:
		_rejected = true
		_errors.clear()
		return

	# Cumulative: the player just calibrated WITH the current offset applied, so
	# this is a correction to it, not a replacement.
	Settings.audio_offset_ms += median_ms
	Settings.save_settings()
	_finished = true
	_errors.clear()
	Music.play_sfx("ui_confirm")


static func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	if n % 2 == 1:
		return sorted[n / 2]
	return (sorted[n / 2 - 1] + sorted[n / 2]) * 0.5


func _back_to_menu() -> void:
	Music.stop_song()
	Conductor.stop()
	get_tree().change_scene_to_file(MenuScene)
