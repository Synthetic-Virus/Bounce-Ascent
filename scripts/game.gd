extends Node2D

## Gameplay orchestrator. Owns a single run from countdown to death.
##
## RUN LIFECYCLE
## -------------
##   1. COUNTDOWN  music starts, the Conductor clock runs, but the player is
##                 frozen and the death line is not advancing. Four beats of
##                 count-in so the player can hear the tempo before they have
##                 to hit it. Starting a rhythm game cold is the single most
##                 common way to make the first ten seconds feel unfair.
##   2. PLAYING    the climb.
##   3. DEAD       results are submitted and the game over screen takes over.
##
## The score model lives here rather than in an autoload because it is entirely
## per-run state; only the final result is persisted, via Scores.

signal run_ended(result: Dictionary)

enum State { COUNTDOWN, PLAYING, PAUSED, DEAD }

## How many beats of count-in before the player is released.
const COUNTIN_BEATS: int = 4

## Where the player starts, in world space.
const START_POSITION := Vector2(Tuning.PLAYFIELD_WIDTH * 0.5, 0.0)

var state: State = State.COUNTDOWN

## The song being played.
var song: Dictionary = {}

# --- Run statistics ---------------------------------------------------------

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var highest_tier: int = 0
## Judgement counts, indexed by Tuning.Judgement.
var judgement_counts: Array[int] = [0, 0, 0, 0]

## Beat index at which the count-in ends. Constant: the count-in always starts
## at beat 0 because Conductor.start() resets the clock.
const RELEASE_BEAT: int = COUNTIN_BEATS

const MenuScene: String = "res://scenes/MainMenu.tscn"

@onready var _player: CharacterBody2D = $Player
@onready var _spawner: Node2D = $PlatformSpawner
@onready var _camera: Camera2D = $GameCamera
@onready var _ui: CanvasLayer = $GameUI
@onready var _game_over: CanvasLayer = $GameOver
@onready var _background: Node2D = $Background
@onready var _death_zone: Node2D = $DeathZone


func _ready() -> void:
	# REQUIRED, not an optimisation: get_tree().paused stops PAUSABLE nodes
	# receiving input, and this node owns the pause key. With the default mode
	# it pauses and then stops listening, trapping the player on the pause
	# screen. Children stay PAUSABLE and correctly freeze.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player.jumped.connect(_on_player_jumped)
	_player.died.connect(_on_player_died)
	_game_over.restart_requested.connect(_on_restart_requested)
	_game_over.menu_requested.connect(_on_menu_requested)

	# The HUD's on-screen pause control and pause-menu buttons, so a touch
	# player has the same options a keyboard player does.
	_ui.pause_requested.connect(func(): if state == State.PLAYING: _toggle_pause())
	_ui.resume_requested.connect(func(): if state == State.PAUSED: _toggle_pause())
	_ui.restart_requested.connect(_on_restart_requested)
	_ui.menu_requested.connect(_on_menu_requested)

	var song_id: String = Settings.last_song_id
	song = SongLibrary.get_song(song_id)

	start_run()


func _on_restart_requested() -> void:
	_game_over.hide_panel()
	# A restart can be requested from the pause menu as well as from death, so
	# unpausing here is not redundant -- leaving the tree paused would freeze
	# the fresh run on its first frame.
	get_tree().paused = false
	start_run()


func _on_menu_requested() -> void:
	get_tree().paused = false
	Music.stop_song()
	Conductor.stop()
	get_tree().change_scene_to_file(MenuScene)


## Begin a run. Safe to call again for a restart without reloading the scene.
func start_run() -> void:
	score = 0
	combo = 0
	max_combo = 0
	highest_tier = 0
	judgement_counts = [0, 0, 0, 0]
	state = State.COUNTDOWN
	_game_over.hide_panel()

	# Capture how the device is being held right now as tilt centre. The
	# count-in is the one moment in a run when the player is reliably still and
	# not steering, which makes it the only good time to ask.
	var touch := get_node_or_null("TouchControls")
	if touch != null and touch.has_method("recentre_tilt"):
		touch.recentre_tilt()

	# Tier 0 sits at START_POSITION.y and the player starts resting ON it, not
	# hovering above it. A 2px gap lets the body settle onto the surface within
	# a frame; any larger and the run would open with an unquantised free fall.
	_spawner.reset(START_POSITION.y)
	_player.reset(START_POSITION - Vector2(
		0.0, Tuning.PLATFORM_HALF_HEIGHT + _player.RADIUS + 2.0))
	_camera.reset(_player.global_position.y)
	# Seed the player's copy immediately rather than waiting for the first
	# _process_playing tick. Physics runs at 120Hz and can fire between the
	# count-in ending and the next _process, so "it will be set shortly" is not
	# good enough for a value that decides whether the player is alive.
	_player.death_y = _camera.death_line_y()

	# Freeze the player through the count-in.
	_player.active = false

	_ui.on_run_started(song)

	Conductor.start(song)
	if not Music.play_song(song):
		# Not rendered yet. Unreachable via the menu, which gates Play on
		# readiness, but reachable by running Game.tscn directly with F6, so it
		# has to behave rather than error. Hold in COUNTDOWN until it lands.
		state = State.COUNTDOWN
		if not Music.song_ready.is_connected(_on_song_became_ready):
			Music.song_ready.connect(_on_song_became_ready)


