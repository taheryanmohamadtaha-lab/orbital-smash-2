class_name UIKit
extends RefCounted
## Small helpers that build consistent, touch-friendly UI controls in code.

static func style(bg: Color, radius: int = 28, border_bottom: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_width_bottom = border_bottom
	sb.border_color = bg.darkened(0.35)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb

static func button(text: String, color: Color, min_size: Vector2 = Vector2(320, 110), font_size: int = 44) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	b.add_theme_stylebox_override("normal", style(color))
	b.add_theme_stylebox_override("hover", style(color.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", style(color.darkened(0.2), 28, 2))
	b.add_theme_stylebox_override("disabled", style(color.darkened(0.5)))
	b.pressed.connect(func(): GameState.audio.play("click"))
	return b

static func label(text: String, size: int = 36, color: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_direction = Control.TEXT_DIRECTION_AUTO
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", maxi(2, size / 8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func panel(color: Color, radius: int = 36) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func vbox(sep: int = 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

static func hbox(sep: int = 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

static func margin(l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m

static func bar(fill: Color, height: int = 26) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, height)
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(height)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(height)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	return pb

static func star_text(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(3 - n)

## Returns (top, bottom) safe-area insets in viewport units (0 on desktop).
static func safe_insets(node: Node) -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0:
		return Vector2.ZERO
	var vp := node.get_viewport().get_visible_rect().size
	var s := vp.x / win.x
	var safe := Rect2(DisplayServer.get_display_safe_area())
	return Vector2(maxf(0.0, safe.position.y) * s, maxf(0.0, win.y - safe.end.y) * s)
