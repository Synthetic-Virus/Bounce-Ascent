extends CanvasLayer

# UI References
var profile_label: Label
var high_score_label: Label
var height_label: Label

func _ready():
	# Create UI elements
	setup_ui()

	# Connect to GameManager signals
	GameManager.stats_updated.connect(_on_stats_updated)
	GameManager.profile_loaded.connect(_on_profile_loaded)

func setup_ui():
	# Top-left: Profile name and high score
	var top_left_container = VBoxContainer.new()
	top_left_container.position = Vector2(10, 10)
	add_child(top_left_container)

	profile_label = Label.new()
	profile_label.add_theme_font_size_override("font_size", 14)
	profile_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	top_left_container.add_child(profile_label)

	high_score_label = Label.new()
	high_score_label.add_theme_font_size_override("font_size", 14)
	high_score_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	top_left_container.add_child(high_score_label)

	# Center-top: Large height display
	height_label = Label.new()
	height_label.position = Vector2(400, 40)  # Center of 800px width
	height_label.add_theme_font_size_override("font_size", 72)
	height_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.4))  # 40% opacity
	height_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	height_label.size = Vector2(200, 100)
	height_label.pivot_offset = Vector2(100, 50)
	add_child(height_label)

	# Update initial values
	update_profile_display()

func update_profile_display():
	if GameManager.current_profile.is_empty():
		return

	profile_label.text = "Player: " + GameManager.current_profile.username
	high_score_label.text = "High Score: " + str(GameManager.current_profile.high_score)

func _on_stats_updated(stats: Dictionary):
	height_label.text = str(stats.height)

func _on_profile_loaded(_profile: Dictionary):
	update_profile_display()

func update_height(height: int):
	height_label.text = str(height)
