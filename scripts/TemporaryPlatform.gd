extends Platform

@export var disappear_time: float = 2.0  # Time before falling after landing
@export var warning_time: float = 0.5   # Flash warning time
@export var fall_speed: float = 200.0   # How fast platform falls

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

	# Start falling animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 1000, 2.0)  # Fall down
	tween.tween_property(self, "modulate:a", 0.0, 1.0)  # Fade while falling
	tween.chain().tween_callback(deactivate)
