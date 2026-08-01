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
	return true


func stop_song() -> void:
	_player.stop()
	_playing = false
	_last_time = 0.0
	_loop_count = 0
	_last_raw_pos = 0.0


func set_paused(paused: bool) -> void:
	_player.stream_paused = paused


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
	return _last_time


# --- Sound effects ----------------------------------------------------------

func play_sfx(sfx_name: String) -> void:
	if not _sfx.has(sfx_name):
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = _sfx[sfx_name]
	p.play()
