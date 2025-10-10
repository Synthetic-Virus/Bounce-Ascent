extends Node2D

# Platform generation parameters
const SCREEN_WIDTH = 800
const INITIAL_VERTICAL_SPACING = 100  # Pixels between platforms
const MIN_PLATFORM_WIDTH = 60
const MAX_PLATFORM_WIDTH = 180
const SPAWN_DISTANCE_ABOVE_CAMERA = 200  # Spawn platforms this far above visible area

# Difficulty thresholds (based on height)
const TIER_2_HEIGHT = 50   # Moving platforms
const TIER_3_HEIGHT = 100  # Breakable platforms
const TIER_4_HEIGHT = 150  # Temporary platforms
const TIER_5_HEIGHT = 200  # Increased difficulty

# Platform type scenes
var platform_scene = preload("res://scripts/Platform.gd")
var moving_platform_scene = preload("res://scripts/MovingPlatform.gd")
var breakable_platform_scene = preload("res://scripts/BreakablePlatform.gd")
var temporary_platform_scene = preload("res://scripts/TemporaryPlatform.gd")

# State
var last_spawn_y: float = 0.0
var platforms: Array = []
var camera_ref: Camera2D = null

signal platform_spawned(platform)

func _ready():
	last_spawn_y = 0.0

func set_camera(camera: Camera2D):
	camera_ref = camera

func spawn_initial_platforms():
	# Fill entire screen with platforms from bottom (y=1000) to top (y=0)
	# Player starts at y=920 (near bottom on ground)
	var player_y = 920
	var screen_bottom = 1000
	var screen_top = 0

	# Create ground row of platforms at bottom (at the very bottom edge)
	# Spawn 7 platforms across the width to create a solid ground
	for i in range(7):
		var ground_platform = create_platform_for_difficulty(0)
		ground_platform.position = Vector2(i * 120 + 60, 990)  # At the very bottom
		ground_platform.platform_width = 120
		add_child(ground_platform)
		platforms.append(ground_platform)

	# First platform ALWAYS spawns directly under player
	var first_platform = create_platform_for_difficulty(0)
	first_platform.position = Vector2(400, player_y + 40)  # Centered under player
	first_platform.platform_width = 140  # Wider for safety
	add_child(first_platform)
	platforms.append(first_platform)

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

	# Random horizontal position (ensure platform stays on screen)
	var platform_width = get_platform_width(height)
	var min_x = platform_width / 2 + 20
	var max_x = SCREEN_WIDTH - platform_width / 2 - 20
	var x_position = randf_range(min_x, max_x)

	platform.position = Vector2(x_position, y_position)

	# Set platform width
	if platform.has_method("set"):
		platform.platform_width = platform_width

	add_child(platform)
	platforms.append(platform)
	platform_spawned.emit(platform)

	last_spawn_y = y_position

func create_platform_for_difficulty(height: int) -> Platform:
	var platform_script = null

	# Determine platform type based on difficulty tier
	if height < TIER_2_HEIGHT:
		# Tier 1: Only static platforms
		platform_script = platform_scene
	elif height < TIER_3_HEIGHT:
		# Tier 2: Static + Moving (50% static, 50% moving)
		if randf() < 0.5:
			platform_script = platform_scene
		else:
			platform_script = moving_platform_scene
	elif height < TIER_4_HEIGHT:
		# Tier 3: Static + Moving + Breakable (30% static, 40% moving, 30% breakable)
		var rand = randf()
		if rand < 0.3:
			platform_script = platform_scene
		elif rand < 0.7:
			platform_script = moving_platform_scene
		else:
			platform_script = breakable_platform_scene
	elif height < TIER_5_HEIGHT:
		# Tier 4: All types including temporary (25% static, 35% moving, 25% breakable, 15% temporary)
		var rand = randf()
		if rand < 0.25:
			platform_script = platform_scene
		elif rand < 0.60:
			platform_script = moving_platform_scene
		elif rand < 0.85:
			platform_script = breakable_platform_scene
		else:
			platform_script = temporary_platform_scene
	else:
		# Tier 5+: Harder mix
		var rand = randf()
		if rand < 0.3:
			platform_script = platform_scene
		elif rand < 0.55:
			platform_script = moving_platform_scene
		elif rand < 0.80:
			platform_script = breakable_platform_scene
		else:
			platform_script = temporary_platform_scene

	# Create platform node
	var platform = StaticBody2D.new()
	platform.set_script(platform_script)
	return platform

func get_platform_width(height: int) -> float:
	# Platforms get smaller with height
	if height < TIER_5_HEIGHT:
		return randf_range(120, MAX_PLATFORM_WIDTH)
	else:
		# Tier 5+: Smaller platforms
		var reduction = min((height - TIER_5_HEIGHT) * 0.5, 40)
		return randf_range(MIN_PLATFORM_WIDTH + 20, MAX_PLATFORM_WIDTH - reduction)

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
