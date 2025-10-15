extends StaticBody2D
class_name Platform

# Platform types
enum PlatformType {
	STATIC,
	MOVING,
	BREAKABLE,
	TEMPORARY
}

@export var platform_type: PlatformType = PlatformType.STATIC
@export var platform_width: float = 120.0:
	set(value):
		platform_width = value
		if is_inside_tree():
			update_collision_and_sprite()
@export var platform_height: float = 40.0:
	set(value):
		platform_height = value
		if is_inside_tree():
			update_collision_and_sprite()
@export var middle_piece_count: int = 0  # 0-2 middle pieces

var platform_color: Color = Color.WHITE
var is_active: bool = true

# Node references (from scene)
@onready var sprite: Sprite2D = $PlatformSprite
@onready var collision: CollisionShape2D = $CollisionShape2D

# Tile piece containers
var left_sprite: Sprite2D
var middle_sprites: Array[Sprite2D] = []
var right_sprite: Sprite2D

func _ready():
	# Groups are already set in scene, but ensure it's there
	add_to_group("platform")

	# Set up sprite based on platform type FIRST (this calculates correct platform_width)
	setup_modular_platform()

	# THEN update collision shape size (now platform_width is correct)
	# Use 40px collision height - thin enough for good gameplay, thick enough to prevent phase-through
	if collision and collision.shape:
		collision.shape.size = Vector2(platform_width, 40)  # 40px collision height

func _draw():
	# Draw collision box outline for debugging
	if collision and collision.shape:
		var rect_shape = collision.shape as RectangleShape2D
		if rect_shape:
			var rect_size = rect_shape.size
			var rect_pos = collision.position

			# Draw red rectangle outline showing collision box
			draw_rect(
				Rect2(rect_pos.x - rect_size.x / 2, rect_pos.y - rect_size.y / 2, rect_size.x, rect_size.y),
				Color(1, 0, 0, 0.5),  # Red, semi-transparent
				false,  # false = outline only
				2.0  # Line width
			)

func update_collision_and_sprite():
	# Update collision shape
	if collision and collision.shape:
		collision.shape.size = Vector2(platform_width, platform_height)

	# Update sprite scale
	if sprite:
		var scale_x = platform_width / 128.0
		var scale_y = platform_height / 128.0
		sprite.scale = Vector2(scale_x, scale_y)

func setup_sprite():
	"""Set up platform sprite from Kenney spritesheet"""
	if not sprite:
		push_error("Platform sprite node not found")
		return

	var spritesheet = load("res://assets/sprites/spritesheet-tiles-double.png")
	if not spritesheet:
		push_error("Failed to load platform spritesheet")
		return

	# Create atlas texture based on platform type
	var atlas = AtlasTexture.new()
	atlas.atlas = spritesheet

	# Map platform types to sprite coordinates (128x128 tiles)
	match platform_type:
		PlatformType.STATIC:
			# Green grass cloud platform
			atlas.region = Rect2(896, 1664, 128, 128)  # terrain_grass_cloud
			platform_color = Color(0.2, 1.0, 0.4)
		PlatformType.MOVING:
			# Yellow block
			atlas.region = Rect2(2048, 896, 128, 128)  # block_yellow
			platform_color = Color(1.0, 0.8, 0.2)
		PlatformType.BREAKABLE:
			# Red block
			atlas.region = Rect2(2048, 2176, 128, 128)  # block_red
			platform_color = Color(1.0, 0.3, 0.3)
		PlatformType.TEMPORARY:
			# Purple cloud platform
			atlas.region = Rect2(768, 384, 128, 128)  # terrain_purple_cloud
			platform_color = Color(0.7, 0.4, 1.0)

	sprite.texture = atlas

	# Scale sprite to match platform width
	# Platform width 120px, sprite is 128px, so scale = 120/128 = 0.9375
	var scale_x = platform_width / 128.0
	var scale_y = platform_height / 128.0
	sprite.scale = Vector2(scale_x, scale_y)

func setup_modular_platform():
	"""Create platform using left, middle(s), and right tile pieces"""
	# Hide the old single sprite
	if sprite:
		sprite.visible = false

	var spritesheet = load("res://assets/sprites/spritesheet-tiles-double.png")
	if not spritesheet:
		push_error("Failed to load platform spritesheet")
		return

	# Load platform tile pieces (7,9), (7,10), (7,11)
	# SWAPPED: (7,9) is actually RIGHT, (7,11) is actually LEFT based on rounded edges
	var left_atlas = AtlasTexture.new()
	left_atlas.atlas = spritesheet
	left_atlas.region = Rect2(896, 1408, 128, 128)  # Tile (7,11) - LEFT (rounded on left)

	var middle_atlas = AtlasTexture.new()
	middle_atlas.atlas = spritesheet
	middle_atlas.region = Rect2(896, 1280, 128, 128)  # Tile (7,10) - MIDDLE

	var right_atlas = AtlasTexture.new()
	right_atlas.atlas = spritesheet
	right_atlas.region = Rect2(896, 1152, 128, 128)  # Tile (7,9) - RIGHT (rounded on right)

	# Calculate total platform width in pixels (each tile is 128px wide)
	var tile_width = 128
	var tile_height = 128
	var total_pieces = 2 + middle_piece_count  # left + right + middles
	var total_width = total_pieces * tile_width

	# Update platform dimensions
	platform_width = total_width
	platform_height = tile_height

	# Position collision at the top of the platform
	# Collision size will be set in _ready() after this function completes
	# Y position: -44 keeps 40px collision at the very top of the 128px tile
	if collision:
		collision.position = Vector2(0, -44)  # Centered horizontally, top of tile vertically

	# Calculate sprite positions to center the entire platform around x=0
	# For centered sprites, we need to position them so the whole platform is centered
	# Example: 2 tiles (256px) -> left at -64, right at +64 (centers of 128px sprites)
	# Example: 3 tiles (384px) -> left at -128, middle at 0, right at +128
	var half_width = total_width / 2.0

	# Create LEFT piece (first tile, positioned at left side)
	left_sprite = Sprite2D.new()
	left_sprite.texture = left_atlas
	left_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left_sprite.position = Vector2(-half_width + (tile_width / 2.0), 0)
	add_child(left_sprite)

	# Create MIDDLE pieces (0-2)
	for i in range(middle_piece_count):
		var middle_spr = Sprite2D.new()
		middle_spr.texture = middle_atlas
		middle_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		middle_spr.position = Vector2(-half_width + (tile_width / 2.0) + tile_width * (i + 1), 0)
		add_child(middle_spr)
		middle_sprites.append(middle_spr)

	# Create RIGHT piece (last tile, positioned at right side)
	right_sprite = Sprite2D.new()
	right_sprite.texture = right_atlas
	right_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	right_sprite.position = Vector2(-half_width + (tile_width / 2.0) + tile_width * (middle_piece_count + 1), 0)
	add_child(right_sprite)

func on_player_land():
	# Override in specific platform types
	pass

func deactivate():
	is_active = false
	queue_free()
