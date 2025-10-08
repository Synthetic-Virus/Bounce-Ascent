extends ColorRect

# Color transitions based on height
const SKY_COLOR = Color(0.53, 0.81, 0.92)      # Light blue sky
const SUNSET_COLOR = Color(0.98, 0.55, 0.38)   # Orange/pink sunset
const DUSK_COLOR = Color(0.25, 0.15, 0.35)     # Purple dusk
const SPACE_COLOR = Color(0.02, 0.02, 0.08)    # Dark space

# Height thresholds for color transitions (much higher for combo system)
const SUNSET_HEIGHT = 200
const DUSK_HEIGHT = 400
const SPACE_HEIGHT = 600

# Stars for space background
var stars: Array = []
const MAX_STARS = 100
var camera_ref: Camera2D = null

func _ready():
	# This will be set from Game.gd
	pass

func setup_background(camera: Camera2D):
	camera_ref = camera
	# Generate random stars
	for i in range(MAX_STARS):
		stars.append({
			"pos": Vector2(randf() * 800, randf() * 1000),
			"brightness": randf(),
			"size": randf_range(1.0, 3.0)
		})

func _process(_delta):
	# Follow the camera
	if camera_ref:
		global_position = camera_ref.global_position - Vector2(400, 500)

	# Get current height from GameManager
	var height = GameManager.session_stats.height if GameManager.session_stats.has("height") else 0

	# Calculate color based on height
	var bg_color = get_color_for_height(height)
	color = bg_color

	# Draw stars when in space
	if height >= DUSK_HEIGHT:
		queue_redraw()

func _draw():
	var height = GameManager.session_stats.height if GameManager.session_stats.has("height") else 0

	# Draw stars when transitioning to space
	if height >= DUSK_HEIGHT:
		var star_opacity = clamp((height - DUSK_HEIGHT) / float(SPACE_HEIGHT - DUSK_HEIGHT), 0.0, 1.0)

		for star in stars:
			var star_color = Color(1.0, 1.0, 1.0, star["brightness"] * star_opacity)
			draw_circle(star["pos"], star["size"], star_color)

func get_color_for_height(height: int) -> Color:
	if height < SUNSET_HEIGHT:
		# Sky to sunset
		var t = height / float(SUNSET_HEIGHT)
		return SKY_COLOR.lerp(SUNSET_COLOR, t)
	elif height < DUSK_HEIGHT:
		# Sunset to dusk
		var t = (height - SUNSET_HEIGHT) / float(DUSK_HEIGHT - SUNSET_HEIGHT)
		return SUNSET_COLOR.lerp(DUSK_COLOR, t)
	elif height < SPACE_HEIGHT:
		# Dusk to space
		var t = (height - DUSK_HEIGHT) / float(SPACE_HEIGHT - DUSK_HEIGHT)
		return DUSK_COLOR.lerp(SPACE_COLOR, t)
	else:
		# Full space
		return SPACE_COLOR
