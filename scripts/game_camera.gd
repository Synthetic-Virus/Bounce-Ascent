extends Camera2D

## Follows the climb and drives the rising death line.
##
## The camera tracks the player upward and never downward: letting it descend
## would mean a botched jump scrolls back progress already earned.

## Whether the death line is advancing. Off during the count-in.
var scrolling: bool = false

var _top_y: float = 0.0

## World y of the death line, only ever decreasing.
##
## World-space, NOT an offset from the camera. Because the camera follows the
## player, a camera-relative line would rise WITH them and climbing faster could
## never open a gap.
var _death_y: float = 0.0

var _shake: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO


func reset(player_start_y: float) -> void:
	_top_y = player_start_y - Tuning.PLAYFIELD_HEIGHT * Tuning.CAMERA_ANCHOR
	_death_y = player_start_y + Tuning.PLAYFIELD_HEIGHT * Tuning.DEATH_LINE
	_shake = 0.0
	scrolling = false
	global_position = Vector2(
		Tuning.PLAYFIELD_WIDTH * 0.5,
		_top_y + Tuning.PLAYFIELD_HEIGHT * 0.5
	)


func update_camera(delta: float, player_y: float, player_tier: int) -> void:
	var desired_top := player_y - Tuning.PLAYFIELD_HEIGHT * Tuning.CAMERA_ANCHOR
	if desired_top < _top_y:
		_top_y = lerpf(_top_y, desired_top,
			clampf(Tuning.CAMERA_LERP * delta, 0.0, 1.0))

	if scrolling:
		var progress := clampf(float(player_tier) / Tuning.RAMP_TIERS, 0.0, 1.0)
		var tiers_per_beat := lerpf(Tuning.SCROLL_START, Tuning.SCROLL_MAX, progress)
		# Expressed per beat then converted, so pressure scales with tempo
		# rather than being a flat pixel rate.
		var beats_per_second := 1.0 / maxf(Conductor.sec_per_beat, 0.0001)
		_death_y -= tiers_per_beat * beats_per_second * Tuning.TIER_RISE * delta

		# Cap the lead so a strong player cannot build an unbounded safe margin.
		_death_y = minf(_death_y,
			player_y + Tuning.PLAYFIELD_HEIGHT * Tuning.MAX_DEATH_LEAD)

	_update_shake(delta)
	global_position = Vector2(
		Tuning.PLAYFIELD_WIDTH * 0.5,
		_top_y + Tuning.PLAYFIELD_HEIGHT * 0.5
	) + _shake_offset


func death_line_y() -> float:
	return _death_y


func top_y() -> float:
	return _top_y


func bottom_y() -> float:
	return _top_y + Tuning.PLAYFIELD_HEIGHT


func add_shake(amount: float) -> void:
	if not Settings.screen_shake:
		return
	_shake = maxf(_shake, amount)


func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		_shake_offset = Vector2.ZERO
		return
	_shake = maxf(_shake - delta * 28.0, 0.0)
	_shake_offset = Vector2(
		randf_range(-_shake, _shake),
		randf_range(-_shake, _shake)
	)
