extends Camera2D

## Camera that follows the player while auto-scrolling upward with increasing speed.
## Player must keep climbing or camera scrolls past them and they lose.

# Export variables for easy tweaking in editor
@export_group("Scrolling")
@export var initial_scroll_speed: float = 50.0  ## Pixels per second at start (was 25.0)
@export var max_scroll_speed: float = 400.0     ## Maximum scroll speed (was 250.0)
@export var speed_increase_rate: float = 2.0    ## Speed increase per second (was 0.4)
@export var space_speed_multiplier: float = 2.5 ## Extra multiplier in space zone (height 600+)

@export_group("Camera Follow")
@export var follow_smoothness: float = 5.0      ## How smoothly camera follows player (higher = smoother)
@export var min_scroll_y: float = 0.0           ## Minimum Y the camera will scroll to (doesn't go below player)

@export_group("Space Zone")
@export var space_zone_height: int = 300  ## Height at which space zone begins (was 600)
@export var space_zone_duration: int = 200  ## Height range over which multiplier ramps up (was 400)

# Internal state
var current_scroll_speed: float = 0.0
var is_scrolling: bool = false
var player_ref: CharacterBody2D = null
var target_y: float = 0.0  # Target Y position for camera

signal player_fell_behind()

func _ready():
	# Make camera current
	enabled = true
	target_y = position.y

func start_scrolling() -> void:
	is_scrolling = true
	current_scroll_speed = initial_scroll_speed
	if player_ref:
		target_y = player_ref.global_position.y

func stop_scrolling() -> void:
	is_scrolling = false

func set_player(player: CharacterBody2D) -> void:
	player_ref = player
	if player_ref:
		target_y = player_ref.global_position.y

func _process(delta: float) -> void:
	if not is_scrolling or player_ref == null:
		return

	# Increase scroll speed over time
	current_scroll_speed = min(current_scroll_speed + speed_increase_rate * delta, max_scroll_speed)

	# Get current height to determine if in space zone
	var height: int = GameManager.session_stats.height if GameManager.session_stats.has("height") else 0
	var speed_multiplier: float = 1.0

	# Progressive speed increase in space zone
	if height >= space_zone_height:
		# Increase speed gradually as you go higher in space
		var space_progress: float = min(float(height - space_zone_height) / float(space_zone_duration), 1.0)
		speed_multiplier = 1.0 + (space_speed_multiplier - 1.0) * space_progress

	# Scroll target upward (negative Y) with multiplier
	target_y -= current_scroll_speed * delta * speed_multiplier

	# Follow player: Use the lower Y value (higher on screen) between scroll position and player position
	# This ensures camera keeps scrolling up but also follows player if they climb faster
	var desired_y = min(target_y, player_ref.global_position.y)

	# Smoothly interpolate camera position toward desired position
	position.y = lerp(position.y, desired_y, follow_smoothness * delta)

	# Check if player fell behind the bottom of the screen
	var camera_bottom: float = position.y + get_viewport_rect().size.y / 2
	if player_ref.global_position.y > camera_bottom:
		player_fell_behind.emit()

func reset_camera(start_position: Vector2) -> void:
	position = start_position
	target_y = start_position.y
	current_scroll_speed = initial_scroll_speed

func get_current_height() -> int:
	# Calculate height based on how far camera has moved from start (900)
	# Moving upward (negative Y) increases height
	var distance_traveled = 900.0 - position.y
	return max(0, int(distance_traveled / 100.0))
