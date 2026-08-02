class_name UIKit
extends RefCounted

## Design tokens and widget factories for every screen.
##
## One place for colour, type and spacing so the menus, HUD and results screen
## cannot drift apart. Screens compose from here rather than hand-rolling
## Labels with ad-hoc sizes.
##
## TYPE
## ----
## Two system faces, so the project stays asset-free:
##
##   DISPLAY  Bahnschrift, condensed geometric, used uppercase with wide
##            tracking. Technical and poster-like rather than neutral.
##   DATA     Consolas, monospace, for every number and every table column.
##
## The mono face is not a stylistic flourish. Columns were previously aligned by
## padding strings with spaces in a PROPORTIONAL font, which cannot line up: a
## space is narrower than a digit, so "score      12" and "height     4" landed
## in different places. Tabular data belongs in a monospace face.

# --- Colour -----------------------------------------------------------------

const BG := Color("07030f")
const PANEL := Color("150b26")
const PANEL_EDGE := Color("2b1a47")

const CYAN := Color("5ef6ff")
const VIOLET := Color("b388ff")
const GOLD := Color("ffd84a")
const RED := Color("ff4b6e")

const TEXT := Color("ede7ff")
const DIM := Color("7a6b9e")

# --- Spacing ----------------------------------------------------------------

## Left margin for content, clearing the beat ruler.
const MARGIN: float = 56.0
const RULER_WIDTH: float = 22.0

## Top and bottom insets in VIEWPORT units, so content clears a notch or a home
## indicator. Returns zero on desktop.
##
## MOBILE ONLY, deliberately. DisplayServer.get_display_safe_area() reports a
## rect in VIRTUAL DESKTOP space, so on a multi-monitor desktop its position.y
## is an absolute offset between screens, not an inset. Treating it as an inset
## once pushed the entire menu 1728px down and off the screen.
##
## Headless could not catch that: screen_get_size() is (0,0) there, so the guard
## below returned zero and every layout assertion passed while the real window
## showed nothing. Hence the clamp as well as the platform check.
static func safe_area_insets() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO

	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.y <= 0 or safe.size.y <= 0:
		return Vector2.ZERO

	var scale := Tuning.PLAYFIELD_HEIGHT / float(screen.y)
	var top := float(safe.position.y) * scale
	var bottom := float(screen.y - (safe.position.y + safe.size.y)) * scale

	# No real notch or home indicator approaches 15% of the screen. Anything
	# larger is a misread, and clamping keeps a bad reading from hiding the UI.
	var limit := Tuning.PLAYFIELD_HEIGHT * 0.15
	return Vector2(clampf(top, 0.0, limit), clampf(bottom, 0.0, limit))


# --- Type -------------------------------------------------------------------

## Cached so every label does not re-resolve the system font.
##
## Typed as Font, not FontFile: SystemFont extends Font directly and resolves
## its family from the OS at load time.
static var _display: Font
static var _data: Font


## Condensed grotesque for headings and primary actions.
##
## The Apple entries are not optional garnish. The list used to be Bahnschrift,
## Segoe UI Semibold, Arial Narrow, every one of which is a WINDOWS face, so on
## iOS none resolved and headings dropped to Godot's generic built-in. The list
## was ordered for the machine it was written on: Windows matches on entry one,
## so the rest was never exercised during development.
##
## Avenir Next Condensed comes before SF Pro deliberately. SF is the more
## "native" answer, but this is a game and its display face should have some
## character; Avenir Next Condensed is also far closer to Bahnschrift's
## proportions, so the layout keeps the same rhythm across platforms.
static func display_font() -> Font:
	if _display == null:
		_display = _system([
			"Bahnschrift", "Segoe UI Semibold",          # Windows
			"Avenir Next Condensed", "SF Pro Display",   # iOS / macOS
			"Arial Narrow", "DejaVu Sans",               # last resort
		])
	return _display


