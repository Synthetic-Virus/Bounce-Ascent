extends Control

## Main menu: pick a track, then play. Settings live behind their own panel.
##
## Built from real Button and HSlider nodes in containers, not hand-drawn
## rectangles, so every control has hover, pressed and keyboard focus states and
## cannot be covered by a sibling.
##
## Sizing targets touch first. Every control is at least Tuning.TOUCH_MIN tall,
## which is comfortably above the 44pt minimum on a phone once the 720-wide
## viewport is scaled to a real screen. Nothing depends on hover.

const GameScene: String = "res://scenes/Game.tscn"
const CalibrationScene: String = "res://scenes/Calibration.tscn"

var _songs: Array[Dictionary] = []
var _selected: int = 0
var _preview_started: bool = false

var _main_panel: VBoxContainer
var _settings_panel: VBoxContainer
var _howto_panel: VBoxContainer
var _howto: Button
var _track_buttons: Array[Button] = []
var _play: Button
var _volume: HSlider
var _volume_value: Label
var _flash: Button
var _shake: Button
var _steering: Button
var _calibrate: Button
var _status: Label


func _ready() -> void:
	_songs = SongLibrary.all_songs()
	for i in _songs.size():
		if _songs[i]["id"] == Settings.last_song_id:
			_selected = i
			break

	_build()
	_refresh()
	Music.song_ready.connect(_on_song_ready)
	set_process(true)
	_track_buttons[_selected].grab_focus()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var ruler := preload("res://scenes/BeatRuler.tscn").instantiate()
	ruler.position = Vector2(14.0, 0.0)
	ruler.size = Vector2(UIKit.RULER_WIDTH, Tuning.PLAYFIELD_HEIGHT)
	add_child(ruler)

	_main_panel = _make_column()
	add_child(_main_panel)
	_build_main(_main_panel)

	_settings_panel = _make_column()
	_settings_panel.visible = false
	add_child(_settings_panel)
	_build_settings(_settings_panel)

	_howto_panel = _make_column()
	_howto_panel.visible = false
	add_child(_howto_panel)
	_build_howto(_howto_panel)


## A full-height column inside the safe area, so nothing lands under a notch or
## a home indicator on a phone.
func _make_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	var inset := UIKit.safe_area_insets()
	col.position = Vector2(UIKit.MARGIN, 80.0 + inset.x)
	col.size = Vector2(
		Tuning.PLAYFIELD_WIDTH - UIKit.MARGIN * 2.0,
		Tuning.PLAYFIELD_HEIGHT - 140.0 - inset.x - inset.y)
	col.add_theme_constant_override("separation", 12)
	return col


func _build_main(col: VBoxContainer) -> void:
	var avail := Tuning.PLAYFIELD_WIDTH - UIKit.MARGIN * 2.0
	var size := mini(
		UIKit.fit_size(UIKit.display_font(), "BOUNCE", avail, 88),
		UIKit.fit_size(UIKit.display_font(), "ASCENT", avail, 88))
	col.add_child(UIKit.heading("Bounce", size, UIKit.CYAN, 4))
	col.add_child(UIKit.heading("Ascent", size, UIKit.VIOLET, 4))
	col.add_child(UIKit.data("land on the beat", 19, UIKit.DIM))

	col.add_child(_spacer(16))
	col.add_child(UIKit.eyebrow("Track"))

	for i in _songs.size():
		var b := UIKit.button("", UIKit.VIOLET, 20)
		b.custom_minimum_size = Vector2(0, Tuning.TOUCH_ROW)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_track_pressed.bind(i))
		b.focus_entered.connect(_on_track_focused.bind(i))
		_track_buttons.append(b)
		col.add_child(b)

	_status = UIKit.data("", 16, UIKit.GOLD)
	col.add_child(_status)

	col.add_child(_spacer(12))
	_play = UIKit.button("PLAY", UIKit.GOLD, 32, true)
	_play.custom_minimum_size = Vector2(0, Tuning.TOUCH_PRIMARY)
	_play.pressed.connect(_start_game)
	col.add_child(_play)

	# Above Settings, because a new player needs this and does not need Settings.
	# Its label calls itself out until the player has actually finished a run;
	# see _refresh().
	_howto = UIKit.button("", UIKit.CYAN, 20)
	_howto.custom_minimum_size = Vector2(0, Tuning.TOUCH_MIN)
	_howto.pressed.connect(_show_howto)
	col.add_child(_howto)

	var settings := UIKit.button("Settings", UIKit.CYAN, 20)
	settings.custom_minimum_size = Vector2(0, Tuning.TOUCH_MIN)
	settings.pressed.connect(_show_settings)
	col.add_child(settings)


