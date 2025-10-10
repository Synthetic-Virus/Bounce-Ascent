extends Node2D

# Get countdown time from parent Game node
func _draw():
	var game = get_parent()
	if not game or not game.has("countdown_time"):
		return

	var countdown_time = game.countdown_time
	var total_time = 3.0

	# Calculate progress (0 to 1)
	var progress = 1.0 - (countdown_time / total_time)

	# Circle parameters
	var radius = 50.0
	var thickness = 6.0

	# Background circle (gray)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.3, 0.3, 0.3, 0.6), thickness)

	# Progress circle (color changes: green -> yellow -> red)
	var circle_color = Color.GREEN
	if countdown_time <= 1.0:
		circle_color = Color.RED
	elif countdown_time <= 2.0:
		circle_color = Color.YELLOW

	# Draw progress arc from top, clockwise
	var arc_angle = progress * TAU
	if arc_angle > 0:
		draw_arc(Vector2.ZERO, radius, -PI/2, -PI/2 + arc_angle, 64, circle_color, thickness + 2)
