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
		# Draw rounded platform with wood texture
		var corner_radius = 8.0
		var rect = Rect2(-platform_width / 2, -platform_height / 2, platform_width, platform_height)

		# Draw black outline/shadow first (behind platform)
		var outline_width = 3.0
		var outline_rect = Rect2(rect.position.x - outline_width, rect.position.y - outline_width,
								  rect.size.x + outline_width * 2, rect.size.y + outline_width * 2)
		var outline_radius = corner_radius + outline_width

		# Draw outline rounded rectangle
		draw_rect(Rect2(outline_rect.position.x + outline_radius, outline_rect.position.y,
						outline_rect.size.x - outline_radius * 2, outline_rect.size.y), Color.BLACK)
		draw_rect(Rect2(outline_rect.position.x, outline_rect.position.y + outline_radius,
						outline_radius, outline_rect.size.y - outline_radius * 2), Color.BLACK)
		draw_rect(Rect2(outline_rect.position.x + outline_rect.size.x - outline_radius,
						outline_rect.position.y + outline_radius, outline_radius,
						outline_rect.size.y - outline_radius * 2), Color.BLACK)

		# Outline corner circles
		draw_circle(Vector2(outline_rect.position.x + outline_radius, outline_rect.position.y + outline_radius),
					outline_radius, Color.BLACK)
		draw_circle(Vector2(outline_rect.position.x + outline_rect.size.x - outline_radius,
					outline_rect.position.y + outline_radius), outline_radius, Color.BLACK)
		draw_circle(Vector2(outline_rect.position.x + outline_radius,
					outline_rect.position.y + outline_rect.size.y - outline_radius), outline_radius, Color.BLACK)
		draw_circle(Vector2(outline_rect.position.x + outline_rect.size.x - outline_radius,
					outline_rect.position.y + outline_rect.size.y - outline_radius), outline_radius, Color.BLACK)

		# Draw main platform (rounded rectangle)
		draw_rect(Rect2(rect.position.x + corner_radius, rect.position.y, rect.size.x - corner_radius * 2, rect.size.y), platform_color)
		draw_rect(Rect2(rect.position.x, rect.position.y + corner_radius, corner_radius, rect.size.y - corner_radius * 2), platform_color)
		draw_rect(Rect2(rect.position.x + rect.size.x - corner_radius, rect.position.y + corner_radius, corner_radius, rect.size.y - corner_radius * 2), platform_color)

		# Draw corner circles
		draw_circle(Vector2(rect.position.x + corner_radius, rect.position.y + corner_radius), corner_radius, platform_color)
		draw_circle(Vector2(rect.position.x + rect.size.x - corner_radius, rect.position.y + corner_radius), corner_radius, platform_color)
		draw_circle(Vector2(rect.position.x + corner_radius, rect.position.y + rect.size.y - corner_radius), corner_radius, platform_color)
		draw_circle(Vector2(rect.position.x + rect.size.x - corner_radius, rect.position.y + rect.size.y - corner_radius), corner_radius, platform_color)

		# Add wood grain texture (simple geometric lines)
		var darker = platform_color.darkened(0.3)
		var lighter = platform_color.lightened(0.2)

		# Horizontal wood grain lines
		var num_lines = int(platform_height / 4) + 2
		for i in range(num_lines):
			var y_offset = rect.position.y + (i * platform_height / float(num_lines))
			var line_color = darker if i % 2 == 0 else lighter
			var start_x = rect.position.x + corner_radius
			var end_x = rect.position.x + rect.size.x - corner_radius

			# Add slight variation to line positions for organic feel
			var variation = sin(i * 1.5) * 2.0
			y_offset += variation

			# Draw wood grain line
			draw_line(Vector2(start_x, y_offset), Vector2(end_x, y_offset), line_color, 1.0)

		# Add a few vertical cracks/knots for wood texture
		for i in range(2):
			var x_pos = rect.position.x + (platform_width * (0.3 + i * 0.4))
			var crack_color = darker.darkened(0.2)
			draw_line(
				Vector2(x_pos, rect.position.y + 3),
				Vector2(x_pos + randf_range(-2, 2), rect.position.y + rect.size.y - 3),
				crack_color,
				1.5
			)

func on_player_land():
	# Override in specific platform types
	pass

func deactivate():
	is_active = false
	queue_free()
