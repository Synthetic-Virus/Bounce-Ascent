extends Platform

@export var disappear_time: float = 1.5  # Time before disappearing after landing
@export var warning_time: float = 0.5   # Flash warning time

var timer: float = 0.0
var player_has_landed: bool = false
var is_warning: bool = false

func _ready():
	super._ready()
	platform_type = PlatformType.TEMPORARY

func _process(delta):
	if not is_active or not player_has_landed:
		return

	timer += delta

	# Warning phase - flash
	if timer >= disappear_time - warning_time and not is_warning:
		is_warning = true
		start_warning_flash()

	# Disappear
	if timer >= disappear_time:
		disappear()

func on_player_land():
	if not player_has_landed:
		player_has_landed = true
		timer = 0.0

func start_warning_flash():
	var tween = create_tween()
	tween.set_loops(999)
	tween.tween_property(self, "modulate:a", 0.3, 0.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)

func disappear():
	# Disable collision
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(deactivate)
