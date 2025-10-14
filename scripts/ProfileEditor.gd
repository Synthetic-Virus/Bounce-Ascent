extends Control

# UI Elements
var username_input: LineEdit
var color_buttons: Array = []
var stats_label: Label
var close_button: Button

# Predefined colors
var preset_colors: Array = [
	Color(0.29, 0.62, 1.0),  # Neon Blue (default)
	Color(1.0, 0.3, 0.3),    # Red
	Color(0.2, 1.0, 0.4),    # Green
	Color(1.0, 0.8, 0.2),    # Yellow
	Color(0.7, 0.4, 1.0),    # Purple
	Color(1.0, 0.5, 0.0),    # Orange
	Color(0.2, 0.9, 0.9),    # Cyan
	Color(1.0, 0.3, 0.7),    # Pink
]

func create_rounded_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style

func apply_rounded_style(button: Button):
	var normal = create_rounded_button_style()
	var hover = create_rounded_button_style()
	hover.bg_color = Color(0.3, 0.3, 0.4)
	var pressed = create_rounded_button_style()
	pressed.bg_color = Color(0.15, 0.15, 0.25)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)

func _ready():
	# Make this control fill the entire viewport
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block all clicks to menu below

	# Set background - fully opaque to hide main menu
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 1.0)  # Fully opaque dark background
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass to buttons
	add_child(bg)
	move_child(bg, 0)  # Make sure it's first (behind everything else)

	# Create UI container
	var container = VBoxContainer.new()
	container.position = Vector2(100, 50)
	container.size = Vector2(600, 900)
	container.add_theme_constant_override("separation", 15)
	add_child(container)

	# Title
	var title = Label.new()
	title.text = "PROFILE SETTINGS"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	container.add_child(spacer1)

	# Username section
	var name_label = Label.new()
	name_label.text = "Player Name:"
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	container.add_child(name_label)

	username_input = LineEdit.new()
	username_input.text = GameManager.current_profile.username
	username_input.placeholder_text = "Enter your name"
	username_input.custom_minimum_size = Vector2(400, 50)
	username_input.add_theme_font_size_override("font_size", 20)
	username_input.max_length = 20
	username_input.text_changed.connect(_on_username_changed)
	container.add_child(username_input)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	container.add_child(spacer2)

	# Ball color section
	var color_label = Label.new()
	color_label.text = "Ball Color:"
	color_label.add_theme_font_size_override("font_size", 24)
	color_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	container.add_child(color_label)

	# Color picker grid
	var color_grid = GridContainer.new()
	color_grid.columns = 4
	color_grid.add_theme_constant_override("h_separation", 10)
	color_grid.add_theme_constant_override("v_separation", 10)
	container.add_child(color_grid)

	for i in range(preset_colors.size()):
		var color_btn = Button.new()
		color_btn.custom_minimum_size = Vector2(80, 80)

		# Create a colored panel style with rounded corners
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = preset_colors[i]
		style_normal.border_width_left = 2
		style_normal.border_width_right = 2
		style_normal.border_width_top = 2
		style_normal.border_width_bottom = 2
		style_normal.border_color = Color.WHITE
		style_normal.corner_radius_top_left = 12
		style_normal.corner_radius_top_right = 12
		style_normal.corner_radius_bottom_left = 12
		style_normal.corner_radius_bottom_right = 12

		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = preset_colors[i].lightened(0.2)
		style_hover.border_width_left = 4
		style_hover.border_width_right = 4
		style_hover.border_width_top = 4
		style_hover.border_width_bottom = 4
		style_hover.border_color = Color.WHITE
		style_hover.corner_radius_top_left = 12
		style_hover.corner_radius_top_right = 12
		style_hover.corner_radius_bottom_left = 12
		style_hover.corner_radius_bottom_right = 12

		color_btn.add_theme_stylebox_override("normal", style_normal)
		color_btn.add_theme_stylebox_override("hover", style_hover)
		color_btn.add_theme_stylebox_override("pressed", style_hover)

		color_btn.pressed.connect(_on_color_selected.bind(i))
		color_grid.add_child(color_btn)
		color_buttons.append(color_btn)

	# Spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 30)
	container.add_child(spacer3)

	# Stats display
	var stats_title = Label.new()
	stats_title.text = "STATISTICS"
	stats_title.add_theme_font_size_override("font_size", 28)
	stats_title.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(stats_title)

	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	container.add_child(stats_label)

	update_stats_display()

	# Spacer
	var spacer4 = Control.new()
	spacer4.custom_minimum_size = Vector2(0, 20)
	container.add_child(spacer4)

	# Back button
	close_button = Button.new()
	close_button.text = "BACK TO MENU"
	close_button.custom_minimum_size = Vector2(300, 50)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(_on_close_pressed)
	apply_rounded_style(close_button)
	container.add_child(close_button)

	# Highlight current color
	highlight_current_color()

func _on_username_changed(new_text: String):
	if new_text.strip_edges() == "":
		GameManager.update_username("Player")
	else:
		GameManager.update_username(new_text.strip_edges())

func _on_color_selected(color_index: int):
	var selected_color = preset_colors[color_index]
	GameManager.update_ball_color(selected_color)
	highlight_current_color()

func highlight_current_color():
	var current_color = GameManager.get_ball_color()
	for i in range(color_buttons.size()):
		var btn = color_buttons[i]
		var style = btn.get_theme_stylebox("normal")
		if style is StyleBoxFlat:
			if preset_colors[i].is_equal_approx(current_color):
				style.border_width_left = 5
				style.border_width_right = 5
				style.border_width_top = 5
				style.border_width_bottom = 5
				style.border_color = Color.YELLOW
			else:
				style.border_width_left = 2
				style.border_width_right = 2
				style.border_width_top = 2
				style.border_width_bottom = 2
				style.border_color = Color.WHITE

func update_stats_display():
	var profile = GameManager.current_profile
	var stats_text = ""
	stats_text += "High Score: " + str(profile.high_score) + "\n"
	stats_text += "Total Runs: " + str(profile.total_runs) + "\n"
	stats_text += "Total Height: " + str(profile.total_height) + "\n"
	stats_text += "Platforms Landed On: " + str(profile.platforms_landed) + "\n"
	stats_text += "Platforms Broken: " + str(profile.platforms_broken) + "\n"
	stats_text += "Total Time: " + str(snappedf(profile.total_time_survived, 0.1)) + "s\n"
	stats_text += "Deaths: " + str(profile.fell_to_death_count) + "\n"

	if profile.rage_quit_count > 0:
		stats_text += "Rage Quits: " + str(profile.rage_quit_count) + " 😅\n"

	stats_label.text = stats_text

func _on_close_pressed():
	queue_free()

func _input(event):
	# Allow ESC to close profile editor
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
