extends Camera2D

# Scrolling parameters
const INITIAL_SCROLL_SPEED = 30.0  # Pixels per second
const MAX_SCROLL_SPEED = 300.0     # Much higher max speed for endgame
const SPEED_INCREASE_RATE = 0.5    # Speed increase per second
const SPACE_SPEED_MULTIPLIER = 2.0 # Extra speed multiplier in space zone

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

	# Get current height to determine if in space zone
	var height = GameManager.session_stats.height if GameManager.session_stats.has("height") else 0
	var speed_multiplier = 1.0

	# Progressive speed increase in space zone (height > 600)
	if height >= 600:
		# Increase speed gradually as you go higher in space
		var space_progress = min((height - 600) / 400.0, 1.0)  # 0 to 1 over next 400 height
		speed_multiplier = 1.0 + (SPACE_SPEED_MULTIPLIER - 1.0) * space_progress

	# Scroll camera downward (negative Y) with multiplier
	position.y -= current_scroll_speed * delta * speed_multiplier

	# Check if player fell behind
	if player_ref != null:
		var camera_bottom = position.y + get_viewport_rect().size.y / 2
		if player_ref.global_position.y > camera_bottom:
			player_fell_behind.emit()

func reset_camera(start_position: Vector2):
	position = start_position
	current_scroll_speed = INITIAL_SCROLL_SPEED

func get_current_height() -> int:
	# Calculate height based on how far camera has moved from start (500)
	# Moving upward (negative Y) increases height
	var distance_traveled = 500.0 - position.y
	return max(0, int(distance_traveled / 100.0))
