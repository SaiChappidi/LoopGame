class_name LoopDesign
extends RefCounted
const BG = Color("0b0e15")
const PANEL = Color("151a24")
const TEXT = Color("f3f4f7")
const MUTED = Color("8d96a9")
const LIME = Color("c5e6d1")

static func box(color: Color, radius: int = 14, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(1 if border.a>0 else 0)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func label(value: String, font_size: int = 16, color: Color = TEXT) -> Label:
	var node = Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(value: String, callback: Callable, primary: bool = false) -> Button:
	var node = Button.new()
	node.text = value
	node.custom_minimum_size.y = 44
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size",14)
	node.add_theme_color_override("font_color",BG if primary else TEXT)
	node.add_theme_color_override("font_hover_color",BG if primary else TEXT)
	node.add_theme_stylebox_override("normal",box(LIME if primary else PANEL,12))
	node.add_theme_stylebox_override("hover",box(LIME.lightened(0.1) if primary else Color("242c3a"),12))
	node.add_theme_stylebox_override("pressed",box(LIME.darkened(0.15) if primary else Color("303a49"),12))
	node.add_theme_stylebox_override("focus",box(Color.TRANSPARENT,12,LIME))
	node.pressed.connect(callback)
	return node

static func paragraph(value: String, font_size: int = 15, color: Color = MUTED) -> Label:
	var node = label(value,font_size,color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node
