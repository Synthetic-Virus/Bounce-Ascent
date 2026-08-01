extends CanvasLayer

## Touch input for phones. Feeds the same actions the keyboard does, so nothing
## downstream knows or cares which was used.
##
## SCHEME
## ------
## Tap anywhere      jump
## Tilt the device   steer  (default)
## On-screen pads    steer  (fallback, Settings.tilt_steering off)
##
## Doodle Jump steers by tilt and has no jump input at all; you bounce on
## contact. We cannot copy that, because the timed jump IS this game. But the
## steering half is the right idea, and it buys something valuable: with
## steering on the accelerometer, the jump gets the ENTIRE SCREEN as its target.
## For an input judged to +/-45ms, the largest possible target is worth more than
## on-screen buttons that would also cover the playfield.
##
## Pads exist for playing with the device flat on a table, where tilt cannot
## work. Even then the jump stays tap-anywhere, above the pads.

## Only shown when the device actually has a touchscreen.
var _active: bool = false
var _pads: Control

## Current steer, -1..1, from tilt or from pads.
var _steer: float = 0.0
var _pad_left: bool = false
var _pad_right: bool = false


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

	if not Settings.tilt_steering and _pad_rect_left().has_point(touch.position):
		_pad_left = touch.pressed
		return
	if not Settings.tilt_steering and _pad_rect_right().has_point(touch.position):
		_pad_right = touch.pressed
		return

	# Anywhere else is a jump. Fired on press, never on release: the press is
	# the moment the player meant, and it is what gets judged.
	if touch.pressed:
		Input.action_press("jump")
	else:
		Input.action_release("jump")


func _pad_rect_left() -> Rect2:
	var s := Tuning.PAD_SIZE
	var m := Tuning.PAD_MARGIN
	return Rect2(m, Tuning.PLAYFIELD_HEIGHT - s - m, s, s)


func _pad_rect_right() -> Rect2:
	var s := Tuning.PAD_SIZE
	var m := Tuning.PAD_MARGIN
	return Rect2(m * 2.0 + s, Tuning.PLAYFIELD_HEIGHT - s - m, s, s)


## Pads are drawn faintly: they are a fallback, and the playfield matters more.
func _draw_pads() -> void:
	if Settings.tilt_steering:
		return
	_draw_pad(_pad_rect_left(), -1.0, _pad_left)
	_draw_pad(_pad_rect_right(), 1.0, _pad_right)


func _draw_pad(rect: Rect2, direction: float, held: bool) -> void:
	var alpha := 0.30 if held else 0.14
	_pads.draw_rect(rect, Color(UIKit.CYAN.r, UIKit.CYAN.g, UIKit.CYAN.b, alpha * 0.4), true)
	_pads.draw_rect(rect, Color(UIKit.CYAN.r, UIKit.CYAN.g, UIKit.CYAN.b, alpha + 0.2), false, 2.0)

	# A chevron, so the pad reads as a direction rather than a blank square.
	var c := rect.get_center()
	var w := rect.size.x * 0.16
	var pts := PackedVector2Array([
		c + Vector2(w * direction, -w),
		c + Vector2(-w * direction, 0.0),
		c + Vector2(w * direction, w),
	])
	_pads.draw_polyline(pts, Color(UIKit.CYAN.r, UIKit.CYAN.g, UIKit.CYAN.b,
		alpha + 0.35), 4.0)