func _build_settings(col: VBoxContainer) -> void:
	col.add_child(UIKit.heading("Settings", 54, UIKit.CYAN, 4))
	col.add_child(_spacer(10))

	col.add_child(UIKit.eyebrow("Audio"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size = Vector2(0, Tuning.TOUCH_MIN)
	col.add_child(row)

	var vol_label := UIKit.data("volume", 18, UIKit.DIM)
	vol_label.custom_minimum_size = Vector2(96, 0)
	vol_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(vol_label)

	_volume = UIKit.slider()
	_volume.min_value = 0.0
	_volume.max_value = 1.0
	_volume.step = 0.05
	_volume.value = Settings.master_volume
	# Tall enough to grab with a thumb, not just a mouse pointer.
	_volume.custom_minimum_size = Vector2(300, Tuning.TOUCH_MIN)
	_volume.value_changed.connect(_on_volume_changed)
	row.add_child(_volume)

	_volume_value = UIKit.data("", 18, UIKit.TEXT)
	_volume_value.custom_minimum_size = Vector2(64, 0)
	_volume_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_volume_value)

	_calibrate = UIKit.button("Calibrate audio", UIKit.CYAN, 20)
	_calibrate.custom_minimum_size = Vector2(0, Tuning.TOUCH_MIN)
	_calibrate.pressed.connect(_open_calibration)
	col.add_child(_calibrate)

	col.add_child(_spacer(14))
	col.add_child(UIKit.eyebrow("Controls"))
	_steering = UIKit.button("", UIKit.CYAN, 20)
	_steering.custom_minimum_size = Vector2(0, Tuning.TOUCH_MIN)
	_steering.pressed.connect(_toggle_steering)
	col.add_child(_steering)

	col.add_child(_spacer(14))
	col.add_child(UIKit.eyebrow("Accessibility"))
	_flash = UIKit.button("", UIKit.CYAN, 20)
	_flash.custom_minimum_size = Vector2(0, Tuning.TOUCH_MIN)
	_flash.pressed.connect(_toggle_flash)
	col.add_child(_flash)

	_shake = UIKit.button("", UIKit.CYAN, 20)
	_shake.custom_minimum_size = Vector2(0, Tuning.TOUCH_MIN)
	_shake.pressed.connect(_toggle_shake)
	col.add_child(_shake)

	col.add_child(_spacer(20))
	var back := UIKit.button("Done", UIKit.GOLD, 26, true)
	back.custom_minimum_size = Vector2(0, Tuning.TOUCH_PRIMARY)
	back.pressed.connect(_hide_settings)
	col.add_child(back)


## How to play.
##
## Written as four things in the order a player needs them, not as a feature
## list. The game's central rule is not guessable by experiment: you can play
## for a long time, jump whenever, and never notice that timing is what decides
## how high you go. That has to be stated.
##
## Controls adapt to the device, because telling a phone player about the A key
## is noise and telling a desktop player to tap is worse.
func _build_howto(col: VBoxContainer) -> void:
	col.add_child(UIKit.heading("How to play", 46, UIKit.CYAN, 3))
	col.add_child(_spacer(8))

	col.add_child(UIKit.eyebrow("The rule"))
	col.add_child(UIKit.data("You jump on every beat.", 20, UIKit.TEXT))
	col.add_child(UIKit.data("Land, then tap in time with the music.", 18, UIKit.DIM))

	col.add_child(_spacer(12))
	col.add_child(UIKit.eyebrow("Timing is height"))
	col.add_child(UIKit.data("Perfect timing climbs TWO platforms.", 19, UIKit.GOLD))
	col.add_child(UIKit.data("Anything else climbs one.", 18, UIKit.DIM))

	col.add_child(_spacer(12))
	col.add_child(UIKit.eyebrow("Stay ahead"))
	col.add_child(UIKit.data("A hazard line rises from below and", 18, UIKit.DIM))
	col.add_child(UIKit.data("speeds up. Fall behind it and the run ends.", 18, UIKit.DIM))

	col.add_child(_spacer(12))
	col.add_child(UIKit.eyebrow("Controls"))
	if DisplayServer.is_touchscreen_available():
		col.add_child(UIKit.data("Tap anywhere to jump.", 19, UIKit.TEXT))
		col.add_child(UIKit.data("Hold the arrows to steer, in the air only.", 18, UIKit.DIM))
	else:
		col.add_child(UIKit.data("SPACE to jump.", 19, UIKit.TEXT))
		col.add_child(UIKit.data("A and D steer, in the air only.", 18, UIKit.DIM))
	col.add_child(UIKit.data("Standing still, steering is off on purpose,", 17, UIKit.DIM))
	col.add_child(UIKit.data("so you cannot walk off your own platform.", 17, UIKit.DIM))

	col.add_child(_spacer(12))
	col.add_child(UIKit.data("Calibrate audio in Settings first, or", 17, UIKit.VIOLET))
	col.add_child(UIKit.data("good timing will still score badly.", 17, UIKit.VIOLET))

	col.add_child(_spacer(16))
	var back := UIKit.button("Got it", UIKit.GOLD, 26, true)
	back.custom_minimum_size = Vector2(0, Tuning.TOUCH_PRIMARY)
	back.pressed.connect(_hide_howto)
	col.add_child(back)


func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _process(_delta: float) -> void:
	_maybe_start_preview()
	_update_ready_state()
	if Conductor.running and _play != null and _play.visible:
		var pulse := Conductor.beat_pulse(5.0)
		_play.modulate = Color(1.0 + pulse * 0.12, 1.0 + pulse * 0.12,
			1.0 + pulse * 0.12)


# --- Panels -----------------------------------------------------------------

func _show_settings() -> void:
	Music.play_sfx("ui_confirm")
	_main_panel.visible = false
	_settings_panel.visible = true
	_volume.grab_focus()


func _hide_settings() -> void:
	Music.play_sfx("ui_move")
	_settings_panel.visible = false
	_main_panel.visible = true
	_play.grab_focus()


func _show_howto() -> void:
	Music.play_sfx("ui_confirm")
	_main_panel.visible = false
	_howto_panel.visible = true


func _hide_howto() -> void:
	Music.play_sfx("ui_move")
	_howto_panel.visible = false
	_main_panel.visible = true
	_play.grab_focus()


# --- Actions ----------------------------------------------------------------

## Track rows ONLY select. Starting a run is the Play button's job and nothing
## else's, so no press can drop the player into a climb they did not ask for.
func _on_track_pressed(index: int) -> void:
	_select(index)


func _on_track_focused(index: int) -> void:
	_select(index)


func _select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	Settings.last_song_id = _songs[_selected]["id"]
	Settings.save_settings()
	_preview_started = false
	Music.stop_song()
	Conductor.stop()
	Music.play_sfx("ui_move")
	_refresh()


func _on_volume_changed(value: float) -> void:
	Settings.master_volume = value
	Settings.save_settings()
	_volume_value.text = "%d%%" % int(round(value * 100.0))


func _toggle_flash() -> void:
	Settings.flash_effects = not Settings.flash_effects
	Settings.save_settings()
	Music.play_sfx("ui_move")
	_refresh()


func _toggle_shake() -> void:
	Settings.screen_shake = not Settings.screen_shake
	Settings.save_settings()
	Music.play_sfx("ui_move")
	_refresh()


func _toggle_steering() -> void:
	Settings.tilt_steering = not Settings.tilt_steering
	Settings.save_settings()
	Music.play_sfx("ui_move")
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	# Back out of a sub-panel rather than quitting, so the key means the same
	# thing it means everywhere else in the game.
	if _settings_panel.visible:
		_hide_settings()
	elif _howto_panel.visible:
		_hide_howto()
	else:
		get_tree().quit()


# --- State ------------------------------------------------------------------

func _maybe_start_preview() -> void:
	if _preview_started or not _selected_ready():
		return
	_preview_started = true
	var song := _songs[_selected]
	Conductor.start(song)
	Music.play_song(song)


func _selected_ready() -> bool:
	return Music.is_song_ready(_songs[_selected]["id"])


func _refresh() -> void:
	for i in _track_buttons.size():
		var song := _songs[i]
		var best := Scores.best_score(song["id"])
		var best_text := "best %s" % UIKit.thousands(best) if best > 0 else "no record"
		_track_buttons[i].text = "%s%3d BPM  %-13s %s %s" % [
			"> " if i == _selected else "  ",
			int(song["bpm"]), str(song["name"]).to_upper(),
			"*".repeat(int(song.get("difficulty", 0)) + 1).rpad(3),
			best_text,
		]
		_track_buttons[i].add_theme_color_override("font_color",
			UIKit.GOLD if i == _selected else UIKit.TEXT)

	# Calls itself out until the player has a record on some track. The rule that
	# timing decides height is not discoverable by playing, so a brand new player
	# who walks past this button never learns the game.
	var played := false
	for song in _songs:
		if Scores.best_score(song["id"]) > 0:
			played = true
			break
	_howto.text = "How to play" if played else "How to play  <- new here?"
	_howto.add_theme_color_override("font_color",
		UIKit.CYAN if played else UIKit.GOLD)

	_flash.text = "Flash effects   %s" % ("on" if Settings.flash_effects else "off")
	_shake.text = "Screen shake    %s" % ("on" if Settings.screen_shake else "off")
	_steering.text = "Steering   %s" % (
		"tilt the device" if Settings.tilt_steering else "on-screen pads")
	_volume_value.text = "%d%%" % int(round(Settings.master_volume * 100.0))

	var calibrated := absf(Settings.audio_offset_ms) > 0.5
	_calibrate.text = "Calibrate audio  (%+d ms)" % int(Settings.audio_offset_ms) \
		if calibrated else "Calibrate audio  <- do this first"


func _update_ready_state() -> void:
	var ready := _selected_ready()
	_play.disabled = not ready
	_play.text = "PLAY" if ready else "PREPARING AUDIO"
	_status.text = "" if ready else "building audio, first launch only"


func _on_song_ready(_song_id: String) -> void:
	_refresh()


func _start_game() -> void:
	if not _selected_ready():
		return
	Music.play_sfx("ui_confirm")
	Settings.last_song_id = _songs[_selected]["id"]
	Settings.save_settings()
	Music.stop_song()
	Conductor.stop()
	get_tree().change_scene_to_file(GameScene)


func _open_calibration() -> void:
	Music.play_sfx("ui_confirm")
	Music.stop_song()
	Conductor.stop()
	get_tree().change_scene_to_file(CalibrationScene)