## Monospace for body copy, data and most buttons.
##
## Monospace is load-bearing, not decoration: the track rows are laid out with
## printf padding ("%-13s"), which only lines up in a fixed-pitch face.
##
## Menlo is the important addition. Courier New was previously the ONLY name in
## this list that exists on iOS, so every non-primary button on the phone was
## rendering in a 1955 typewriter face, which is most of what made the menus
## look foreign.
static func data_font() -> Font:
	if _data == null:
		_data = _system([
			"Consolas", "Cascadia Mono",                 # Windows
			"SF Mono", "Menlo",                          # iOS / macOS
			"Courier New", "DejaVu Sans Mono",           # last resort
		])
	return _data


## Names are tried in order; if none resolve, Godot falls back to its default,
## so a machine without these faces still gets a working (if plainer) build.
static func _system(names: Array) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f


## A font with real letter-spacing, in pixels.
##
## FontVariation.spacing_glyph is proper tracking. An earlier version faked it by
## inserting space CHARACTERS between letters, which is far too wide (a space is
## most of a character width), breaks text measurement, and makes the string
## unsearchable and unreadable to a screen reader.
static func tracked(base: Font, pixels: int) -> Font:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = pixels
	return fv


## A display label: uppercase, lightly tracked, for headings and actions.
static func heading(text: String, size: int, color: Color = TEXT,
		tracking: int = 2) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", tracked(display_font(), tracking))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", -4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A data label: monospace, for numbers and anything that must align.
static func data(text: String, size: int, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", data_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Small uppercase category label, e.g. "TRACK". Structural, not decorative:
## it names what the following block is.
static func eyebrow(text: String, color: Color = DIM) -> Label:
	var l := data(text.to_upper(), 15, color)
	l.add_theme_font_override("font", tracked(data_font(), 3))
	return l


## Largest font size at or below `preferred` that fits `text` into `max_width`.
##
## Used for the wordmark. Hand-picking a size would be fine on this machine and
## broken on one without Bahnschrift, where a wider fallback loads and the
## title silently runs off the screen edge with no error.
static func fit_size(
	font: Font, text: String, max_width: float, preferred: int, minimum: int = 24
) -> int:
	var size := preferred
	while size > minimum:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_width:
			break
		size -= 2
	return size


## Group digits in threes, so a five-figure score is readable at a glance.
static func thousands(value: int) -> String:
	var s := str(absi(value))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if value < 0 else out



## Outline a label so it stays readable over the playfield.
static func outline(label: Label, size: int = 5) -> Label:
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", size)
	return label


# --- Widgets ----------------------------------------------------------------

## A filled panel style with a neon border.
## A short tap of the vibration motor, for touch feedback on a control.
##
## Guarded to mobile because vibrate_handheld does nothing on desktop and there
## is no reason to ask.
##
## Honest about the limits: Godot exposes a duration and amplitude, not the
## named iOS feedback styles, so this is a coarse buzz rather than a proper
## Taptic "light impact". Very short durations may be rounded up or ignored
## depending on the device. It is still much closer to how a phone should feel
## than silence.
static func haptic() -> void:
	if not OS.has_feature("mobile") or not Settings.haptics:
		return
	Input.vibrate_handheld(12)


## Corner radius for controls.
##
## 4px was a desktop-era value and read as a Windows dialog on a phone. Apple's
## controls sit around 10-14px at this size, and a touch target that is 88-120px
## tall needs the larger radius simply to look intentional rather than clipped.
const RADIUS: int = 12


static func box(fill: Color, border: Color, width: int = 1,
		radius: int = RADIUS) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


## A real Button, styled for this game.
##
## Real Controls rather than custom _draw: they get hover, pressed and keyboard
## FOCUS states for free, they participate in focus navigation, and they cannot
## be silently hidden behind a sibling the way hand-drawn UI can.
static func button(text: String, accent: Color = CYAN, size: int = 22,
		primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", display_font() if primary else data_font())
	b.add_theme_font_size_override("font_size", size)

	var fill := accent if primary else PANEL
	var text_col := BG if primary else TEXT

	b.add_theme_stylebox_override("normal", box(fill, accent if primary else PANEL_EDGE, 1))
	b.add_theme_stylebox_override("hover",
		box(fill.lightened(0.12) if primary else PANEL.lightened(0.10), accent, 2))

	# Pressed goes BRIGHTER, not darker.
	#
	# It used to darken by 15%, which is a mouse-era convention: on a desktop the
	# cursor never covers the control, so a subtle change is visible. On a phone
	# your thumb is on top of the button, so the only part still visible is the
	# rim, and a darkening reads as nothing happening. Lighting up the fill and
	# thickening the border puts the feedback where it can still be seen.
	b.add_theme_stylebox_override("pressed",
		box(fill.lightened(0.28) if primary else PANEL.lightened(0.30), accent, 3))
	# Haptic on button_down rather than pressed: button_down fires the instant
	# the finger lands, and feedback that waits for the release feels detached
	# from the touch that caused it.
	b.button_down.connect(haptic)
	# Focus is a distinct, high-contrast ring: keyboard players must be able to
	# see where they are without moving a mouse.
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), GOLD, 3))
	b.add_theme_stylebox_override("disabled", box(PANEL, PANEL_EDGE, 1))

	b.add_theme_color_override("font_color", text_col)
	b.add_theme_color_override("font_hover_color", text_col)
	b.add_theme_color_override("font_pressed_color", text_col)
	b.add_theme_color_override("font_focus_color", text_col)
	b.add_theme_color_override("font_disabled_color", DIM)
	return b