## Retry the start once the background synthesis delivers our song.
func _on_song_became_ready(song_id: String) -> void:
	if song_id != song.get("id", ""):
		return
	Music.song_ready.disconnect(_on_song_became_ready)
	# Restart cleanly rather than resuming: the Conductor clock has been running
	# against silence, so its beat count is meaningless and must be reset.
	start_run()


func _process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_process_countdown()
		State.PLAYING:
			_process_playing(delta)
		_:
			pass


func _process_countdown() -> void:
	var beats_remaining := RELEASE_BEAT - int(floor(Conductor.song_beats))
	_ui.on_countdown(maxi(beats_remaining, 0))

	if Conductor.song_beats >= float(RELEASE_BEAT):
		state = State.PLAYING
		_player.active = true
		# Release lands on a beat, so arming here puts hop one on the grid.
		_player.arm_first_jump()
		_camera.scrolling = true
		_ui.on_countdown_finished()


func _process_playing(delta: float) -> void:
	highest_tier = maxi(highest_tier, _player.current_tier)

	_camera.update_camera(delta, _player.global_position.y, _player.current_tier)
	_player.death_y = _camera.death_line_y()
	_spawner.update_for(_player.current_tier, _camera.bottom_y())

	_background.set_scroll(_camera.top_y())
	_death_zone.set_line(_camera.death_line_y())
	_ui.on_tick(score, combo, highest_tier, _camera.death_line_y(),
		_player.global_position.y)


func _unhandled_input(event: InputEvent) -> void:
	# While dead, the GameOver overlay owns input (it runs on a higher canvas
	# layer and marks events handled), so there is nothing to do here.
	if event.is_action_pressed("pause") and state in [State.PLAYING, State.PAUSED]:
		_toggle_pause()
	elif event.is_action_pressed("restart") and state == State.PAUSED:
		_on_restart_requested()


## Auto-pause on focus loss. Without it, alt-tabbing leaves the death line
## rising and the auto-launch firing, so the player comes back dead.
##
## Deliberately does not auto-resume: being dropped straight back into a running
## climb gives no chance to re-find the beat.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAYING:
		_toggle_pause()


func _toggle_pause() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
		get_tree().paused = true
		Music.set_paused(true)
		_ui.on_paused(true)
	elif state == State.PAUSED:
		state = State.PLAYING
		get_tree().paused = false
		Music.set_paused(false)
		_ui.on_paused(false)


# --- Scoring ----------------------------------------------------------------

func _on_player_jumped(judgement: int, error: float, tiers: int) -> void:
	judgement_counts[judgement] += 1

	if judgement == Tuning.Judgement.MISS:
		combo = 0
		Music.play_sfx("miss")
	else:
		combo += 1
		max_combo = maxi(max_combo, combo)
		# Multiplier grows one step per COMBO_STEP successful jumps, capped so
		# that a long run does not make the early game irrelevant.
		var mult := mini(1 + int(combo / Tuning.COMBO_STEP), Tuning.COMBO_MAX_MULT)
		score += Tuning.score_for(judgement) * mult

		match judgement:
			Tuning.Judgement.PERFECT:
				Music.play_sfx("perfect")
				_camera.add_shake(6.0)
			Tuning.Judgement.GREAT:
				Music.play_sfx("great")
			_:
				Music.play_sfx("good")

	_ui.on_judged(judgement, error, combo, tiers)


func _on_player_died() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	Music.play_sfx("death")
	Conductor.stop()
	Music.stop_song()
	_camera.add_shake(14.0)

	var result := _build_result()
	Scores.submit(
		song["id"], result["score"], result["height"],
		result["max_combo"], result["accuracy"]
	)
	_ui.on_run_ended(result)
	_game_over.show_result(result)
	run_ended.emit(result)


## Assemble the end-of-run summary.
func _build_result() -> Dictionary:
	var total := 0
	for c in judgement_counts:
		total += c

	# Weighted accuracy: PERFECT counts full, GREAT two thirds, GOOD one third,
	# MISS nothing. A plain hit-rate would report 100% for a run of nothing but
	# barely-inside-the-window GOODs, which is not what the player did.
	var weighted := (
		float(judgement_counts[Tuning.Judgement.PERFECT]) * 1.0
		+ float(judgement_counts[Tuning.Judgement.GREAT]) * 0.667
		+ float(judgement_counts[Tuning.Judgement.GOOD]) * 0.333
	)
	var accuracy := (weighted / float(total)) * 100.0 if total > 0 else 0.0

	return {
		"song_id": song.get("id", ""),
		"song_name": song.get("name", ""),
		"score": score,
		"height": highest_tier,
		"max_combo": max_combo,
		"accuracy": accuracy,
		"perfect": judgement_counts[Tuning.Judgement.PERFECT],
		"great": judgement_counts[Tuning.Judgement.GREAT],
		"good": judgement_counts[Tuning.Judgement.GOOD],
		"miss": judgement_counts[Tuning.Judgement.MISS],
		"is_best": Scores.is_new_best(song.get("id", ""), score),
	}
