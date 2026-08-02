extends CanvasLayer

## In-run HUD.
##
## A rhythm HUD has a narrow job: report the last judgement instantly, show the
## combo that is at risk, and warn when the death line is closing. Everything
## else stays out of the way of the playfield.
##
## Judgement and combo are drawn as one group in the upper third. They were
## previously separate widgets in separate places, which split the player's
## attention between two readouts describing the same event.
##
## Score is deliberately small and peripheral. Watching it mid-run is never the
## right play; it is there for after you land, not during.

const POPUP_HOLD: float = 0.35
const POPUP_FADE: float = 0.45

## Inset of the pause button from the top and right edges.
const PAUSE_MARGIN: float = 20.0

## Clearance between the height readout and the pause button. Named so the two
## are laid out against each other rather than each against the screen edge,
## which is how they came to overlap.
const HUD_GAP: float = 16.0

signal pause_requested
signal resume_requested
signal restart_requested
signal menu_requested

var _canvas: Control
var _pause_panel: Control
var _pause_button: Button

## Top safe-area inset, cached at build time.
var _top_inset: float = 0.0


## The block the height readout occupies, drawn text and all.
##
## Exposed as a function so the pause button's placement can be ASSERTED
## against it. The two were previously positioned independently, each against
## the right edge of the screen, and nothing connected them: the button landed
## on top of the readout and no test could see it, because draw_string leaves no
## node behind to measure. Anything drawn rather than laid out needs a rect like
## this if it is to be checked at all.
func height_readout_rect() -> Rect2:
	var right := Tuning.PLAYFIELD_WIDTH - Tuning.TOUCH_MIN - PAUSE_MARGIN \
		- HUD_GAP - 200.0
	return Rect2(right, _top_inset + 30.0, 200.0, 62.0)


## Where the pause button sits. Same reasoning as above.
func pause_button_rect() -> Rect2:
	return Rect2(
		Tuning.PLAYFIELD_WIDTH - Tuning.TOUCH_MIN - PAUSE_MARGIN,
		_top_inset + PAUSE_MARGIN,
		Tuning.TOUCH_MIN, Tuning.TOUCH_MIN)

var _song_name: String = ""
var _song_bpm: int = 0

var _score: int = 0
var _combo: int = 0
var _height: int = 0
var _danger: float = 0.0

var _judgement: int = -1
var _judgement_error: float = 0.0
var _judgement_tiers: int = 1
var _popup_age: float = 999.0

var _countdown: int = -1

## Smoothed score, so the number rolls rather than snapping.
var _shown_score: float = 0.0


func _ready() -> void:
	layer = 10
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)

	var ruler := preload("res://scenes/BeatRuler.tscn").instantiate()
	ruler.position = Vector2(18.0, 0.0)
	ruler.size = Vector2(UIKit.RULER_WIDTH, UIKit.screen_height())
	_canvas.add_child(ruler)

	# Cached rather than sampled per frame: it cannot change during a run, and
	# _draw runs every frame.
	_top_inset = UIKit.safe_area_insets().x

	# A pause control on screen, because a phone has no ESC key and without one
	# there would be no way to pause a touch run at all.
	#
	# Pushed below the safe-area inset. At a flat y=20 it sat underneath the
	# Dynamic Island on a modern iPhone, which is both unreadable and awkward to
	# hit, since the island swallows touches near it.
	_pause_button = UIKit.button("II", UIKit.CYAN, 22)
	_pause_button.custom_minimum_size = Vector2(Tuning.TOUCH_MIN, Tuning.TOUCH_MIN)
	_pause_button.position = pause_button_rect().position
	_pause_button.size = pause_button_rect().size
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(func(): pause_requested.emit())
	_canvas.add_child(_pause_button)

	_pause_panel = Control.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_panel.draw.connect(_draw_pause)
	_pause_panel.visible = false
	add_child(_pause_panel)
	_build_pause_actions()


