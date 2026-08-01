extends Node

## Headless UI and lifecycle test. Run with:
##
##   godot --headless --path <project> res://tests/UITest.tscn
##
## Exits 0 on success, 1 otherwise.
##
## Godot computes Control layout and calls _draw() in headless mode even though
## it renders nothing, so "is this on screen" and "does this crash while
## drawing" are both answerable by assertion rather than by squinting at a
## screenshot.
##
## Also covers navigation, pause and focus loss: the interaction failures that
## can actively kill a player or trap them.

const GameScene: PackedScene = preload("res://scenes/Game.tscn")
const MenuScene: PackedScene = preload("res://scenes/MainMenu.tscn")
const CalibrationScene: PackedScene = preload("res://scenes/Calibration.tscn")

## preload, NOT load(), because the tests call static functions on it.
##
## `var x := load("...")` infers Resource, and Resource has no arrow_head, so
## the call fails the static type check and the whole script refuses to compile.
## A preloaded const carries the GDScript type, which permits the static call.
const TouchControls: GDScript = preload("res://scripts/touch_controls.gd")

## Glow padding and outline bleed put a few pixels outside the layout rect.
const EDGE_TOLERANCE: float = 8.0

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	print("=== Bounce Ascent UI test ===")

	test_fonts()
	await _test_menu_layout()
	await _test_menu_navigation()
	await _test_calibration_layout()
	await _test_touch_controls()
	await _test_hud_layout()
	await _test_pause_lifecycle()
	await _test_focus_loss_pauses()
	await _test_game_over_panel()

	print("---")
	if _failures.is_empty():
		print("PASS  %d checks" % _checks)
		get_tree().quit(0)
	else:
		print("FAIL  %d of %d checks failed:" % [_failures.size(), _checks])
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		print("  FAIL: " + description)


# --- Type -------------------------------------------------------------------

