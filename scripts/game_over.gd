extends CanvasLayer

## End-of-run results.
##
## Shown as an overlay so the dead playfield stays visible behind it: you can
## see exactly where you fell, which is more useful than a black screen.
##
## The breakdown is deliberately detailed. After a run the interesting question
## is never "what did I score", it is "where did my timing go", and the
## judgement counts answer that where the score alone cannot.
##
## Columns are drawn with a monospace font at fixed x positions. The previous
## version padded label strings with spaces in a PROPORTIONAL font, which cannot
## align: a space is narrower than a digit, so every row started somewhere
## different.

signal restart_requested
signal menu_requested

const ROW_HEIGHT: float = 40.0

var _visible_result: Dictionary = {}
var _panel: Control
var _again: Button
var _back: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = _build()
	add_child(_panel)
	visible = false


func _build() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.draw.connect(_draw_panel.bind(root))

	# Real buttons for the actions, matching the menu. Children draw after the
	# parent, so these correctly sit above everything _draw_panel paints.
	var actions := VBoxContainer.new()
	actions.position = Vector2(UIKit.MARGIN, Tuning.PLAYFIELD_HEIGHT - 260.0)
	actions.size = Vector2(Tuning.PLAYFIELD_WIDTH - UIKit.MARGIN * 2.0, 170.0)
	actions.add_theme_constant_override("separation", 12)
	actions.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(actions)

	_again = UIKit.button("CLIMB AGAIN", UIKit.GOLD, 28, true)
	_again.custom_minimum_size = Vector2(0, 78)
	_again.process_mode = Node.PROCESS_MODE_ALWAYS
	_again.pressed.connect(func(): _confirm_restart())
	actions.add_child(_again)

	_back = UIKit.button("Back to tracks", UIKit.CYAN, 20)
	_back.process_mode = Node.PROCESS_MODE_ALWAYS
	_back.pressed.connect(func(): _confirm_menu())
	actions.add_child(_back)

	return root


func _confirm_restart() -> void:
	Music.play_sfx("ui_confirm")
	restart_requested.emit()


func _confirm_menu() -> void:
	Music.play_sfx("ui_move")
	menu_requested.emit()


func show_result(result: Dictionary) -> void:
	_visible_result = result
	visible = true
	_panel.queue_redraw()


func hide_panel() -> void:
	visible = false


func _process(_delta: float) -> void:
	if visible:
		_panel.queue_redraw()


func _draw_panel(ci: CanvasItem) -> void:
	if _visible_result.is_empty():
		return

	var w := Tuning.PLAYFIELD_WIDTH
	var h := Tuning.PLAYFIELD_HEIGHT

	ci.draw_rect(Rect2(0, 0, w, h), Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.9), true)

	var best: bool = _visible_result.get("is_best", false)
	var accent: Color = UIKit.GOLD if best else UIKit.RED
	var display := UIKit.display_font()
	var data := UIKit.data_font()

	var x := UIKit.MARGIN
	var y := 210.0

	# Headline states the outcome in one word. Auto-fitted, because tracked
	# display text at a fixed size runs off the edge on a narrow viewport or a
	# wider fallback font.
	var head := "NEW BEST" if best else "FELL"
	var avail := w - UIKit.MARGIN * 2.0
	ci.draw_string(display, Vector2(x, y), head, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UIKit.fit_size(display, head, avail, 62), accent)
	y += 34.0
	ci.draw_string(data, Vector2(x + 4.0, y), str(_visible_result.get("song_name", "")),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIKit.DIM)

	# Score, given the space it earns.
	y += 96.0
	ci.draw_string(data, Vector2(x, y),
		UIKit.thousands(_visible_result.get("score", 0)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 72, UIKit.TEXT)
	ci.draw_string(data, Vector2(x + 4.0, y + 46.0), "SCORE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIKit.DIM)

	# Two aligned columns: label left, value right. Fixed x, monospace.
	y += 92.0
	var value_x := w - UIKit.MARGIN - 150.0
	_row(ci, x, value_x, y, "height", "%d m" % _visible_result.get("height", 0), UIKit.TEXT)
	y += ROW_HEIGHT
	_row(ci, x, value_x, y, "best combo", "%d" % _visible_result.get("max_combo", 0), UIKit.TEXT)
	y += ROW_HEIGHT
	_row(ci, x, value_x, y, "accuracy", "%.1f%%" % _visible_result.get("accuracy", 0.0), UIKit.TEXT)

	# Judgement breakdown, colour coded to match the in-run popups.
	y += ROW_HEIGHT + 26.0
	ci.draw_rect(Rect2(x, y - 18.0, w - UIKit.MARGIN * 2.0, 1.0),
		Color(UIKit.PANEL_EDGE.r, UIKit.PANEL_EDGE.g, UIKit.PANEL_EDGE.b, 1.0), true)

	_row(ci, x, value_x, y, "perfect", "%d" % _visible_result.get("perfect", 0),
		Tuning.judgement_color(Tuning.Judgement.PERFECT))
	y += ROW_HEIGHT
	_row(ci, x, value_x, y, "great", "%d" % _visible_result.get("great", 0),
		Tuning.judgement_color(Tuning.Judgement.GREAT))
	y += ROW_HEIGHT
	_row(ci, x, value_x, y, "good", "%d" % _visible_result.get("good", 0),
		Tuning.judgement_color(Tuning.Judgement.GOOD))
	y += ROW_HEIGHT
	_row(ci, x, value_x, y, "miss", "%d" % _visible_result.get("miss", 0),
		Tuning.judgement_color(Tuning.Judgement.MISS))


## One label/value row. Value is right-aligned against a fixed column so the
## numbers form a clean edge regardless of their width.
func _row(ci: CanvasItem, label_x: float, value_x: float, y: float,
		label: String, value: String, color: Color) -> void:
	var data := UIKit.data_font()
	ci.draw_string(data, Vector2(label_x, y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIKit.DIM)
	ci.draw_string(data, Vector2(value_x, y), value,
		HORIZONTAL_ALIGNMENT_RIGHT, 150.0, 24, color)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("restart"):
		Music.play_sfx("ui_confirm")
		restart_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		Music.play_sfx("ui_move")
		menu_requested.emit()
		get_viewport().set_input_as_handled()
