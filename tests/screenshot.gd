extends Node

## Capture real frames of the game to PNG, for looking at.
##
##   godot --path <project> --resolution 720x1560 res://tests/Screenshot.tscn
##
## NOT headless: headless has no renderer, so there is nothing to capture. This
## needs a display, which under WSL means WSLg.
##
## Every other test in this project asserts something a number can express.
## Art cannot be asserted that way, and "it should look better" is not a claim
## anything here can check. So this exists to produce the artefact a human (or a
## model that can see) can judge, rather than to pass or fail.
##
## Shots are taken at musically meaningful moments, because half of this game's
## look is reactive: a frame captured on a beat and one captured between beats
## are different pictures, and judging the art from whichever frame happened to
## land first would be judging it by accident.

const GameScene: PackedScene = preload("res://scenes/Game.tscn")

const OUT_DIR: String = "user://shots"

## Seconds into the run to capture, and what each moment is for.
const SHOTS: Array = [
	{"at": 1.0, "name": "countin", "why": "count-in, approach ring wide"},
	{"at": 6.0, "name": "early", "why": "first hops, tier 2-4, plain platforms"},
	{"at": 14.0, "name": "mid", "why": "MOVING platforms have unlocked"},
	{"at": 24.0, "name": "late", "why": "higher tiers, narrower platforms"},
]

var _game: Node2D


func _ready() -> void:
	print("=== Bounce Ascent screenshot ===")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var waited := 0.0
	while not Music.all_ready() and waited < 120.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25

	_game = GameScene.instantiate()
	add_child(_game)
	await get_tree().process_frame

	var player: CharacterBody2D = _game.get_node("Player")
	var spawner: Node2D = _game.get_node("PlatformSpawner")

	var elapsed := 0.0
	var next := 0
	while next < SHOTS.size():
		_steer(player, spawner)
		await get_tree().process_frame
		elapsed += get_process_delta_time()

		var shot: Dictionary = SHOTS[next]
		if elapsed >= float(shot["at"]):
			await _capture(String(shot["name"]), String(shot["why"]))
			next += 1

		if _game.state == _game.State.DEAD:
			# Restart rather than stop: a dead run would leave the remaining
			# shots unfilled, and a results screen is not what is being judged.
			_game._on_restart_requested()
			await get_tree().process_frame

	print("---")
	print("wrote %d shots to %s" % [SHOTS.size(),
		ProjectSettings.globalize_path(OUT_DIR)])
	get_tree().quit(0)


func _capture(shot_name: String, why: String) -> void:
	# Wait for the frame to be fully drawn. Without this the texture read can
	# land mid-frame and capture a partially composited image, which looks like
	# an art bug and is not one.
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, shot_name]
	var err := image.save_png(path)
	if err != OK:
		print("    FAILED to write %s (error %d)" % [path, err])
		return
	print("    %-10s %dx%d  %s" % [shot_name, image.get_width(),
		image.get_height(), why])


## Same steering controller as the other probes, so the shots show the game
## being played rather than a body falling.
func _steer(player: CharacterBody2D, spawner: Node2D) -> void:
	var target_x: float = spawner.x_of_tier(player.current_tier + 1)
	if target_x < 0.0:
		Input.action_release("move_left")
		Input.action_release("move_right")
		return

	var w: float = Tuning.PLAYFIELD_WIDTH
	var dx: float = fposmod(target_x - player.global_position.x + w * 0.5, w) - w * 0.5
	var vx: float = player.velocity.x
	var braking_distance: float = (vx * vx) / (2.0 * Tuning.AIR_ACCEL)

	if absf(dx) < 6.0 and absf(vx) < 60.0:
		Input.action_release("move_left")
		Input.action_release("move_right")
		return

	var want_right: bool
	if dx > 0.0:
		want_right = not (vx > 0.0 and braking_distance >= dx)
	else:
		want_right = (vx < 0.0 and braking_distance >= -dx)

	if want_right:
		Input.action_release("move_left")
		Input.action_press("move_right")
	else:
		Input.action_release("move_right")
		Input.action_press("move_left")
