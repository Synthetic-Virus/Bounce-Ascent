extends Node

## Musical time. Autoloaded as `Conductor`.
##
## Music owns the raw audio clock; this turns it into beats, bars and timing
## judgements. Nothing outside this file should do arithmetic on seconds per
## beat.
##
## The clock is READ every frame, never accumulated from delta. Frame delta
## measures the renderer while audio runs on its own crystal, and the two
## disagree by a small relentless amount that compounds into audible desync.

signal beat(beat_index: int)
signal downbeat(bar_index: int)
signal judged(judgement: int, error: float)

var bpm: float = 120.0
var sec_per_beat: float = 0.5
var beats_per_bar: int = 4
var running: bool = false

## Song position in beats. The fractional part drives visual pulsing.
var song_beats: float = 0.0

## Song position in seconds as of the last _process. Fine for visuals, NOT for
## judging input: use now().
var song_time: float = 0.0

## Bound on beat signals emitted in one frame while catching up, so a large
## clock jump resynchronises silently instead of freezing the frame.
const MAX_BEAT_CATCHUP: int = 16

var _last_beat_emitted: int = -1


func _ready() -> void:
	# Must keep ticking while paused, so resuming does not fire a burst of
	# catch-up beats.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


## Bind to a song and reset. Call immediately before Music.play_song().
func start(song: Dictionary) -> void:
	bpm = song.get("bpm", 120.0)
	beats_per_bar = song.get("beats_per_bar", 4)
	sec_per_beat = Tuning.sec_per_beat(bpm)
	song_beats = 0.0
	song_time = 0.0
	_last_beat_emitted = -1
	running = true


func stop() -> void:
	running = false


func _process(_delta: float) -> void:
	if not running:
		return

	song_time = Music.get_audio_time()
	song_beats = song_time / sec_per_beat

	var current: int = int(floor(song_beats))
	if current - _last_beat_emitted > MAX_BEAT_CATCHUP:
		_last_beat_emitted = current - 1

	while _last_beat_emitted < current:
		_last_beat_emitted += 1
		beat.emit(_last_beat_emitted)
		if _last_beat_emitted % beats_per_bar == 0:
			downbeat.emit(_last_beat_emitted / beats_per_bar)


## The song position right now, sampled fresh. Use for anything timing-critical.
##
## `song_time` only updates in _process, but input is sampled in
## _unhandled_input (which runs BEFORE _process, so it is a full frame stale)
## and landings are detected in _physics_process at 120Hz. Reading through here
## decouples judgement accuracy from the render frame rate.
func now() -> float:
	if not running:
		return song_time
	return Music.get_audio_time()


# --- Conversions ------------------------------------------------------------

func beat_to_time(beat_index: float) -> float:
	return beat_index * sec_per_beat


func time_to_beat(t: float) -> float:
	return t / sec_per_beat


func beat_progress() -> float:
	return song_beats - floorf(song_beats)


## Spikes to 1.0 on each beat and decays. A raw beat_progress() ramp reads as a
## sawtooth sweep rather than a pulse.
func beat_pulse(sharpness: float = 3.0) -> float:
	return pow(1.0 - beat_progress(), sharpness)


func bar_pulse(sharpness: float = 2.0) -> float:
	var bar_beats: float = fmod(song_beats, float(beats_per_bar))
	return pow(1.0 - (bar_beats / float(beats_per_bar)), sharpness)


# --- Judgement --------------------------------------------------------------

## Judge an input that happened at song time `press_time`.
##
## Returns { judgement, error, beat_index }. `error` is signed: negative early,
## positive late, which the calibration screen averages into an audio offset.
##
## Judged against the NEAREST beat rather than a predicted one: if the player
## lingers and jumps a beat later than usual that is still musically correct and
## should still score.
func judge(press_time: float) -> Dictionary:
	var beat_float: float = press_time / sec_per_beat
	var nearest: int = int(round(beat_float))
	var error: float = press_time - (float(nearest) * sec_per_beat)
	var abs_error: float = absf(error)

	var judgement: int
	if abs_error <= Tuning.WINDOW_PERFECT:
		judgement = Tuning.Judgement.PERFECT
	elif abs_error <= Tuning.WINDOW_GREAT:
		judgement = Tuning.Judgement.GREAT
	elif abs_error <= Tuning.WINDOW_GOOD:
		judgement = Tuning.Judgement.GOOD
	else:
		judgement = Tuning.Judgement.MISS

	judged.emit(judgement, error)
	return {"judgement": judgement, "error": error, "beat_index": nearest}


func judge_now() -> Dictionary:
	return judge(now())
