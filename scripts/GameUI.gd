extends CanvasLayer

# UI References
var profile_label: Label
var high_score_label: Label
var height_label: Label
var timer_label: Label
var rhythm_label: Label
var player_ref: CharacterBody2D = null
var last_jump_quality: String = ""
var jump_feedback_timer: float = 0.0

func _ready():
	# Create UI elements
	setup_ui()

	# Connect to GameManager signals
	GameManager.stats_updated.connect(_on_stats_updated)
	GameManager.profile_loaded.connect(_on_profile_loaded)

func set_player_reference(player: CharacterBody2D):
	player_ref = player
	# Connect to player's jumped signal to get quality feedback
	if player_ref and player_ref.has_signal("jumped"):
		player_ref.jumped.connect(_on_player_jumped)

func _process(delta):
	# Decay jump feedback timer
	if jump_feedback_timer > 0:
		jump_feedback_timer -= delta

	# Update rhythm indicator if we have player reference
	if player_ref != null and is_instance_valid(player_ref):
		if player_ref.is_grounded and player_ref.physics_enabled:
			var time_until = player_ref.current_bounce_interval - player_ref.bounce_timer
			var timing_text = "BOUNCE: %.1fs" % time_until

			# Color code based on timing window
			if time_until <= 0.1:
				rhythm_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))  # Bright green
				timing_text = "PRESS NOW! PERFECT"
			elif time_until <= 0.2:
				rhythm_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))  # Yellow
				timing_text = "PRESS NOW! GREAT"
			else:
				rhythm_label.add_theme_color_override("font_color", Color.WHITE)

			rhythm_label.text = timing_text
		else:
			# Show jump quality feedback while in air
			if jump_feedback_timer > 0:
				show_jump_feedback()
			else:
				rhythm_label.text = ""
	else:
		rhythm_label.text = ""

func _on_player_jumped(quality: String):
	"""Called when player jumps with quality: 'perfect', 'great', or other"""
	last_jump_quality = quality
	jump_feedback_timer = 1.0  # Show feedback for 1 second

	# Trigger animation based on quality
	if quality == "perfect":
		animate_perfect_jump()
	elif quality == "great":
		animate_close_jump()

func show_jump_feedback():
	"""Display the jump quality text"""
	if last_jump_quality == "perfect":
		rhythm_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))  # Bright green
		rhythm_label.text = "PERFECT!"
	elif last_jump_quality == "great":
		rhythm_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))  # Yellow
		rhythm_label.text = "GREAT!"
	else:
		rhythm_label.text = ""

func animate_close_jump():
	"""Wiggle animation for GREAT jumps (yellow window, good power)"""
	var tween = create_tween()
	tween.set_parallel(true)
	# Slightly larger font
	tween.tween_property(rhythm_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(rhythm_label, "rotation", deg_to_rad(5), 0.05)
	tween.chain().tween_property(rhythm_label, "rotation", deg_to_rad(-5), 0.05)
	tween.chain().tween_property(rhythm_label, "rotation", deg_to_rad(0), 0.05)
	tween.set_parallel(false)
	tween.tween_property(rhythm_label, "scale", Vector2(1.0, 1.0), 0.2)

func animate_perfect_jump():
	"""Grow and wiggle animation for PERFECT jumps (green window, best power)"""
	var tween = create_tween()
	tween.set_parallel(true)
	# Much larger font
	tween.tween_property(rhythm_label, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(rhythm_label, "rotation", deg_to_rad(10), 0.075)
	tween.chain().tween_property(rhythm_label, "rotation", deg_to_rad(-10), 0.075)
	tween.chain().tween_property(rhythm_label, "rotation", deg_to_rad(5), 0.075)
	tween.chain().tween_property(rhythm_label, "rotation", deg_to_rad(0), 0.075)
	tween.set_parallel(false)
	tween.tween_property(rhythm_label, "scale", Vector2(1.0, 1.0), 0.3)

func setup_ui():
	# Top-left: Profile name and high score
	var top_left_container = VBoxContainer.new()
	top_left_container.position = Vector2(10, 10)
	add_child(top_left_container)

	profile_label = Label.new()
	profile_label.add_theme_font_size_override("font_size", 14)
	profile_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	profile_label.add_theme_color_override("font_outline_color", Color.BLACK)
	profile_label.add_theme_constant_override("outline_size", 4)
	top_left_container.add_child(profile_label)

	high_score_label = Label.new()
	high_score_label.add_theme_font_size_override("font_size", 14)
	high_score_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	high_score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	high_score_label.add_theme_constant_override("outline_size", 4)
	top_left_container.add_child(high_score_label)

	# Center-top: Large height display
	height_label = Label.new()
	height_label.position = Vector2(300, 30)
	height_label.add_theme_font_size_override("font_size", 48)
	height_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 0.9))
	height_label.add_theme_color_override("font_outline_color", Color.BLACK)
	height_label.add_theme_constant_override("outline_size", 8)
	height_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	height_label.size = Vector2(200, 80)
	add_child(height_label)

	# Top-right: Timer display
	timer_label = Label.new()
	timer_label.position = Vector2(650, 10)
	timer_label.add_theme_font_size_override("font_size", 24)
	timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 0.9))
	timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	timer_label.add_theme_constant_override("outline_size", 6)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.size = Vector2(140, 50)
	add_child(timer_label)

	# Center: Rhythm timing indicator (below height counter)
	rhythm_label = Label.new()
	rhythm_label.position = Vector2(200, 120)
	rhythm_label.add_theme_font_size_override("font_size", 28)
	rhythm_label.add_theme_color_override("font_color", Color.WHITE)
	rhythm_label.add_theme_color_override("font_outline_color", Color.BLACK)
	rhythm_label.add_theme_constant_override("outline_size", 8)
	rhythm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rhythm_label.size = Vector2(400, 60)
	rhythm_label.text = ""
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
