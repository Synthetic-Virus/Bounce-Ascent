extends Camera2D

# Scrolling parameters
const INITIAL_SCROLL_SPEED = 30.0  # Pixels per second
const MAX_SCROLL_SPEED = 120.0
const SPEED_INCREASE_RATE = 0.5    # Speed increase per second

var current_scroll_speed: float = INITIAL_SCROLL_SPEED
var is_scrolling: bool = false
var player_ref: CharacterBody2D = null

signal player_fell_behind()

func _ready():
	# Make camera current
	enabled = true

func start_scrolling():
	is_scrolling = true
	current_scroll_speed = INITIAL_SCROLL_SPEED

func stop_scrolling():
	is_scrolling = false

func set_player(player: CharacterBody2D):
	player_ref = player

func _process(delta):
	if not is_scrolling:
		return

	# Increase scroll speed over time
	current_scroll_speed = min(current_scroll_speed + SPEED_INCREASE_RATE * delta, MAX_SCROLL_SPEED)

	# Scroll camera downward (negative Y)
	position.y -= current_scroll_speed * delta

	# Check if player fell behind
	if player_ref != null:
		var camera_bottom = position.y + get_viewport_rect().size.y / 2
		if player_ref.global_position.y > camera_bottom:
			player_fell_behind.emit()

func reset_camera(start_position: Vector2):
	position = start_position
	current_scroll_speed = INITIAL_SCROLL_SPEED

func get_current_height() -> int:
	# Calculate height based on camera position (each platform ~= 1 height)
	return int(abs(position.y) / 100.0)
