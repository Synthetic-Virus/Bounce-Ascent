extends Platform

var is_broken: bool = false
var break_progress: float = 0.0
const BREAK_TIME: float = 0.5  # Time to fully dissolve

func _ready():
	super._ready()
	platform_type = PlatformType.BREAKABLE

func _process(delta):
	if is_broken and break_progress < 1.0:
		break_progress += delta / BREAK_TIME
		queue_redraw()  # Redraw to show dissolve effect

		# Disable collision when 80% dissolved
		if break_progress >= 0.8:
			for child in get_children():
				if child is CollisionShape2D:
					child.set_deferred("disabled", true)

		# Fully gone
		if break_progress >= 1.0:
			deactivate()

func on_player_land():
	if not is_broken:
		is_broken = true
		GameManager.increment_platform_broken()
		create_break_particles()

func _draw():
	# Draw dissolve effect - modify sprite transparency instead of drawing cracks
	if is_broken and break_progress > 0.0 and sprite:
		sprite.modulate.a = 1.0 - break_progress

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
