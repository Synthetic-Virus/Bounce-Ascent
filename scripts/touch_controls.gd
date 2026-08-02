extends CanvasLayer

## Touch input for phones. Feeds the same actions the keyboard does, so nothing
## downstream knows or cares which was used.
##
## SCHEME
## ------
## Tap anywhere      jump
## On-screen pads    steer  (default)
## Tilt the device   steer  (opt-in, Settings.tilt_steering)
##
## Doodle Jump steers by tilt and has no jump input at all; you bounce on
## contact. We cannot copy that, because the timed jump IS this game, and that
## difference is what sank tilt here. Doodle Jump can afford tilt precisely
## because it has no other touch input: nothing you do with your hands fights
## the accelerometer. Give the same player a jump they must tap on the beat, and
## every tap perturbs the device's attitude, so aiming and timing corrupt each
## other. There is also no neutral to return to, because "level" depends on how
## you happen to be sitting.
##
## So pads are the default despite costing screen area, and despite the jump
## being worth the largest target we can give it. Tilt is kept as an option
## because it does suit playing one-handed, and because taste varies.
##
## The jump stays tap-anywhere in both schemes, including the area above the
## pads, so it keeps nearly the whole screen either way.

## Only shown when the device actually has a touchscreen.
var _active: bool = false
var _pads: Control

## Current steer, -1..1, from tilt or from pads.
var _steer: float = 0.0
var _pad_left: bool = false
var _pad_right: bool = false

## Which touch index is holding each pad, or -1.
##
## A pad is released by the RELEASE OF THE FINGER THAT PRESSED IT, wherever that
## finger happens to be at the time. Matching the release by position instead is
## what made pads stick: press inside the pad, slide your thumb off it, lift,
## and the release lands outside the rect, so the "up" was discarded and the pad
## stayed held forever. Sliding off a button is completely ordinary on a touch
## screen, so this was not an edge case.
var _pad_left_touch: int = -1
var _pad_right_touch: int = -1


func _ready() -> void:
	layer = 5
	_active = DisplayServer.is_touchscreen_available()
	if not _active:
		return

	_pads = Control.new()
	_pads.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pads.draw.connect(_draw_pads)
	add_child(_pads)

	set_process(true)
	set_process_unhandled_input(true)


func _process(_delta: float) -> void:
	if not _active:
		return

	if Settings.tilt_steering:
		# Accelerometer x is the long axis in portrait. Dead zone first so a
		# hand that is not perfectly level does not drift.
		var raw := Input.get_accelerometer().x
		var sign_v := signf(raw)
		var mag := clampf(
			(absf(raw) - Tuning.TILT_DEAD) / (Tuning.TILT_FULL - Tuning.TILT_DEAD),
			0.0, 1.0)
		_steer = sign_v * mag
	else:
		_steer = (1.0 if _pad_right else 0.0) - (1.0 if _pad_left else 0.0)

	_apply_steer()
	if _pads != null and not Settings.tilt_steering:
		_pads.queue_redraw()


## Drive the same actions the keyboard uses, with analogue strength from tilt,
## so a small lean is a small correction.
func _apply_steer() -> void:
	if _steer > 0.0:
		Input.action_release("move_left")
		Input.action_press("move_right", _steer)
	elif _steer < 0.0:
		Input.action_release("move_right")
		Input.action_press("move_left", -_steer)
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch

	if touch.pressed:
		_on_touch_press(touch)
	else:
		_on_touch_release(touch)


func _on_touch_press(touch: InputEventScreenTouch) -> void:
	if not Settings.tilt_steering:
		if _pad_rect_left().has_point(touch.position):
			_pad_left = true
			_pad_left_touch = touch.index
			return
		if _pad_rect_right().has_point(touch.position):
			_pad_right = true
			_pad_right_touch = touch.index
			return

	# Anywhere else is a jump. Fired on press, never on release: the press is
	# the moment the player meant, and it is what gets judged.
	Input.action_press("jump")


