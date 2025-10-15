extends Node2D

# Platform generation parameters
const SCREEN_WIDTH = 800
const INITIAL_VERTICAL_SPACING = 240  # Pixels between platforms (spaced out for better gameplay)
const MIN_PLATFORM_WIDTH = 256  # Minimum 2 tiles (left+right)
const MAX_PLATFORM_WIDTH = 512  # Maximum 4 tiles (left+2middle+right)
const SPAWN_DISTANCE_ABOVE_CAMERA = 400  # Spawn platforms this far above visible area
const MIN_HORIZONTAL_DISTANCE = 200  # Minimum horizontal distance from previous platform

# Difficulty thresholds (based on height)
const TIER_2_HEIGHT = 50   # Moving platforms
const TIER_3_HEIGHT = 100  # Breakable platforms
const TIER_4_HEIGHT = 150  # Temporary platforms
const TIER_5_HEIGHT = 200  # Increased difficulty

# Platform type scene - Now using TileMapPlatform with automatic physics
var platform_scene = preload("res://scenes/platforms/TileMapPlatform.tscn")

# State
var last_spawn_y: float = 0.0
var last_spawn_x: float = 400.0  # Track last platform x position (start center)
var platforms: Array = []
var camera_ref: Camera2D = null

signal platform_spawned(platform)

func _ready():
	last_spawn_y = 0.0
	last_spawn_x = 400.0  # Start center

func set_camera(camera: Camera2D):
	camera_ref = camera

func spawn_initial_platforms():
	# Fill entire screen with platforms from bottom (y=1000) to top (y=0)
	# Player starts at y=800 (on top of Ground scene)
	var player_y = 800
	var _screen_bottom = 1000  # Not used, just for documentation
	var screen_top = 0

	# Load the Ground scene as the starting platform
	create_ground_row()

	# Spawn platforms upward from player to screen top
	var y_pos = player_y - INITIAL_VERTICAL_SPACING
	while y_pos > screen_top:
		spawn_platform_at_height(y_pos, 0)
		y_pos -= INITIAL_VERTICAL_SPACING

	# Update last_spawn_y to continue from the highest platform
	last_spawn_y = screen_top - INITIAL_VERTICAL_SPACING

func _process(_delta):
	if camera_ref == null:
		return

	# Spawn new platforms above camera
	var camera_top = camera_ref.global_position.y - get_viewport_rect().size.y / 2
	while last_spawn_y > camera_top - SPAWN_DISTANCE_ABOVE_CAMERA:
		var current_height = abs(int(last_spawn_y / INITIAL_VERTICAL_SPACING))
		spawn_platform_at_height(last_spawn_y - get_vertical_spacing(current_height), current_height)

	# Remove platforms far below camera
	cleanup_old_platforms()

func spawn_platform_at_height(y_position: float, height: int):
	var platform = create_platform_for_difficulty(height)

	# Calculate horizontal position with spacing from previous platform
	var platform_width = get_platform_width(height)
	var min_x = platform_width / 2 + 40
	var max_x = SCREEN_WIDTH - platform_width / 2 - 40

	# Try to spawn platform away from last position (left or right)
	var x_position: float
	if randf() < 0.5:
		# Spawn to the left of previous platform
		x_position = last_spawn_x - MIN_HORIZONTAL_DISTANCE - randf_range(0, 100)
		x_position = max(min_x, x_position)  # Clamp to screen bounds
	else:
		# Spawn to the right of previous platform
		x_position = last_spawn_x + MIN_HORIZONTAL_DISTANCE + randf_range(0, 100)
		x_position = min(max_x, x_position)  # Clamp to screen bounds

	# If we hit the edge, spawn on opposite side
	if x_position <= min_x:
		x_position = randf_range(SCREEN_WIDTH / 2.0, max_x)
	elif x_position >= max_x:
		x_position = randf_range(min_x, SCREEN_WIDTH / 2.0)

	platform.position = Vector2(x_position, y_position)

	# Set platform width
	if platform.has_method("set"):
		platform.platform_width = platform_width

	add_child(platform)
	platforms.append(platform)
	platform_spawned.emit(platform)

	last_spawn_y = y_position
	last_spawn_x = x_position  # Remember this position for next platform

