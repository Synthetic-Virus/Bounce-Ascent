extends Node

## Persisted player settings. Autoloaded as `Settings`.
##
## Kept separate from scores.gd so a corrupt score table cannot take the audio
## calibration down with it.

signal settings_changed

const SAVE_PATH: String = "user://settings.cfg"

## Manual audio latency correction, measured by the calibration screen.
##
## The important one. Godot's get_output_latency() only covers its own
## buffering; it knows nothing about the OS mixer, Bluetooth or display audio
## processing, which vary by more than 200ms between setups. That is far wider
## than the PERFECT window, so without this a player on high-latency output
## cannot score well no matter how good their timing is.
##
## Positive means sound reaches the ears later than the game thinks.
var audio_offset_ms: float = 0.0

## Output levels. The default is deliberately modest: the synthesised tracks
## stack seven parts and sit close to full scale, so 0.8 came out far too loud
## on first launch, and a first impression of "too loud" is one most players
## only fix by quitting.
var master_volume: float = 0.45
var music_volume: float = 0.85
var sfx_volume: float = 0.6

## Accessibility toggles. A rhythm game flashes and shakes several times a
## second, which is a genuine problem for some players.
var flash_effects: bool = true
var screen_shake: bool = true

## Vibration on button presses. Grouped with the other two because it is the
## same kind of setting: a sensory effect some players need to turn off, not a
## preference about how the game plays. Ignored on desktop.
var haptics: bool = true

## Touch steering. On-screen pads are the default; tilt is opt-in.
##
## Tilt was the original default, on the reasoning that it leaves the whole
## screen free as a jump target. That reasoning was sound and the result was
## still bad on a real phone: tilt couples steering to how you are holding the
## device, so every jump tap nudges your aim, and there is no neutral position
## to return to. Pads are worse in theory and far better in the hand.
var tilt_steering: bool = false

var last_song_id: String = "neon_ascent"


func _ready() -> void:
	load_settings()
	_apply_volumes()


## Missing file or missing keys fall back to the defaults above, so a corrupt or
## partial config never blocks launch.
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return

	audio_offset_ms = cfg.get_value("audio", "offset_ms", audio_offset_ms)
	master_volume = cfg.get_value("audio", "master", master_volume)

	# One-time migration off the old 0.8 default, which was too loud.
	#
	# Only rewritten when the stored value is EXACTLY the old default, i.e. the
	# player never touched it. Anyone who actually chose a level, including 0.8
	# via the slider, keeps it: the slider steps in 0.05 so a deliberate choice
	# is indistinguishable from the old default only in that one case, and
	# leaving a too-loud default in place is the worse of the two risks.
	if is_equal_approx(master_volume, 0.8) and not cfg.has_section_key("audio", "volume_migrated"):
		master_volume = 0.45
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	flash_effects = cfg.get_value("video", "flash_effects", flash_effects)
	screen_shake = cfg.get_value("video", "screen_shake", screen_shake)
	haptics = cfg.get_value("video", "haptics", haptics)
	last_song_id = cfg.get_value("game", "last_song_id", last_song_id)
	tilt_steering = cfg.get_value("controls", "tilt_steering", tilt_steering)

	# One-time migration off tilt steering.
	#
	# Changing the default alone would not have reached anyone who had already
	# launched the game, because their config already holds tilt_steering=true
	# and a stored value always wins over a default. Since tilt shipped as the
	# default, a stored `true` is far more likely to be "never touched it" than
	# a deliberate choice, so it is flipped once and then never again: the
	# migration marker means anyone who genuinely wants tilt can turn it back on
	# and keep it.
	if tilt_steering and not cfg.has_section_key("controls", "steering_migrated"):
		tilt_steering = false


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "offset_ms", audio_offset_ms)
	cfg.set_value("audio", "master", master_volume)
	# Marks the volume default migration as done, so a player who deliberately
	# sets 0.8 later is never quietly turned down again.
	cfg.set_value("audio", "volume_migrated", true)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "flash_effects", flash_effects)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.set_value("video", "haptics", haptics)
	cfg.set_value("game", "last_song_id", last_song_id)
	cfg.set_value("controls", "tilt_steering", tilt_steering)
	# Marks the tilt migration as done, so a player who deliberately chooses
	# tilt later is never quietly switched back to pads.
	cfg.set_value("controls", "steering_migrated", true)

	if cfg.save(SAVE_PATH) != OK:
		push_warning("Settings: could not write %s" % SAVE_PATH)

	_apply_volumes()
	settings_changed.emit()


func audio_offset_seconds() -> float:
	return audio_offset_ms / 1000.0


func _apply_volumes() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	# Mute explicitly rather than relying on linear_to_db(0) being -inf.
	if linear <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