## A slider styled to match, for volume.
static func slider() -> HSlider:
	var s := HSlider.new()
	s.focus_mode = Control.FOCUS_ALL

	var track := StyleBoxFlat.new()
	track.bg_color = PANEL
	track.set_corner_radius_all(3)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	s.add_theme_stylebox_override("slider", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = CYAN
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	return s


# --- Drawing helpers --------------------------------------------------------

## Panel with a neon left edge. The edge carries the state colour, so a
## selected card reads at a glance without changing its size or position.
static func draw_card(
	ci: CanvasItem, rect: Rect2, accent: Color, selected: bool, pulse: float
) -> void:
	var fill := PANEL if not selected else PANEL.lightened(0.06)
	ci.draw_rect(rect, fill, true)

	# Border. Brighter and thicker when selected.
	var border := accent if selected else PANEL_EDGE
	var thickness := 2.0 if selected else 1.0
	ci.draw_rect(rect, Color(border.r, border.g, border.b,
		0.9 if selected else 0.5), false, thickness)

	# The state bar: a solid accent stripe down the leading edge.
	if selected:
		var bar := Rect2(rect.position.x, rect.position.y, 5.0, rect.size.y)
		ci.draw_rect(bar, accent, true)
		# Glow that breathes with the music.
		for i in range(3, 0, -1):
			var g := float(i) * 4.0 * (1.0 + pulse * 0.6)
			ci.draw_rect(
				Rect2(rect.position.x - g, rect.position.y - g,
					rect.size.x + g * 2.0, rect.size.y + g * 2.0),
				Color(accent.r, accent.g, accent.b, 0.05 + pulse * 0.03), false, 1.0)


## Difficulty as filled pips, which reads faster than a number or stars.
static func draw_pips(
	ci: CanvasItem, at: Vector2, filled: int, total: int, color: Color
) -> void:
	for i in total:
		var c := Vector2(at.x + float(i) * 15.0, at.y)
		if i < filled:
			ci.draw_circle(c, 5.0, color)
		else:
			ci.draw_arc(c, 5.0, 0.0, TAU, 12, Color(color.r, color.g, color.b, 0.35), 1.5)
