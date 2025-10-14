extends Camera2D

## Camera that automatically scrolls upward, increasing speed over time.
## Player must keep up or fall behind and lose.

# Export variables for easy tweaking in editor
@export_group("Scrolling")
@export var initial_scroll_speed: float = 25.0  ## Pixels per second at start (slower for larger tiles)
@export var max_scroll_speed: float = 250.0     ## Maximum scroll speed
@export var speed_increase_rate: float = 0.4    ## Speed increase per second
@export var space_speed_multiplier: float = 2.0 ## Extra multiplier in space zone (height 600+)

@export_group("Space Zone")
@export var space_zone_height: int = 600  ## Height at which space zone begins
@export var space_zone_duration: int = 400  ## Height range over which multiplier ramps up

# Internal state
var current_scroll_speed: float = 0.0
var is_scrolling: bool = false
var player_ref: CharacterBody2D = null

signal player_fell_behind()

func _ready():
	# Make camera current
	enabled = true

func start_scrolling() -> void:
	is_scrolling = true
	current_scroll_speed = initial_scroll_speed

func stop_scrolling() -> void:
	is_scrolling = false

func set_player(player: CharacterBody2D) -> void:
	player_ref = player

func _process(delta: float) -> void:
	if not is_scrolling:
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

	# Scroll camera upward (negative Y) with multiplier
	position.y -= current_scroll_speed * delta * speed_multiplier

	# Check if player fell behind
	if player_ref != null:
		var camera_bottom: float = position.y + get_viewport_rect().size.y / 2
		if player_ref.global_position.y > camera_bottom:
			player_fell_behind.emit()

func reset_camera(start_position: Vector2) -> void:
	position = start_position
	current_scroll_speed = initial_scroll_speed

func get_current_height() -> int:
	# Calculate height based on how far camera has moved from start (500)
	# Moving upward (negative Y) increases height
	var distance_traveled = 500.0 - position.y
	return max(0, int(distance_traveled / 100.0))
