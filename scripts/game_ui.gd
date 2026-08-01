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

var _canvas: Control
var _pause_panel: Control

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
	ruler.size = Vector2(UIKit.RULER_WIDTH, Tuning.PLAYFIELD_HEIGHT)
	_canvas.add_child(ruler)

	_pause_panel = Control.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_panel.draw.connect(_draw_pause)
	_pause_panel.visible = false
	add_child(_pause_panel)

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
	var w := Tuning.PLAYFIELD_WIDTH
	var h := Tuning.PLAYFIELD_HEIGHT
	var data := UIKit.data_font()
	var display := UIKit.display_font()
	var pulse := Conductor.beat_pulse(5.0) if Conductor.running else 0.0

	# Danger wash. Ramps with proximity and throbs once it is severe, so it
	# competes for attention without being a constant strobe.
	if _danger > 0.01:
		var throb := 1.0 + (pulse * 0.5 if _danger > 0.5 else 0.0)
		_canvas.draw_rect(Rect2(0, 0, w, h),
			Color(UIKit.RED.r, UIKit.RED.g, UIKit.RED.b, _danger * 0.28 * throb), true)

	# Score, top left.
	_canvas.draw_string(data, Vector2(UIKit.MARGIN, 60.0),
		UIKit.thousands(int(_shown_score)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UIKit.TEXT)
	_canvas.draw_string(data, Vector2(UIKit.MARGIN + 2.0, 84.0),
		"%s  %d BPM" % [_song_name, _song_bpm],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIKit.DIM)

	# Height, top right. Right-aligned so the digits form a stable edge as the
	# number grows.
	var right := w - UIKit.MARGIN - 200.0
	_canvas.draw_string(data, Vector2(right, 60.0), "%d m" % _height,
		HORIZONTAL_ALIGNMENT_RIGHT, 200.0, 34, UIKit.CYAN)
	_canvas.draw_string(data, Vector2(right, 84.0), "HEIGHT",
		HORIZONTAL_ALIGNMENT_RIGHT, 200.0, 15, UIKit.DIM)

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

	var y := Tuning.PLAYFIELD_HEIGHT * 0.26
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
	var w := Tuning.PLAYFIELD_WIDTH
	var h := Tuning.PLAYFIELD_HEIGHT
	var display := UIKit.display_font()
	var data := UIKit.data_font()

	_pause_panel.draw_rect(Rect2(0, 0, w, h),
		Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.88), true)
	_pause_panel.draw_string(display, Vector2(UIKit.MARGIN, h * 0.42),
		"PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 58, UIKit.CYAN)

	# Actions named by what they do, in the same voice as every other screen.
	var y := h * 0.42 + 60.0
	for row in [["ESC", "resume climbing"], ["R", "restart this track"]]:
		_pause_panel.draw_string(data, Vector2(UIKit.MARGIN, y), str(row[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIKit.GOLD)
		_pause_panel.draw_string(data, Vector2(UIKit.MARGIN + 60.0, y), str(row[1]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIKit.TEXT)
		y += 36.0


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


func on_run_ended(_result: Dictionary) -> void:
	_judgement = -1
	_countdown = -1
	_combo = 0
