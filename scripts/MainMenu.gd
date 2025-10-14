extends Control

var title_label: Label
var play_button: Button
var profile_button: Button
var quit_button: Button
var profile_info: Label

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
	if GameManager.game_font:
		title_label.add_theme_font_override("font", GameManager.game_font)
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
	if GameManager.game_font:
		profile_info.add_theme_font_override("font", GameManager.game_font)
	profile_info.add_theme_font_size_override("font_size", 18)
	profile_info.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	profile_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(profile_info)

	# Play button
	play_button = Button.new()
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(200, 50)
	if GameManager.game_font:
		play_button.add_theme_font_override("font", GameManager.game_font)
	play_button.add_theme_font_size_override("font_size", 24)
	play_button.pressed.connect(_on_play_pressed)
	apply_rounded_style(play_button)
	container.add_child(play_button)

	# Profile button
	profile_button = Button.new()
	profile_button.text = "PROFILE"
	profile_button.custom_minimum_size = Vector2(200, 50)
	if GameManager.game_font:
		profile_button.add_theme_font_override("font", GameManager.game_font)
	profile_button.add_theme_font_size_override("font_size", 24)
	profile_button.pressed.connect(_on_profile_pressed)
	apply_rounded_style(profile_button)
	container.add_child(profile_button)

	# Quit button
	quit_button = Button.new()
	quit_button.text = "QUIT"
	quit_button.custom_minimum_size = Vector2(200, 50)
	if GameManager.game_font:
		quit_button.add_theme_font_override("font", GameManager.game_font)
	quit_button.add_theme_font_size_override("font_size", 24)
	quit_button.pressed.connect(_on_quit_pressed)
	apply_rounded_style(quit_button)
	container.add_child(quit_button)

	# Update profile display
	update_profile_info()

	# Connect to profile loaded signal
	GameManager.profile_loaded.connect(_on_profile_loaded)

func update_profile_info():
	if GameManager.current_profile.is_empty():
		return

	var profile = GameManager.current_profile
	var username = profile.username if profile.username != "" else "Player"
	var info_text = "Player: " + username + "\n"
	info_text += "High Score: " + str(profile.high_score)
	profile_info.text = info_text

func _on_profile_loaded(_profile):
	update_profile_info()

func _on_play_pressed():
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_profile_pressed():
	# Open profile editor as an overlay
	var profile_editor = load("res://scenes/ProfileEditor.tscn").instantiate()
	add_child(profile_editor)

	# Update profile info when editor closes
	await profile_editor.tree_exited
	update_profile_info()

func _on_quit_pressed():
	get_tree().quit()
