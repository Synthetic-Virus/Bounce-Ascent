extends Node2D

# Platform generation parameters
const SCREEN_WIDTH = 800
const INITIAL_VERTICAL_SPACING = 240  # Pixels between platforms (spaced out for better gameplay)
const MIN_PLATFORM_WIDTH = 256  # Minimum 2 tiles (left+right)
const MAX_PLATFORM_WIDTH = 512  # Maximum 4 tiles (left+2middle+right)
const SPAWN_DISTANCE_ABOVE_CAMERA = 400  # Spawn platforms this far above visible area

# Difficulty thresholds (based on height)
const TIER_2_HEIGHT = 50   # Moving platforms
const TIER_3_HEIGHT = 100  # Breakable platforms
const TIER_4_HEIGHT = 150  # Temporary platforms
const TIER_5_HEIGHT = 200  # Increased difficulty

# Platform type scene (base scene - variants use same scene but different scripts)
var platform_scene = preload("res://scenes/platforms/Platform.tscn")

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

	# Create ground row using ONLY middle pieces across the bottom
	# Spawn middle tile pieces across the entire screen width
	# This serves as the starting platform, no need for separate first platform
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

func get_platform_width(height: int) -> float:
	# Not used anymore - width is determined by middle_piece_count (0-2)
	# This returns a dummy value for compatibility
	return 256  # 2 tiles minimum

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
	"""Create a solid ground made of middle tile pieces"""
	var spritesheet = load("res://assets/sprites/spritesheet-tiles-double.png")
	if not spritesheet:
		push_error("Failed to load spritesheet for ground")
		return

	# Middle tile piece (7,10) at pixel (896, 1280)
	var middle_atlas = AtlasTexture.new()
	middle_atlas.atlas = spritesheet
	middle_atlas.region = Rect2(896, 1280, 128, 128)

	# Create a Node2D to hold all ground tiles
	var ground_container = Node2D.new()
	ground_container.name = "Ground"
	add_child(ground_container)

	# Spawn middle tiles across the entire screen width
	var tile_width = 128
	var num_tiles = ceil(SCREEN_WIDTH / float(tile_width)) + 2  # Extra tiles to ensure edge coverage
	var ground_y = 936  # Lower position - at bottom of visible screen (1000 - 64 for half tile height)

	# Start from slightly left of screen edge to ensure full coverage
	var start_x = -tile_width / 2
	for i in range(num_tiles):
		var ground_sprite = Sprite2D.new()
		ground_sprite.texture = middle_atlas
		ground_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground_sprite.position = Vector2(start_x + (i * tile_width) + (tile_width / 2), ground_y)
		ground_container.add_child(ground_sprite)

	# Create a single large collision shape for the entire ground
	# Thin collision at top surface to prevent ball getting stuck
	var ground_body = StaticBody2D.new()
	ground_body.position = Vector2(SCREEN_WIDTH / 2, ground_y)
	ground_body.add_to_group("platform")

	var ground_collision = CollisionShape2D.new()
	var ground_shape = RectangleShape2D.new()
	ground_shape.size = Vector2(SCREEN_WIDTH, 20)  # Thin collision matching platforms
	ground_collision.shape = ground_shape
	ground_collision.position = Vector2(0, -54)  # Match platform collision offset
	ground_body.add_child(ground_collision)

	add_child(ground_body)
	platforms.append(ground_body)