func create_platform_for_difficulty(height: int) -> TileMapPlatform:
	# Instance the base platform scene
	var platform = platform_scene.instantiate()

	# Determine platform type and swap script based on difficulty tier
	var platform_type = Platform.PlatformType.STATIC  # Default

	if height < TIER_2_HEIGHT:
		# Tier 1: Only static platforms
		platform_type = Platform.PlatformType.STATIC
	elif height < TIER_3_HEIGHT:
		# Tier 2: Static + Moving (50% static, 50% moving)
		if randf() < 0.5:
			platform_type = Platform.PlatformType.STATIC
		else:
			platform_type = Platform.PlatformType.MOVING
			platform.set_script(load("res://scripts/MovingPlatform.gd"))
	elif height < TIER_4_HEIGHT:
		# Tier 3: Static + Moving + Breakable (30% static, 40% moving, 30% breakable)
		var rand = randf()
		if rand < 0.3:
			platform_type = Platform.PlatformType.STATIC
		elif rand < 0.7:
			platform_type = Platform.PlatformType.MOVING
			platform.set_script(load("res://scripts/MovingPlatform.gd"))
		else:
			platform_type = Platform.PlatformType.BREAKABLE
			platform.set_script(load("res://scripts/BreakablePlatform.gd"))
	elif height < TIER_5_HEIGHT:
		# Tier 4: All types including temporary (25% static, 35% moving, 25% breakable, 15% temporary)
		var rand = randf()
		if rand < 0.25:
			platform_type = Platform.PlatformType.STATIC
		elif rand < 0.60:
			platform_type = Platform.PlatformType.MOVING
			platform.set_script(load("res://scripts/MovingPlatform.gd"))
		elif rand < 0.85:
			platform_type = Platform.PlatformType.BREAKABLE
			platform.set_script(load("res://scripts/BreakablePlatform.gd"))
		else:
			platform_type = Platform.PlatformType.TEMPORARY
			platform.set_script(load("res://scripts/TemporaryPlatform.gd"))
	else:
		# Tier 5+: Harder mix
		var rand = randf()
		if rand < 0.3:
			platform_type = Platform.PlatformType.STATIC
		elif rand < 0.55:
			platform_type = Platform.PlatformType.MOVING
			platform.set_script(load("res://scripts/MovingPlatform.gd"))
		elif rand < 0.80:
			platform_type = Platform.PlatformType.BREAKABLE
			platform.set_script(load("res://scripts/BreakablePlatform.gd"))
		else:
			platform_type = Platform.PlatformType.TEMPORARY
			platform.set_script(load("res://scripts/TemporaryPlatform.gd"))

	# Set the platform type
	platform.platform_type = platform_type

	# Set random middle piece count (0-2)
	platform.middle_piece_count = randi() % 3  # 0, 1, or 2

	return platform

func get_platform_width(_height: int) -> float:
	# Not used anymore - width is determined by middle_piece_count (0-2)
	# This returns a dummy value for compatibility
	return 256.0  # 2 tiles minimum

func get_vertical_spacing(height: int) -> float:
	# Spacing increases slightly with difficulty
	var base_spacing = INITIAL_VERTICAL_SPACING

	if height > TIER_5_HEIGHT:
		# Increase gap size gradually
		var extra_spacing = min((height - TIER_5_HEIGHT) * 0.3, 30)
		base_spacing += extra_spacing

	return randf_range(base_spacing * 0.9, base_spacing * 1.2)

func cleanup_old_platforms():
	if camera_ref == null:
		return

	var camera_bottom = camera_ref.global_position.y + get_viewport_rect().size.y / 2
	var cleanup_distance = 300  # Distance below camera before cleanup

	for platform in platforms:
		if platform != null and platform.global_position.y > camera_bottom + cleanup_distance:
			platform.queue_free()
			platforms.erase(platform)

func clear_all_platforms():
	for platform in platforms:
		if platform != null:
			platform.queue_free()
	platforms.clear()
	last_spawn_y = 0.0

func create_ground_row():
	"""Load and instantiate the Ground scene as the starting platform"""
	var ground_scene = load("res://scenes/Ground.tscn")
	if not ground_scene:
		push_error("Failed to load Ground scene")
		return

	var ground = ground_scene.instantiate()
	ground.name = "Ground"
	add_child(ground)

	# Add the collision body to platforms array for tracking
	var collision_body = ground.get_node("CollisionBody")
	if collision_body:
		collision_body.add_to_group("platform")
		platforms.append(collision_body)
