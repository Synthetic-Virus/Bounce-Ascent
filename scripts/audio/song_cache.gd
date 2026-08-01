class_name SongCache
extends Node

## Renders songs on a background thread and caches them to disk.
##
## Rendering a song takes roughly two seconds, so it happens off the main thread
## while the menu is up and is then cached to user:// forever. See
## docs/ARCHITECTURE.md for why synthesis is offline rather than live.

signal song_ready(song_id: String)
signal all_ready

const CACHE_DIR: String = "user://cache"
const CACHE_FORMAT_VERSION: int = 1
const CACHE_MAGIC: int = 0x42415343  # "BASC"

var _streams: Dictionary = {}
var _thread: Thread
var _running: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)


func _exit_tree() -> void:
	# A running Thread at free time is a hard crash in Godot, so this is not
	# optional.
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


## Begin rendering every song that is not already cached.
func start() -> void:
	if _running:
		return
	_running = true
	_thread = Thread.new()
	if _thread.start(_worker) != OK:
		# Threading unavailable, e.g. a single-threaded web export. Render
		# inline instead: the first launch hitches but the game still works.
		push_warning("SongCache: no thread available, rendering inline")
		_running = false
		_worker()


func is_ready(song_id: String) -> bool:
	return _streams.has(song_id)


func all_songs_ready() -> bool:
	return _streams.size() >= SongLibrary.all_songs().size()


func get_stream(song_id: String) -> AudioStreamWAV:
	return _streams.get(song_id)


## Runs on the background thread. Must not touch the scene tree.
func _worker() -> void:
	for song in SongLibrary.all_songs():
		var stream: AudioStreamWAV = _load(song)
		if stream == null:
			stream = Synth.render_song(song)
			_save(song, stream)
		_on_rendered.call_deferred(song["id"], stream)
	_on_complete.call_deferred()


func _on_rendered(song_id: String, stream: AudioStreamWAV) -> void:
	_streams[song_id] = stream
	song_ready.emit(song_id)


func _on_complete() -> void:
	_running = false
	all_ready.emit()


## Cache path, keyed by the song definition AND Synth.RENDER_VERSION.
##
## The definition alone would not notice changes to the synthesiser itself, so
## editing synth.gd would leave every render stale forever.
func _path_for(song: Dictionary) -> String:
	return "%s/%s_%d_r%d_%d.pcm" % [
		CACHE_DIR, song["id"], CACHE_FORMAT_VERSION,
		Synth.RENDER_VERSION, JSON.stringify(song).hash()
	]


func _load(song: Dictionary) -> AudioStreamWAV:
	var path := _path_for(song)
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null

	# Validate the header before trusting the payload: a file truncated by an
	# interrupted first launch would otherwise play as a burst of noise.
	if f.get_32() != CACHE_MAGIC or f.get_32() != CACHE_FORMAT_VERSION:
		return null
	var mix_rate := f.get_32()
	var stereo := f.get_32() != 0
	var loop_end := f.get_32()
	var byte_count := f.get_32()
	var data := f.get_buffer(byte_count)
	if data.size() != byte_count:
		return null

	return _make_stream(data, mix_rate, stereo, loop_end)


## Failure is non-fatal: the song simply re-renders next launch.
func _save(song: Dictionary, stream: AudioStreamWAV) -> void:
	var f := FileAccess.open(_path_for(song), FileAccess.WRITE)
	if f == null:
		push_warning("SongCache: could not write cache for %s" % song["id"])
		return
	f.store_32(CACHE_MAGIC)
	f.store_32(CACHE_FORMAT_VERSION)
	f.store_32(stream.mix_rate)
	f.store_32(1 if stream.stereo else 0)
	f.store_32(stream.loop_end)
	f.store_32(stream.data.size())
	f.store_buffer(stream.data)
	f.close()


func _make_stream(
	data: PackedByteArray, mix_rate: int, stereo: bool, loop_end: int
) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = stereo
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = loop_end
	return stream
