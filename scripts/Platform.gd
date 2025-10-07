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
@export var platform_width: float = 120.0
@export var platform_height: float = 20.0

var platform_color: Color = Color.WHITE
var is_active: bool = true

func _ready():
	add_to_group("platform")

	# Set up collision
	var collision = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(platform_width, platform_height)
	collision.shape = rect
	add_child(collision)

	# Set color based on type
	match platform_type:
		PlatformType.STATIC:
			platform_color = Color(0.2, 1.0, 0.4)  # Green
		PlatformType.MOVING:
			platform_color = Color(1.0, 0.8, 0.2)  # Yellow
		PlatformType.BREAKABLE:
			platform_color = Color(1.0, 0.3, 0.3)  # Red
		PlatformType.TEMPORARY:
			platform_color = Color(0.7, 0.4, 1.0)  # Purple

	queue_redraw()

func _draw():
	if is_active:
		# Draw platform rectangle
		var rect = Rect2(-platform_width / 2, -platform_height / 2, platform_width, platform_height)
		draw_rect(rect, platform_color)
		# Draw border
		draw_rect(rect, platform_color.lightened(0.3), false, 2.0)

func on_player_land():
	# Override in specific platform types
	pass

func deactivate():
	is_active = false
	queue_free()