## Buttons on the pause screen, for the same reason the pause control exists.
func _build_pause_actions() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(UIKit.MARGIN, UIKit.screen_height() * 0.52)
	col.size = Vector2(Tuning.PLAYFIELD_WIDTH - UIKit.MARGIN * 2.0, 300.0)
	col.add_theme_constant_override("separation", 12)
	col.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_panel.add_child(col)

	var resume := UIKit.button("Resume", UIKit.GOLD, 26, true)
	resume.custom_minimum_size = Vector2(0, Tuning.TOUCH_PRIMARY)
	resume.process_mode = Node.PROCESS_MODE_ALWAYS
	resume.pressed.connect(func(): resume_requested.emit())
	col.add_child(resume)

	var restart := UIKit.button("Restart track", UIKit.CYAN, 20)
	restart.custom_minimum_size = Vector2(0, Tuning.TOUCH_MIN)
	restart.process_mode = Node.PROCESS_MODE_ALWAYS
	restart.pressed.connect(func(): restart_requested.emit())
	col.add_child(restart)

	var menu := UIKit.button("Back to tracks", UIKit.CYAN, 20)
	menu.custom_minimum_size = Vector2(0, Tuning.TOUCH_MIN)
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.pressed.connect(func(): menu_requested.emit())
	col.add_child(menu)

	set_process(true)


func _process(delta: float) -> void:
	_popup_age += delta
	_shown_score = move_toward(_shown_score, float(_score),
		maxf(900.0, absf(float(_score) - _shown_score) * 6.0) * delta)
	_canvas.queue_redraw()
	if _pause_panel.visible:
		_pause_panel.queue_redraw()


# --- Drawing ----------------------------------------------------------------

