extends CanvasLayer

# UI References
var profile_label: Label
var high_score_label: Label
var height_label: Label
var timer_label: Label
var rhythm_label: Label
var player_ref: CharacterBody2D = null

func _ready():
	# Create UI elements
	setup_ui()

	# Connect to GameManager signals
	GameManager.stats_updated.connect(_on_stats_updated)
	GameManager.profile_loaded.connect(_on_profile_loaded)

func set_player_reference(player: CharacterBody2D):
	player_ref = player

func _process(_delta):
	# Update rhythm indicator if we have player reference
	if player_ref != null and is_instance_valid(player_ref):
		if player_ref.is_grounded and player_ref.physics_enabled:
			var time_until = player_ref.current_bounce_interval - player_ref.bounce_timer
			var timing_text = "BOUNCE: %.1fs" % time_until

			# Color code based on timing window
			if time_until <= 0.1:
				rhythm_label.add_theme_color_override("font_color", Color.YELLOW)
				timing_text = "PRESS NOW! GREAT"
			elif time_until <= 0.2:
				rhythm_label.add_theme_color_override("font_color", Color.GREEN)
				timing_text = "PRESS NOW! PERFECT"
			else:
				rhythm_label.add_theme_color_override("font_color", Color.WHITE)

			rhythm_label.text = timing_text
		else:
			rhythm_label.text = "IN AIR"
	else:
		rhythm_label.text = ""

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
	height_label.position = Vector2(300, 30)
	height_label.add_theme_font_size_override("font_size", 48)
	height_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 0.9))
	height_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	height_label.size = Vector2(200, 80)
	add_child(height_label)

	# Top-right: Timer display
	timer_label = Label.new()
	timer_label.position = Vector2(650, 10)
	timer_label.add_theme_font_size_override("font_size", 24)
	timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 0.9))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.size = Vector2(140, 50)
	add_child(timer_label)

	# Center-bottom: Rhythm timing indicator
	rhythm_label = Label.new()
	rhythm_label.position = Vector2(250, 850)
	rhythm_label.add_theme_font_size_override("font_size", 32)
	rhythm_label.add_theme_color_override("font_color", Color.WHITE)
	rhythm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rhythm_label.size = Vector2(300, 100)
	rhythm_label.text = "JUMP RHYTHM: --"
	add_child(rhythm_label)

	# Update initial values
	update_profile_display()

func update_profile_display():
	if GameManager.current_profile.is_empty():
		return

	profile_label.text = "Player: " + GameManager.current_profile.username
	high_score_label.text = "High Score: " + str(GameManager.current_profile.high_score)

func _on_stats_updated(stats: Dictionary):
	# Update height with label
	height_label.text = "HEIGHT: " + str(stats.height)

	# Update timer with format mm:ss (handle large values)
	var total_seconds = int(stats.time_survived)
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	# Cap minutes display at 99 to prevent overflow
	timer_label.text = "TIME: %d:%02d" % [min(minutes, 99), seconds]

func _on_profile_loaded(_profile: Dictionary):
	update_profile_display()

func update_height(height: int):
	height_label.text = "HEIGHT: " + str(height)
