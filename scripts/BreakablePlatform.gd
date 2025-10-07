extends Platform

var is_broken: bool = false

func _ready():
	super._ready()
	platform_type = PlatformType.BREAKABLE

func on_player_land():
	if not is_broken:
		is_broken = true
		GameManager.increment_platform_broken()
		break_platform()

func break_platform():
	# Create particle effect
	create_break_particles()

	# Disable collision
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	# Visual feedback - fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(deactivate)

func create_break_particles():
	# Simple particle effect using multiple small squares
	for i in range(8):
		var particle = Node2D.new()
		get_parent().add_child(particle)
		particle.global_position = global_position + Vector2(randf_range(-platform_width/2, platform_width/2), 0)

		var lifetime = randf_range(0.3, 0.6)
		var velocity = Vector2(randf_range(-100, 100), randf_range(-200, -50))

		# Animate particle
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", particle.position + velocity * lifetime, lifetime)
		tween.tween_property(particle, "modulate:a", 0.0, lifetime)
		tween.tween_callback(particle.queue_free)