func _draw_hud() -> void:
	# Real viewport, not the reference layout: the danger wash and the countdown
	# both position against the whole screen, and at 1280 they stopped 280 units
	# short of the bottom on a tall phone.
	var size := UIKit.screen_size()
	var w := size.x
	var h := size.y
	var data := UIKit.data_font()
	var display := UIKit.display_font()
	var pulse := Conductor.beat_pulse(5.0) if Conductor.running else 0.0

	# Danger wash. Ramps with proximity and throbs once it is severe, so it
	# competes for attention without being a constant strobe.
	if _danger > 0.01:
		var throb := 1.0 + (pulse * 0.5 if _danger > 0.5 else 0.0)
		_canvas.draw_rect(Rect2(0, 0, w, h),
			Color(UIKit.RED.r, UIKit.RED.g, UIKit.RED.b, _danger * 0.28 * throb), true)

	# Score, top left. Everything in the top bar is offset by the safe-area
	# inset so it clears a notch or Dynamic Island.
	var top := _top_inset
	_canvas.draw_string(data, Vector2(UIKit.MARGIN, 60.0 + top),
		UIKit.thousands(int(_shown_score)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UIKit.TEXT)
	_canvas.draw_string(data, Vector2(UIKit.MARGIN + 2.0, 84.0 + top),
		"%s  %d BPM" % [_song_name, _song_bpm],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIKit.DIM)

	# Height, top right. Right-aligned so the digits form a stable edge as the
	# number grows.
	var block := height_readout_rect()
	_canvas.draw_string(data, Vector2(block.position.x, 60.0 + top), "%d m" % _height,
		HORIZONTAL_ALIGNMENT_RIGHT, block.size.x, 34, UIKit.CYAN)
	_canvas.draw_string(data, Vector2(block.position.x, 84.0 + top), "HEIGHT",
		HORIZONTAL_ALIGNMENT_RIGHT, block.size.x, 15, UIKit.DIM)

	if _countdown >= 0:
		_draw_countdown(display, w, h, pulse)
		return

	_draw_judgement(display, data, w, pulse)


## Judgement and combo as one group, so the player reads a single thing.
func _draw_judgement(display: Font, data: Font, w: float, pulse: float) -> void:
	if _judgement < 0:
		return

	var alpha := 1.0
	if _popup_age > POPUP_HOLD:
		alpha = clampf(1.0 - (_popup_age - POPUP_HOLD) / POPUP_FADE, 0.0, 1.0)

	var y := UIKit.screen_height() * 0.26
	var col := Tuning.judgement_color(_judgement)
	var label := Tuning.judgement_label(_judgement)
	if _judgement_tiers >= Tuning.PERFECT_TIER_SKIP:
		label += "  x2"

	_canvas.draw_string(display, Vector2(0.0, y), label,
		HORIZONTAL_ALIGNMENT_CENTER, w, 54,
		Color(col.r, col.g, col.b, alpha))

	# Which WAY you were wrong, which is the actionable part.
	if _judgement != Tuning.Judgement.PERFECT:
		var ms := int(round(_judgement_error * 1000.0))
		var dir := "LATE" if ms > 0 else "EARLY"
		_canvas.draw_string(data, Vector2(0.0, y + 32.0),
			"%d ms %s" % [absi(ms), dir],
			HORIZONTAL_ALIGNMENT_CENTER, w, 20,
			Color(UIKit.DIM.r, UIKit.DIM.g, UIKit.DIM.b, alpha))

	# Combo sits directly under the judgement, pulsing on the beat.
	if _combo >= 2:
		var mult := mini(1 + int(_combo / Tuning.COMBO_STEP), Tuning.COMBO_MAX_MULT)
		var size := 44 + int(pulse * 5.0)
		_canvas.draw_string(data, Vector2(0.0, y + 92.0),
			"%d" % _combo, HORIZONTAL_ALIGNMENT_CENTER, w, size, UIKit.TEXT)
		_canvas.draw_string(data, Vector2(0.0, y + 118.0),
			"COMBO  x%d" % mult, HORIZONTAL_ALIGNMENT_CENTER, w, 17, UIKit.GOLD)


func _draw_countdown(display: Font, w: float, h: float, pulse: float) -> void:
	var text := str(_countdown) if _countdown > 0 else "GO"
	var size := 150 + int(pulse * 26.0)
	_canvas.draw_string(display, Vector2(0.0, h * 0.44), text,
		HORIZONTAL_ALIGNMENT_CENTER, w, size, UIKit.CYAN)
	_canvas.draw_string(UIKit.data_font(), Vector2(0.0, h * 0.44 + 46.0),
		"jump on the beat", HORIZONTAL_ALIGNMENT_CENTER, w, 20, UIKit.DIM)


func _draw_pause() -> void:
	# Must cover the ENTIRE screen. A pause overlay that leaves the running
	# playfield visible along the bottom edge is the worst version of this bug.
	var size := UIKit.screen_size()
	var w := size.x
	var h := size.y
	var display := UIKit.display_font()
	var data := UIKit.data_font()

	_pause_panel.draw_rect(Rect2(0, 0, w, h),
		Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.88), true)
	_pause_panel.draw_string(display, Vector2(UIKit.MARGIN, h * 0.42),
		"PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 58, UIKit.CYAN)

	_pause_panel.draw_string(data, Vector2(UIKit.MARGIN, h * 0.42 + 34.0),
		"%s  %d BPM" % [_song_name, _song_bpm],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIKit.DIM)


# --- Callbacks from Game ----------------------------------------------------

func on_run_started(song: Dictionary) -> void:
	_song_name = str(song.get("name", ""))
	_song_bpm = int(song.get("bpm", 0))
	_score = 0
	_shown_score = 0.0
	_combo = 0
	_height = 0
	_danger = 0.0
	_judgement = -1
	_countdown = -1
	_pause_panel.visible = false


func on_countdown(beats_remaining: int) -> void:
	_countdown = beats_remaining


func on_countdown_finished() -> void:
	_countdown = -1


func on_tick(
	score: int, combo: int, height_tiers: int, death_y: float, player_y: float
) -> void:
	_score = score
	_combo = combo
	_height = height_tiers

	var gap := (death_y - player_y) / Tuning.PLAYFIELD_HEIGHT
	_danger = clampf(1.0 - gap / 0.55, 0.0, 1.0)
	if not Settings.flash_effects:
		_danger *= 0.4


func on_judged(judgement: int, error: float, _combo: int, tiers: int) -> void:
	_judgement = judgement
	_judgement_error = error
	_judgement_tiers = tiers
	_popup_age = 0.0


func on_paused(paused: bool) -> void:
	_pause_panel.visible = paused
	_pause_button.visible = not paused


func on_run_ended(_result: Dictionary) -> void:
	_judgement = -1
	_countdown = -1
	_combo = 0
