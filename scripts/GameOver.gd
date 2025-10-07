extends Control

var stats: Dictionary = {}

func _ready():
	# Set background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.size = Vector2(800, 1000)
	bg.z_index = -100
	add_child(bg)

	# Create UI container
	var container = VBoxContainer.new()
	container.position = Vector2(100, 150)
	container.size = Vector2(600, 700)
	container.add_theme_constant_override("separation", 15)
	add_child(container)

	# Title
	var title = Label.new()
	title.text = "GAME OVER"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	container.add_child(spacer1)

	# Stats display
	if not stats.is_empty():
		display_stats(container)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	container.add_child(spacer2)

	# Buttons
	var retry_button = Button.new()
	retry_button.text = "RETRY"
	retry_button.custom_minimum_size = Vector2(200, 50)
	retry_button.add_theme_font_size_override("font_size", 24)
	retry_button.pressed.connect(_on_retry_pressed)
	container.add_child(retry_button)

	var menu_button = Button.new()
	menu_button.text = "MAIN MENU"
	menu_button.custom_minimum_size = Vector2(200, 50)
	menu_button.add_theme_font_size_override("font_size", 24)
	menu_button.pressed.connect(_on_menu_pressed)
	container.add_child(menu_button)

func display_stats(container: VBoxContainer):
	var score = GameManager.calculate_score(stats)

	# Score (large)
	var score_label = Label.new()
	score_label.text = "SCORE: " + str(score)
	score_label.add_theme_font_size_override("font_size", 40)
	score_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(score_label)

	# Individual stats
	var stats_text = ""
	stats_text += "Height Reached: " + str(stats.height) + "\n"
	stats_text += "Time Survived: " + str(snappedf(stats.time_survived, 0.1)) + "s\n"
	stats_text += "Platforms Landed On: " + str(stats.platforms_landed) + "\n"
	stats_text += "Platforms Broken: " + str(stats.platforms_broken) + "\n"
	stats_text += "Forced Jumps: " + str(stats.forced_jumps) + "\n"

	if stats.edge_escape_attempts > 0:
		stats_text += "\nEdge Escape Attempts: " + str(stats.edge_escape_attempts)

	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.add_theme_font_size_override("font_size", 20)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(stats_label)

	# High score notification
	if score == GameManager.current_profile.high_score and score > 0:
		var new_high_score = Label.new()
		new_high_score.text = "NEW HIGH SCORE!"
		new_high_score.add_theme_font_size_override("font_size", 32)
		new_high_score.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		new_high_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(new_high_score)

func set_stats(session_stats: Dictionary):
	stats = session_stats

func _on_retry_pressed():
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
