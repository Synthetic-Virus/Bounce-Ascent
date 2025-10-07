extends Control

var title_label: Label
var play_button: Button
var quit_button: Button
var profile_info: Label

func _ready():
	# Set background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.size = Vector2(800, 1000)
	bg.z_index = -100
	add_child(bg)

	# Create UI container
	var container = VBoxContainer.new()
	container.position = Vector2(200, 200)
	container.size = Vector2(400, 600)
	container.add_theme_constant_override("separation", 20)
	add_child(container)

	# Title
	title_label = Label.new()
	title_label.text = "BOUNCE ASCENT"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.29, 0.62, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title_label)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 100)
	container.add_child(spacer1)

	# Profile info
	profile_info = Label.new()
	profile_info.add_theme_font_size_override("font_size", 18)
	profile_info.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	profile_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(profile_info)

	# Play button
	play_button = Button.new()
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(200, 50)
	play_button.add_theme_font_size_override("font_size", 24)
	play_button.pressed.connect(_on_play_pressed)
	container.add_child(play_button)

	# Quit button
	quit_button = Button.new()
	quit_button.text = "QUIT"
	quit_button.custom_minimum_size = Vector2(200, 50)
	quit_button.add_theme_font_size_override("font_size", 24)
	quit_button.pressed.connect(_on_quit_pressed)
	container.add_child(quit_button)

	# Update profile display
	update_profile_info()

	# Connect to profile loaded signal
	GameManager.profile_loaded.connect(_on_profile_loaded)

func update_profile_info():
	if GameManager.current_profile.is_empty():
		return

	var profile = GameManager.current_profile
	var info_text = "Player: " + profile.username + "\n"
	info_text += "High Score: " + str(profile.high_score) + "\n"
	info_text += "Total Runs: " + str(profile.total_runs)
	profile_info.text = info_text

func _on_profile_loaded(_profile):
	update_profile_info()

func _on_play_pressed():
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_quit_pressed():
	get_tree().quit()
