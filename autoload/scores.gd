extends Node

## High score persistence. Autoloaded as `Scores`.
##
## Stored separately from settings.gd so that a corrupt score table can never
## take the player's audio calibration down with it -- losing your calibration
## is far more annoying than losing a leaderboard.
##
## Scores are tracked per song, because a run on Overclock at 150 BPM is not
## comparable to one on Neon Ascent at 112 BPM. A single global high score would
## just mean "whichever song is easiest".

signal record_set(song_id: String, entry: Dictionary)

const SAVE_PATH: String = "user://scores.cfg"

## How many entries to keep per song.
const TABLE_SIZE: int = 5

## song_id -> Array[Dictionary], sorted best first. Each entry is:
##   { score: int, height: int, max_combo: int, accuracy: float, date: String }
var _tables: Dictionary = {}


func _ready() -> void:
	load_scores()


func load_scores() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for song_id in cfg.get_sections():
		var raw = cfg.get_value(song_id, "entries", [])
		# Defensive: a hand-edited or partially written file could contain
		# anything. Anything that is not a well-formed entry is dropped rather
		# than crashing the game on launch.
		var clean: Array = []
		for e in raw:
			if e is Dictionary and e.has("score"):
				clean.append(e)
		_tables[song_id] = clean


func save_scores() -> void:
	var cfg := ConfigFile.new()
	for song_id in _tables:
		cfg.set_value(song_id, "entries", _tables[song_id])
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Scores: could not write %s (error %d)" % [SAVE_PATH, err])


## The score table for a song, best first. Never null.
func table_for(song_id: String) -> Array:
	return _tables.get(song_id, [])


## The single best score for a song, or 0 if none has been set.
func best_score(song_id: String) -> int:
	var table := table_for(song_id)
	if table.is_empty():
		return 0
	return table[0].get("score", 0)


## Record a finished run. Returns true if it made the table, which the game over
## screen uses to decide whether to celebrate.
func submit(
	song_id: String,
	score: int,
	height: int,
	max_combo: int,
	accuracy: float
) -> bool:
	var entry := {
		"score": score,
		"height": height,
		"max_combo": max_combo,
		"accuracy": accuracy,
		# Stored for display only. Uses the local clock, so it is not
		# authoritative for anything -- there is no server and no competition.
		"date": Time.get_date_string_from_system(),
	}

	var table: Array = _tables.get(song_id, [])
	table.append(entry)
	# Sort descending by score. custom_comparator returns true when a should
	# come before b.
	table.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
	if table.size() > TABLE_SIZE:
		table.resize(TABLE_SIZE)
	_tables[song_id] = table

	save_scores()

	var made_table: bool = table.has(entry)
	if made_table:
		record_set.emit(song_id, entry)
	return made_table


## True if `score` would be a new best for the song.
func is_new_best(song_id: String, score: int) -> bool:
	return score > best_score(song_id)