func _on_touch_release(touch: InputEventScreenTouch) -> void:
	# Matched by finger, not by where the finger ended up.
	if touch.index == _pad_left_touch:
		_pad_left = false
		_pad_left_touch = -1
		return
	if touch.index == _pad_right_touch:
		_pad_right = false
		_pad_right_touch = -1
		return

	Input.action_release("jump")


## Drop everything held. Without this, going to the background mid-hold leaves
## the action pressed: Android delivers no release for a finger that was down
## when the app lost focus, so the player returns to a game steering itself.
func _release_all() -> void:
	_pad_left = false
	_pad_right = false
	_pad_left_touch = -1
	_pad_right_touch = -1
	_steer = 0.0
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_EXIT_TREE:
		_release_all()


func _pad_rect_left() -> Rect2:
	var s := Tuning.PAD_SIZE
	var m := Tuning.PAD_MARGIN
	return Rect2(m, UIKit.screen_height() - s - m, s, s)


func _pad_rect_right() -> Rect2:
	var s := Tuning.PAD_SIZE
	var m := Tuning.PAD_MARGIN
	return Rect2(m * 2.0 + s, UIKit.screen_height() - s - m, s, s)


## Pads are drawn faintly: they are a fallback, and the playfield matters more.
func _draw_pads() -> void:
	if Settings.tilt_steering:
		return
	_draw_pad(_pad_rect_left(), -1.0, _pad_left)
	_draw_pad(_pad_rect_right(), 1.0, _pad_right)


## `direction` is -1 for left and +1 for right, and the arrow points ALONG it.
##
## It used to point the other way. The apex was placed at -w * direction, so the
## left pad drew its point on the right and the right pad on the left: both pads
## worked correctly and both were labelled with the opposite arrow.
func _draw_pad(rect: Rect2, direction: float, held: bool) -> void:
	var alpha := 0.30 if held else 0.14
	var c := UIKit.CYAN
	_pads.draw_rect(rect, Color(c.r, c.g, c.b, alpha * 0.4), true)
	_pads.draw_rect(rect, Color(c.r, c.g, c.b, alpha + 0.2), false, 2.0)

	# A SOLID arrow rather than an outlined bracket. Filled glyphs survive being
	# half covered by the thumb that is pressing them, which a 4px polyline does
	# not, and a single silhouette reads at a glance while airborne.
	var ink := Color(c.r, c.g, c.b, alpha + 0.45)

	# Head and shaft are drawn as two convex pieces rather than one arrow-shaped
	# polygon, because that polygon is concave and draw_colored_polygon
	# triangulates without being told where the notch is.
	_pads.draw_colored_polygon(arrow_head(rect, direction), ink)
	_pads.draw_rect(arrow_shaft(rect, direction), ink, true)


## Geometry is separated from drawing so the direction can be ASSERTED.
##
## The mirrored-arrow bug lived inside a _draw call, where nothing could see it
## but a human looking at a phone. Returning the points makes "does the left pad
## point left" a test rather than an inspection.
static func arrow_head(rect: Rect2, direction: float) -> PackedVector2Array:
	var mid := rect.get_center()
	var r := rect.size.x * 0.26
	var head_back := mid.x + 0.05 * r * direction
	return PackedVector2Array([
		Vector2(mid.x + r * direction, mid.y),
		Vector2(head_back, mid.y - r * 0.78),
		Vector2(head_back, mid.y + r * 0.78),
	])


static func arrow_shaft(rect: Rect2, direction: float) -> Rect2:
	var mid := rect.get_center()
	var r := rect.size.x * 0.26
	var head_back := mid.x + 0.05 * r * direction
	var tail := mid.x - r * direction
	return Rect2(minf(tail, head_back), mid.y - r * 0.30,
		absf(head_back - tail), r * 0.60)