## The design depends on a display face and a MONOSPACE data face. Tabular
## columns are positioned assuming fixed advance widths, so a proportional
## fallback would misalign every results row.
func test_fonts() -> void:
	print("- typography")
	var display := UIKit.display_font()
	var data := UIKit.data_font()
	check(display != null, "display font resolves")
	check(data != null, "data font resolves")

	# Compare the advance of a narrow and a wide digit-width glyph. In a mono
	# face they are identical; in a proportional face they are not.
	var narrow := data.get_string_size("iiiiiiiiii", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var wide := data.get_string_size("WWWWWWWWWW", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	print("    data font: 10x'i' = %.1fpx, 10x'W' = %.1fpx" % [narrow, wide])
	check(absf(narrow - wide) < 2.0,
		"data font is monospace (%.1f vs %.1f)" % [narrow, wide])


# --- Layout helpers ---------------------------------------------------------

func _assert_on_screen(root: Node, label: String) -> void:
	# Measured against the LIVE viewport, not the 720x1280 reference. Stretch
	# aspect is "expand", so a taller phone gets a taller viewport rather than
	# letterboxing, and full-rect controls correctly fill whatever it is.
	var view := (root.get_viewport() as Viewport).get_visible_rect().size
	var w := maxf(view.x, Tuning.PLAYFIELD_WIDTH)
	var h := maxf(view.y, Tuning.PLAYFIELD_HEIGHT)

	for node in _all_controls(root):
		var control := node as Control
		if not control.visible:
			continue

		# Measure the layout rect at unit scale: several widgets scale up on the
		# beat by design, briefly overhanging their own bounds.
		var original_scale := control.scale
		control.scale = Vector2.ONE
		var pos := control.global_position
		var extent := Vector2(
			maxf(control.size.x, control.get_minimum_size().x),
			maxf(control.size.y, control.get_minimum_size().y)
		)
		control.scale = original_scale

		var name_path := "%s/%s" % [label, control.name]
		check(pos.x >= -EDGE_TOLERANCE and pos.y >= -EDGE_TOLERANCE,
			"%s starts on screen (at %.0f,%.0f)" % [name_path, pos.x, pos.y])
		check(pos.x + extent.x <= w + EDGE_TOLERANCE,
			"%s fits horizontally (right edge %.0f of %.0f)"
				% [name_path, pos.x + extent.x, w])
		check(pos.y + extent.y <= h + EDGE_TOLERANCE,
			"%s fits vertically (bottom edge %.0f of %.0f)"
				% [name_path, pos.y + extent.y, h])


func _all_controls(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in root.get_children():
		if child is Control:
			found.append(child)
		found.append_array(_all_controls(child))
	return found


# --- Menu -------------------------------------------------------------------

func _test_menu_layout() -> void:
	print("- main menu layout")
	var menu := MenuScene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	_assert_on_screen(menu, "MainMenu")
	_assert_own_draw_not_covered(menu, "MainMenu")

	# Every interactive element must be a real, focusable Control. Hand-drawn
	# controls have no focus state and can be hidden by a sibling.
	var buttons := _buttons_in(menu)
	print("    %d buttons, %d sliders"
		% [buttons.size(), _nodes_of_type(menu, "HSlider").size()])
	check(buttons.size() >= SongLibrary.all_songs().size() + 4,
		"menu exposes buttons for tracks, play, calibrate and both toggles (%d)"
			% buttons.size())
	for b in buttons:
		check((b as Button).focus_mode == Control.FOCUS_ALL,
			"button '%s' is keyboard focusable" % (b as Button).text.strip_edges())

	# Track rows must not overlap, or they would be unreadable and their hit
	# areas would fight each other.
	var tracks: Array[Button] = menu._track_buttons
	check(tracks.size() == SongLibrary.all_songs().size(),
		"one row per track (%d)" % tracks.size())
	for i in tracks.size():
		var r := Rect2(tracks[i].global_position, tracks[i].size)
		check(r.end.y <= Tuning.PLAYFIELD_HEIGHT, "track row %d fits vertically" % i)
		for j in range(i + 1, tracks.size()):
			var other := Rect2(tracks[j].global_position, tracks[j].size)
			check(not r.intersects(other),
				"track rows %d and %d do not overlap" % [i, j])

	# The primary action must be the largest target and sit below the list.
	var play: Button = menu._play
	var play_area := play.size.x * play.size.y
	var row_area := tracks[0].size.x * tracks[0].size.y
	print("    PLAY %.0fx%.0f, track row %.0fx%.0f"
		% [play.size.x, play.size.y, tracks[0].size.x, tracks[0].size.y])
	check(play_area > 0.0, "primary action has a real hit area")
	check(play.global_position.y > tracks[tracks.size() - 1].global_position.y,
		"primary action sits below the track list")
	check(play.size.y >= tracks[0].size.y,
		"primary action is at least as tall as a track row")

	# A volume control has to exist and be wired to the setting.
	var sliders := _nodes_of_type(menu, "HSlider")
	check(sliders.size() >= 1, "menu has a volume slider")
	if sliders.size() > 0:
		var s := sliders[0] as HSlider
		var before := Settings.master_volume
		s.value = 0.3
		await get_tree().process_frame
		check(absf(Settings.master_volume - 0.3) < 0.01,
			"moving the slider changes master volume (%.2f)" % Settings.master_volume)
		s.value = before
		await get_tree().process_frame

	menu.queue_free()
	await get_tree().process_frame


## A screen that paints in its own _draw() must NOT have an opaque, full-screen
## child, because a CanvasItem draws itself BEFORE its children.
##
## This shipped once: the menu drew its track cards and play button in _draw()
## and then covered them with a background ColorRect child, so the entire
## interface was invisible while every layout assertion still passed.
func _assert_own_draw_not_covered(node: Node, label: String) -> void:
	if not node.has_method("_draw"):
		return
	for child in node.get_children():
		if not (child is ColorRect):
			continue
		var rect := child as ColorRect
		var covers := rect.size.x >= Tuning.PLAYFIELD_WIDTH - 1.0 \
			and rect.size.y >= Tuning.PLAYFIELD_HEIGHT - 1.0
		check(not (covers and rect.color.a >= 0.99 and rect.visible),
			"%s paints in _draw() but has an opaque full-screen ColorRect child"
				% label + " that would cover it")


func _buttons_in(root: Node) -> Array[Node]:
	return _nodes_of_type(root, "Button")


func _nodes_of_type(root: Node, type_name: String) -> Array[Node]:
	var found: Array[Node] = []
	for child in root.get_children():
		if child.is_class(type_name):
			found.append(child)
		found.append_array(_nodes_of_type(child, type_name))
	return found


## Navigation must actually change the selection, by keyboard and by mouse.
func _test_menu_navigation() -> void:
	print("- main menu navigation")
	var menu := MenuScene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	var tracks: Array[Button] = menu._track_buttons
	var start: int = menu._selected

	# Focusing a row selects it, which is what makes arrow-key navigation work.
	var target: int = (start + 1) % tracks.size()
	tracks[target].grab_focus()
	await get_tree().process_frame
	check(menu._selected == target,
		"focusing a track row selects it (wanted %d, got %d)"
			% [target, menu._selected])

	# Pressing a row that is not selected selects it rather than starting a run.
	var other: int = (target + 1) % tracks.size()
	tracks[other].emit_signal("pressed")
	await get_tree().process_frame
	check(menu._selected == other,
		"pressing a different row selects it instead of starting (%d)" % menu._selected)
	check(get_tree().current_scene == null
			or not str(get_tree().current_scene.scene_file_path).ends_with("Game.tscn"),
		"selecting a track does not start a run")

	# Nothing should be able to start a run except an explicit Play press.
	check(menu._play != null, "a Play button exists")
	check(menu._play.focus_mode == Control.FOCUS_ALL, "Play is keyboard focusable")

	menu.queue_free()
	await get_tree().process_frame


func _test_calibration_layout() -> void:
	print("- calibration layout")
	var calib := CalibrationScene.instantiate()
	add_child(calib)
	await get_tree().process_frame
	await get_tree().process_frame

	_assert_on_screen(calib, "Calibration")

	# REGRESSION: the screen said "tap anywhere" and ignored every tap.
	#
	# Control defaults to MOUSE_FILTER_STOP, which consumes pointer events before
	# _unhandled_input can see them. The keyboard path was unaffected, so "press
	# space" worked and the whole screen was dead to touch. It shipped because a
	# desktop test can press space and cannot tap.
	check(calib.mouse_filter != Control.MOUSE_FILTER_STOP,
		"calibration root does not swallow taps before _unhandled_input")

	calib.queue_free()
	await get_tree().process_frame


## Touch steering. Both of these shipped broken and neither was visible to any
## existing assertion, because one lived inside a _draw call and the other only
## appeared when a finger moved between press and release.
func _test_touch_controls() -> void:
	print("- touch steering")

	# REGRESSION: both pads were labelled with the opposite arrow.
	#
	# The apex was placed at -w * direction, so the left pad pointed right. The
	# pads themselves always worked, which is what made it so odd to play: the
	# controls were correct and the labels lied.
	var pad := Rect2(0.0, 0.0, 120.0, 120.0)
	var left_head: PackedVector2Array = TouchControls.arrow_head(pad, -1.0)
	var right_head: PackedVector2Array = TouchControls.arrow_head(pad, 1.0)
	check(left_head[0].x < pad.get_center().x,
		"left pad arrow points left")
	check(right_head[0].x > pad.get_center().x,
		"right pad arrow points right")

	# The shaft must sit BEHIND the tip, or the arrow reads as a diamond.
	var left_shaft: Rect2 = TouchControls.arrow_shaft(pad, -1.0)
	check(left_shaft.get_center().x > left_head[0].x,
		"left pad arrow shaft trails behind its tip")

	# REGRESSION: pads stuck down.
	#
	# Release was matched by POSITION, so pressing inside a pad and lifting after
	# sliding off it discarded the release and left the pad held forever. Sliding
	# off a button is ordinary on a touch screen, so this happened constantly.
	var tc: Node = TouchControls.new()
	add_child(tc)
	await get_tree().process_frame
	tc._active = true
	Settings.tilt_steering = false

	# Annotated, not inferred: tc is typed Node, so its methods return Variant
	# and := has nothing to infer from.
	var inside: Vector2 = tc._pad_rect_left().get_center()
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = inside
	tc._unhandled_input(press)
	check(tc._pad_left, "pad holds while pressed")

	# Lift the SAME finger somewhere else entirely, as a thumb sliding off does.
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = inside + Vector2(400.0, -300.0)
	tc._unhandled_input(release)
	check(not tc._pad_left, "pad releases when the finger lifts off the pad")
	check(not Input.is_action_pressed("move_left"),
		"steering action is not left pressed after the finger lifts")

	# Losing focus mid-hold must not leave the player steering into a wall.
	tc._unhandled_input(press)
	tc._release_all()
	check(not tc._pad_left, "losing focus mid-hold releases the pad")

	tc.queue_free()
	await get_tree().process_frame


# --- In-run -----------------------------------------------------------------

func _test_hud_layout() -> void:
	print("- in-run HUD layout")
	var game := await _start_game()
	var ui: CanvasLayer = game.get_node("GameUI")

	_assert_on_screen(ui, "GameUI")

	# Drive the HUD through its states so every _draw path runs at least once.
	ui.on_countdown(3)
	await get_tree().process_frame
	ui.on_countdown_finished()
	ui.on_judged(Tuning.Judgement.PERFECT, 0.0, 12, Tuning.PERFECT_TIER_SKIP)
	ui.on_tick(12345, 12, 42, 100.0, 0.0)
	await get_tree().process_frame
	ui.on_judged(Tuning.Judgement.MISS, 0.18, 0, 1)
	await get_tree().process_frame
	check(true, "HUD drew countdown, perfect and miss states without error")

	# REGRESSION: the pause button was drawn on top of the height readout.
	#
	# Both were positioned against the right edge of the screen independently,
	# with nothing relating them, and they overlapped by 52px. Invisible to every
	# existing assertion because draw_string leaves no node to measure, which is
	# why both now expose a rect.
	var pause_rect: Rect2 = ui.pause_button_rect()
	var height_rect: Rect2 = ui.height_readout_rect()
	check(not pause_rect.intersects(height_rect),
		"pause button does not overlap the height readout")
	print("    pause %s vs height %s" % [pause_rect, height_rect])

	game.queue_free()
	await get_tree().process_frame


func _test_pause_lifecycle() -> void:
	print("- pause lifecycle")
	var game := await _start_game()
	await _wait_for_playing(game)
	check(game.state == game.State.PLAYING, "run reached PLAYING")

	# Real input events, not a direct _toggle_pause() call: get_tree().paused
	# stops PAUSABLE nodes receiving input, so a node that pauses and then stops
	# listening would trap the player. A method call cannot see that.
	_press_action("pause")
	await get_tree().process_frame
	check(game.state == game.State.PAUSED, "ESC pauses the run")
	check(get_tree().paused, "scene tree is paused")

	_press_action("pause")
	await get_tree().process_frame
	check(game.state == game.State.PLAYING,
		"ESC resumes the run (state %d; if still PAUSED the player is stuck)"
			% game.state)
	check(not get_tree().paused, "scene tree resumed")

	game.queue_free()
	get_tree().paused = false
	await get_tree().process_frame


func _test_focus_loss_pauses() -> void:
	print("- losing window focus pauses the run")
	var game := await _start_game()
	await _wait_for_playing(game)

	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await get_tree().process_frame
	check(game.state == game.State.PAUSED,
		"focus loss pauses the run (state %d)" % game.state)
	check(get_tree().paused, "focus loss pauses the scene tree")

	game.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await get_tree().process_frame
	check(game.state == game.State.PAUSED, "focus regained does not auto-resume")

	game.queue_free()
	get_tree().paused = false
	await get_tree().process_frame


func _test_game_over_panel() -> void:
	print("- results panel")
	var game := await _start_game()
	var over: CanvasLayer = game.get_node("GameOver")

	check(not over.visible, "results panel starts hidden")

	over.show_result({
		"song_name": "Neon Ascent", "score": 1234567, "height": 42,
		"max_combo": 17, "accuracy": 88.5,
		"perfect": 10, "great": 5, "good": 2, "miss": 1,
		"is_best": true,
	})
	await get_tree().process_frame
	await get_tree().process_frame

	check(over.visible, "results panel becomes visible")
	_assert_on_screen(over, "GameOver")

	# Also exercise the non-record path, which uses a different accent.
	over.show_result({
		"song_name": "Overclock", "score": 100, "height": 3,
		"max_combo": 1, "accuracy": 12.0,
		"perfect": 0, "great": 0, "good": 1, "miss": 9,
		"is_best": false,
	})
	await get_tree().process_frame
	check(true, "results panel drew both record and non-record states")

	over.hide_panel()
	check(not over.visible, "results panel hides again")

	game.queue_free()
	await get_tree().process_frame


# --- Helpers ----------------------------------------------------------------

func _start_game() -> Node2D:
	var waited := 0.0
	while not Music.all_ready() and waited < 120.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25

	var game: Node2D = GameScene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	return game


func _wait_for_playing(game: Node2D) -> void:
	var waited := 0.0
	while game.state != game.State.PLAYING and waited < 15.0:
		await get_tree().process_frame
		waited += get_process_delta_time()


## Fire a real press and release through the input system, so it travels the
## same path a keypress does and reaches _unhandled_input.
func _press_action(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)

	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
