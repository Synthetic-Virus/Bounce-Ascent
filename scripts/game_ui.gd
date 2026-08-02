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

## Lead over the death line in tiers: a fast reading for the number, a slow one
## to difference against, and the resulting trend. Negative until the first tick
## so the first frame does not animate up from zero.
var _lead_shown: float = -1.0
var _lead_slow: float = -1.0
var _lead_trend: float = 0.0

## Seconds remaining on the "+1" flourish that fires when a PERFECT is landed.
var _lead_gain_flash: float = 0.0

# --- Coaching ----------------------------------------------------------------
#
# A first-time player is taught DURING their first run, by things that happen,
# rather than by a screen of text before it.
#
# This replaces relying on the How to play page. The evidence is consistent that
# effective onboarding is interactive, that players learn by doing rather than
# reading, and that a streamlined introduction is worth 20-25% more retained
# players in week one, which is more than any amount of visual polish is worth.
# See docs/DESIGN_RESEARCH.md.
#
# Each lesson fires ONCE, only when the thing it describes has actually just
# happened to the player, and only on their first run. There is no tutorial to
# skip and nothing to dismiss.

var _teaching: bool = false
var _lessons_seen: Dictionary = {}
var _coach_text: String = ""
var _coach_age: float = 999.0

# --- Beat assist -------------------------------------------------------------
#
# On the easiest track only, a player who keeps mistiming gets the beat shown to
# them: a large TAP that flashes exactly ON each beat, so the moment to press is
# not something they have to infer.
#
# The approach ring shows the beat COMING; this shows it ARRIVING. Together they
# cover both halves of "when do I press", which is the entire skill the game
# asks for and the one thing it never actually showed.
#
# It turns itself off the instant they land a PERFECT. An assist that stays up
# after the player no longer needs it stops being help and starts being noise,
# and it would also rob them of the moment they worked out the timing.

## Difficulty of the running track. Assist is easiest-track only, deliberately:
## on the harder tracks a player has already demonstrated they can do this.
var _song_difficulty: int = 0

var _miss_streak: int = 0
var _assist_active: bool = false

const COACH_HOLD: float = 2.2
const COACH_FADE: float = 0.6


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
	_coach_age += delta
	_lead_gain_flash = maxf(_lead_gain_flash - delta * 1.4, 0.0)
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

	_draw_lead(data, top)
	_draw_judgement(display, data, w, pulse)
	_draw_assist(display, w, h)
	_draw_coach(data, w, h)


## TAP, flashing exactly ON the beat, for a player who cannot find it.
##
## Peaks at the beat rather than fading from it, which is the opposite of every
## other pulse in the game: those celebrate a beat that has happened, this one
## marks the instant to act. Paired with the approach ring around the player,
## which shows the same beat arriving, the two answer "when do I press" from
## both directions.
##
## Only on the easiest track, only after repeated mistiming, and it disappears
## the moment a PERFECT lands.
func _draw_assist(display: Font, w: float, h: float) -> void:
	if not _assist_active or not Conductor.running:
		return

	# Sharp, so the word is unmistakably ON the beat rather than glowing near it.
	var beat := Conductor.beat_pulse(6.0)
	var alpha := 0.25 + beat * 0.75
	var size := 46 + int(beat * 12.0)

	_canvas.draw_string(display, Vector2(0.0, h * 0.50), "TAP",
		HORIZONTAL_ALIGNMENT_CENTER, w, size,
		Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, alpha))


## One short line of coaching, low on the screen.
##
## Placed BELOW the player rather than above. The judgement popup already owns
## the upper third and the player's eye is on the platform they are aiming at;
## a second message up there competes with the first for the same glance. Low
## and centred is peripheral, which is what a hint should be.
func _draw_coach(data: Font, w: float, h: float) -> void:
	if _coach_text.is_empty() or _coach_age > COACH_HOLD + COACH_FADE:
		return

	var alpha := 1.0
	if _coach_age > COACH_HOLD:
		alpha = clampf(1.0 - (_coach_age - COACH_HOLD) / COACH_FADE, 0.0, 1.0)
	# Ease in as well, so it arrives rather than blinks into existence.
	alpha *= clampf(_coach_age / 0.18, 0.0, 1.0)

	_canvas.draw_string(data, Vector2(0.0, h * 0.78), _coach_text,
		HORIZONTAL_ALIGNMENT_CENTER, w, 22,
		Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, alpha))


