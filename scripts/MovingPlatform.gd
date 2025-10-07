extends Platform

@export var move_speed: float = 100.0
@export var move_range: float = 200.0

var start_x: float = 0.0
var direction: int = 1

func _ready():
	super._ready()
	platform_type = PlatformType.MOVING
	start_x = position.x

func _process(delta):
	if not is_active:
		return

	# Move horizontally
	position.x += direction * move_speed * delta

	# Reverse direction at boundaries
	if abs(position.x - start_x) >= move_range:
		direction *= -1
