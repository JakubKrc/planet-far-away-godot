# The look shared by thoughts and place texts: game font, centred, wrapped, with
# a dark outline so it reads over walls and sky alike.
class_name FloatingTextLabel
extends Label

const TEXT_COLOUR = Color("dcdce2")
const OUTLINE_COLOUR = Color("3b3842")
const FONT_SIZE = 8

var _max_width: float = 120.0

func setup(max_width: float):
	_max_width = max_width
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	size = Vector2(max_width, 0)
	z_index = 50
	add_theme_color_override("font_color", TEXT_COLOUR)
	add_theme_color_override("font_outline_color", OUTLINE_COLOUR)
	add_theme_constant_override("outline_size", 3)
	Global.apply_to_label(self, FONT_SIZE)
	Global.ui_text_settings_changed.connect(_on_text_settings_changed)

func _on_text_settings_changed():
	Global.apply_to_label(self, FONT_SIZE)

# Places the label so its bottom centre sits on the given point. Setting the
# height to 0 lets the wrapped text grow it back to exactly what it needs.
func place_bottom_centre_at(point: Vector2):
	size = Vector2(_max_width, 0)
	global_position = point - Vector2(size.x / 2.0, size.y)
