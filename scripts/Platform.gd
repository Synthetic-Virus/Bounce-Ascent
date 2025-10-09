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
@export var platform_height: float = 20.0:
	set(value):
		platform_height = value
		if is_inside_tree():
			update_collision_and_sprite()

var platform_color: Color = Color.WHITE
var is_active: bool = true
var sprite: Sprite2D = null
var collision: CollisionShape2D = null

func _ready():
	add_to_group("platform")

	# Set up collision
	collision = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(platform_width, platform_height)
	collision.shape = rect
	add_child(collision)

	# Set up sprite instead of procedural drawing
	setup_sprite()

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
	var spritesheet = load("res://assets/sprites/spritesheet-tiles-double.png")
	if not spritesheet:
		push_error("Failed to load platform spritesheet")
		return

	# Create sprite
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true

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

	add_child(sprite)

func on_player_land():
	# Override in specific platform types
	pass

func deactivate():
	is_active = false
	queue_free()
