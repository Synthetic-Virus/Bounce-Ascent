extends Node

## Audio playback and the master clock. Autoloaded as `Music`.
##
## Owns the bus layout, the music and SFX players, and get_audio_time(), which
## is the single source of truth for where we are in the song. Synthesis and
## caching live in SongCache; sound effect generation lives in SfxBank.

signal song_ready(song_id: String)
signal all_songs_ready

var _player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _sfx: Dictionary = {}

var _cache: SongCache
var _current_song: Dictionary = {}

## Loop length in seconds, and how many times we have wrapped. The raw playback
## position resets on every loop, but callers need a clock that only increases.
var _loop_length: float = 0.0
var _loop_count: int = 0
var _last_raw_pos: float = 0.0

var _last_time: float = 0.0
var _playing: bool = false

## TRIED AND REJECTED: clamping AudioServer.get_time_since_last_mix().
##
## The reasoning was sound on paper. That correction interpolates WITHIN one mix
## block, so a value larger than a block means the audio thread did not run, and
## adding it counts a stall as music that has played. Bounding it to 50ms should
## have steadied the measured clock rate.
##
## It did not. Across four runs the rate spread went 3.60/2.76/3.53/1.99% before
## and 3.04/3.45/2.99/5.45% after: no improvement, and the specific 95.9% spike
## that motivated it reappeared as 94.25% with the clamp in place. So whatever
## makes this host's clock wander, it is not an oversized mix correction.
##
## Recorded rather than deleted because it is a plausible idea that will occur
## to the next person, and it has already been measured.

# --- Song clock rate --------------------------------------------------------
#
# How fast the song clock runs compared to the wall clock, as a ratio. 1.0 means
# they agree.
#
# THIS IS NOT A TUNING KNOB. It exists because the game solves jump arcs in SONG
# seconds and then simulates them in REAL seconds, and those are two different
# clocks with two different sources: the audio device's own oscillator on one
# side, the system timer driving physics on the other. Nothing reconciled them.
#
# Measured, not assumed: the headless test host runs its song clock about 8.6%
# slow, which made every landing arrive (1 - rate) * flight_time early. On a
# roughly one second hop that is 86ms against a 25ms tolerance, on every single
# hop, and the error scaled with flight time exactly as a rate mismatch must.
# Real devices are far closer to 1.0, but not exactly 1.0, and Bluetooth audio
# is the standard case where they are not: a resampling headset is free to run
# its own clock and the drift is real.
#
# Which clock is "right" does not matter. The player hears beats coming out of
# the audio device, so the arc has to end when the AUDIO clock reaches the beat,
# whatever the system timer thinks. Converting song seconds into the real
# seconds a hop must actually last is what makes that true.

## Shortest span that may be turned into an estimate.
##
## The estimate's error lands directly on the beat as (1 - rate) * flight_time,
## so on a one second hop a 2.5% error in the rate is a 25ms miss. That makes
## the length of this window a timing budget rather than a preference.
##
## 1.5 seconds, not 0.35: a shorter window measured the audio mix block
## granularity as much as the clock and left 30ms residuals on hops whose arcs
## were otherwise delivered to within 3ms. It also matters after the window
## slides, when the previous, longer estimate is held rather than replaced by a
## fresh and much noisier one.
##
## Still short enough to be ready in time. The count-in is four beats, about two
## seconds, so the first hop of a run is always covered by a real measurement
## rather than the 1.0 default.
const RATE_MIN_MEASURE: float = 1.5

## Longest span an estimate is drawn from, after which the window slides.
##
## A window that only ever grows would be more precise but would also take
## minutes to notice a rate that CHANGED, and rates do change: headphones get
## plugged in, a Bluetooth device reconnects, a phone throttles.
const RATE_MAX_WINDOW: float = 6.0

## Samples outside this band are discarded rather than used. A pause, a seek, a
## song change or a stalled audio thread all produce a garbage ratio, and one of
## those reaching the solver would deform every arc that followed.
const RATE_MIN: float = 0.75
const RATE_MAX: float = 1.35

## The estimate is the ratio measured across the whole current window, with NO
## additional smoothing. The window is the filter.
##
## Deliberate: get_audio_time is called at whatever rate the game happens to
## read it, several times per frame in places, so an exponential smoother here
## would converge at a speed that depended on how often it was called. That is
## exactly the kind of quietly frame-rate-dependent behaviour this whole fix
## exists to remove.
var _rate: float = 1.0
var _rate_anchor_time: float = 0.0
var _rate_anchor_usec: int = 0


func _ready() -> void:
	# Autoloads keep running while the tree is paused; the music must not stop
	# when the player opens the pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_setup_buses()
	_setup_players()
	_sfx = SfxBank.build()

	_cache = SongCache.new()
	_cache.name = "SongCache"
	_cache.song_ready.connect(func(id): song_ready.emit(id))
	_cache.all_ready.connect(func(): all_songs_ready.emit())
	add_child(_cache)
	_cache.start()


