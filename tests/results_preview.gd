extends Node
## Dev tool: show the results panel with a fixed result so it can be
## screenshotted without playing a run to completion.
const GameOver: PackedScene = preload("res://tests/ResultsPreviewPanel.tscn")

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.02, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var over := GameOver.instantiate()
	add_child(over)
	await get_tree().process_frame
	over.show_result({
		"song_name": "Vector Drive", "score": 128400, "height": 96,
		"max_combo": 34, "accuracy": 91.4,
		"perfect": 41, "great": 18, "good": 6, "miss": 3,
		"is_best": true,
	})