## LEAD: how far ahead of the death line the player is, and which way it is going.
##
## The single most important readout in the game after the judgement itself, and
## it did not exist. A PERFECT climbs two tiers in the time an ordinary hop
## climbs one, so timing well pushes the line away and ordinary timing eventually
## does not. That is the entire skill proposition, and it was invisible: the
## player saw a red wash arrive and a run end, with no way to connect either to
## anything they did.
##
## Doodle Jump gets this for free, because you die by missing a platform and the
## cause is self-evident. A rising line has to explain itself or it reads as a
## timer running out. See docs/DESIGN_RESEARCH.md.
func _draw_lead(data: Font, top: float) -> void:
	if _lead_shown < 0.0:
		return

	var tiers := maxi(int(round(_lead_shown)), 0)

	# Colour IS the message: gaining ground is cyan, holding is dim, losing is
	# red. A player who never reads the word still learns that red means their
	# timing has stopped being good enough.
	var col := UIKit.DIM
	var word := "holding"
	if _lead_trend > 0.12:
		col = UIKit.CYAN
		word = "gaining"
	elif _lead_trend < -0.12:
		col = UIKit.RED
		word = "losing"

	var y := 116.0 + top
	var x := UIKit.MARGIN

	_canvas.draw_string(data, Vector2(x, y), "LEAD",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.DIM)
	_canvas.draw_string(data, Vector2(x + 44.0, y), "%d" % tiers,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
	_canvas.draw_string(data, Vector2(x + 82.0, y), word,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)

	# The flourish that closes the causal loop: a PERFECT bought an extra tier,
	# so say so, here, where the consequence is displayed. The judgement popup
	# already says the timing was good; this says what the timing was FOR.
	if _lead_gain_flash > 0.0:
		var rise := (1.0 - _lead_gain_flash) * 14.0
		_canvas.draw_string(data, Vector2(x + 150.0, y - rise), "+1",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(UIKit.GOLD.r, UIKit.GOLD.g, UIKit.GOLD.b, _lead_gain_flash))


## Judgement and combo as one group, so the player reads a single thing.
func _draw_judgement(display: Font, data: Font, w: float, pulse: float) -> void:
	if _judgement < 0:
		return

	var alpha := 1.0
	if _popup_age > POPUP_HOLD:
		alpha = clampf(1.0 - (_popup_age - POPUP_HOLD) / POPUP_FADE, 0.0, 1.0)

	var y := UIKit.screen_height() * 0.26
	var col := Tuning.judgement_color(_judgement)
	var label := Tuning.judgement_label(_judgement, _judgement_error)
	if _judgement_tiers >= Tuning.PERFECT_TIER_SKIP:
		label += "  x2"

	_canvas.draw_string(display, Vector2(0.0, y), label,
		HORIZONTAL_ALIGNMENT_CENTER, w, 54,
		Color(col.r, col.g, col.b, alpha))

	# How far off, which is the actionable part.
	#
	# The direction used to be repeated here as well as being obvious from the
	# error sign, and now the bottom tier's own label says LATE or EARLY, so
	# printing it twice would be three statements of one fact stacked vertically.
	if _judgement != Tuning.Judgement.PERFECT:
		var ms := absi(int(round(_judgement_error * 1000.0)))
		var detail := "%d ms" % ms
		if _judgement != Tuning.Judgement.MISS:
			detail = "%d ms %s" % [ms, "late" if _judgement_error > 0.0 else "early"]
		_canvas.draw_string(data, Vector2(0.0, y + 32.0), detail,
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
	_song_difficulty = int(song.get("difficulty", 0))
	_miss_streak = 0
	_assist_active = false
	_score = 0
	_shown_score = 0.0
	_combo = 0
	_height = 0
	_danger = 0.0
	_judgement = -1
	_countdown = -1
	_lead_shown = -1.0
	_lead_slow = -1.0
	_lead_trend = 0.0
	_lead_gain_flash = 0.0
	_coach_text = ""
	_coach_age = 999.0
	_pause_panel.visible = false


## Turn coaching on for this run. Game decides, from whether the player has ever
## finished one.
func set_teaching(on: bool) -> void:
	_teaching = on
	_lessons_seen.clear()


## Show a lesson, once per run, and only while teaching.
##
## Keyed so a lesson cannot repeat: the second PERFECT of a run should feel like
## a win, not like the game explaining the same thing again.
func _teach(key: String, text: String) -> void:
	if not _teaching or _lessons_seen.has(key):
		return
	_lessons_seen[key] = true
	_coach_text = text
	_coach_age = 0.0


func on_countdown(beats_remaining: int) -> void:
	_countdown = beats_remaining


func on_countdown_finished() -> void:
	_countdown = -1
	# The instruction arrives as the player is released, not before. Four short
	# words, phrased as the action to take.
	_teach("start", "Tap on every beat")


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

	# Lead over the death line, in tiers, and which way it is moving.
	#
	# This is the game's central cause-and-effect made visible. A PERFECT climbs
	# two tiers in the time an ordinary hop climbs one, so timing well pushes the
	# line away and timing ordinarily eventually does not. That relationship was
	# real but invisible: it existed only in the physics and in one line of a
	# text screen, so a death read as a timer expiring rather than as a
	# consequence.
	#
	# Smoothed, because the raw gap oscillates by most of a tier over every
	# single hop as the player rises and falls. An indicator that flickers
	# between gaining and losing twice a second teaches nothing.
	var lead := (death_y - player_y) / Tuning.TIER_RISE
	if _lead_shown < 0.0:
		_lead_shown = lead
		_lead_slow = lead
	_lead_shown = lerpf(_lead_shown, lead, 0.18)
	_lead_slow = lerpf(_lead_slow, lead, 0.02)
	_lead_trend = _lead_shown - _lead_slow

	# Taught the first time the player is actually losing ground, which is the
	# only moment the sentence means anything. Explaining the death line before
	# it is chasing them is explaining a rule with no referent.
	if _lead_trend < -0.12:
		_teach("losing", "The line is gaining. PERFECTs outrun it.")


func on_judged(judgement: int, error: float, _combo: int, tiers: int) -> void:
	_judgement = judgement
	_judgement_error = error
	_judgement_tiers = tiers

	# Fire the flourish on the LEAD readout, not just the judgement popup. The
	# popup says "you timed well"; this says "and here is what it bought you",
	# which is the half the player could not previously see.
	if tiers >= Tuning.PERFECT_TIER_SKIP:
		_lead_gain_flash = 0.9

	# The central rule, taught at the exact moment the player has just done it.
	# It cannot be discovered by playing: you can jump whenever, climb steadily,
	# and never notice that timing decides how HIGH you go rather than just
	# whether you survive.
	# Struggle tracking for the beat assist. A PERFECT is the only thing that
	# clears it: landing a GREAT still means the timing has not clicked yet.
	if judgement == Tuning.Judgement.PERFECT:
		_miss_streak = 0
		_assist_active = false
	elif judgement == Tuning.Judgement.MISS:
		_miss_streak += 1
		if _song_difficulty <= 0 and _miss_streak >= Tuning.ASSIST_AFTER_MISSES:
			_assist_active = true

	if judgement == Tuning.Judgement.PERFECT:
		_teach("perfect", "PERFECT climbs two platforms")
	elif judgement == Tuning.Judgement.MISS:
		# Corrective, and in the direction that fixes it. "Tap sooner" is an
		# instruction; "MISS" was a verdict.
		if error > 0.0:
			_teach("late", "That was late. Tap sooner.")
		else:
			_teach("early", "That was early. Wait for the beat.")
	_popup_age = 0.0


func on_paused(paused: bool) -> void:
	_pause_panel.visible = paused
	_pause_button.visible = not paused


func on_run_ended(_result: Dictionary) -> void:
	_judgement = -1
	_countdown = -1
	_combo = 0