# --- Buses ------------------------------------------------------------------

## Defined in code rather than as a default_bus_layout.tres so the project
## cannot ship a resource missing a bus the scripts expect.
func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _setup_players() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)

	# A pool, because rhythm feedback fires often enough that one player would
	# cut off its own previous sound.
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_players.append(p)


# --- Availability -----------------------------------------------------------

func is_song_ready(song_id: String) -> bool:
	return _cache != null and _cache.is_ready(song_id)


func all_ready() -> bool:
	return _cache != null and _cache.all_songs_ready()


# --- Playback ---------------------------------------------------------------

## Start a song from the beginning. Returns false if it has not rendered yet, in
## which case the caller should wait on song_ready.
func play_song(song: Dictionary) -> bool:
	var stream := _cache.get_stream(song["id"]) if _cache != null else null
	if stream == null:
		return false

	_current_song = song
	_loop_length = float(stream.loop_end) / float(stream.mix_rate)
	_loop_count = 0
	_last_raw_pos = 0.0
	_last_time = 0.0

	_player.stream = stream
	_player.play()
	_playing = true
	_reanchor_rate()
	return true


func stop_song() -> void:
	_player.stop()
	_playing = false
	_last_time = 0.0
	_loop_count = 0
	_last_raw_pos = 0.0
	_reanchor_rate()


func set_paused(paused: bool) -> void:
	_player.stream_paused = paused
	# Re-anchor across a pause. The song clock stops while the wall clock does
	# not, so a window spanning the pause would measure a rate near zero and,
	# without this, drag the estimate down for several seconds after resuming.
	_reanchor_rate()


func is_playing() -> bool:
	return _playing and _player.playing


func current_song() -> Dictionary:
	return _current_song


# --- The clock --------------------------------------------------------------

## Seconds since the song started, counting past loop boundaries, with every
## latency correction applied. This is THE clock.
##
## Three corrections, and getting any of them wrong produces a game that "feels
## off" rather than an obvious bug:
##
##   + time_since_last_mix   the playback position only updates once per mix
##                           block, so it is stale between mixes
##   - output_latency        audio that is mixed has not been HEARD yet, and the
##                           player reacts to what they hear
##   - Settings offset       everything downstream of Godot: OS mixer, Bluetooth,
##                           display audio processing
func get_audio_time() -> float:
	if not _playing or not _player.playing:
		return _last_time

	var raw: float = _player.get_playback_position()

	# A large backwards jump means the stream looped rather than seeked.
	if _loop_length > 0.0 and raw < _last_raw_pos - (_loop_length * 0.5):
		_loop_count += 1
	_last_raw_pos = raw

	var t: float = raw + float(_loop_count) * _loop_length
	t += AudioServer.get_time_since_last_mix()
	t -= AudioServer.get_output_latency()
	t -= Settings.audio_offset_seconds()
	t = maxf(t, 0.0)

	# Never run backwards: one backwards step would repeat a beat index and fire
	# a duplicate beat signal.
	_last_time = maxf(t, _last_time)
	_update_rate(_last_time)
	return _last_time


# --- Song clock rate --------------------------------------------------------

## Song seconds per wall-clock second. See the constants above for why.
##
## Starts at 1.0 and stays there until a full window has been measured, so a run
## that begins before any estimate exists behaves exactly as it did before.
func clock_rate() -> float:
	return _rate


## Real seconds a span of song seconds will actually take.
##
## The conversion every solved arc needs: a hop must last long enough in REAL
## time for the SONG clock to reach the beat it was aimed at.
func song_to_real(song_seconds: float) -> float:
	return song_seconds / _rate


## Start a fresh measurement window WITHOUT discarding what is already known.
##
## The rate is a property of the hardware, not of the song, so it survives a
## stop, a restart and a change of track. Throwing it away would put the first
## seconds of every run back on the unmeasured 1.0 default, which is precisely
## when a player is least able to absorb a mistimed hop.
func _reanchor_rate() -> void:
	_rate_anchor_usec = 0


## Recompute the estimate from the current window.
func _update_rate(song_now: float) -> void:
	var usec := Time.get_ticks_usec()

	if _rate_anchor_usec == 0:
		_rate_anchor_time = song_now
		_rate_anchor_usec = usec
		return

	var real_elapsed := float(usec - _rate_anchor_usec) / 1_000_000.0
	if real_elapsed < RATE_MIN_MEASURE:
		return

	var sample := (song_now - _rate_anchor_time) / real_elapsed
	if sample >= RATE_MIN and sample <= RATE_MAX:
		_rate = sample

	# Slide the window once it is full. The estimate carries over, so nothing
	# jumps: the next window simply refines it from a more recent baseline.
	if real_elapsed >= RATE_MAX_WINDOW:
		_rate_anchor_time = song_now
		_rate_anchor_usec = usec


# --- Sound effects ----------------------------------------------------------

func play_sfx(sfx_name: String) -> void:
	if not _sfx.has(sfx_name):
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = _sfx[sfx_name]
	p.play()
