# In-game encyclopedia: entries exported from the Obsidian vault, showing only the
# ones the player has discovered. Opened with J or by clicking a link in dialogue.
extends CanvasLayer

const DATA_PATH = "res://data/encyclopedia.json"
const C_BG     = Color(0.08, 0.08, 0.12, 0.96)
const C_BORDER = Color(0.45, 0.45, 0.55)
const C_TEXT   = Color(0.85, 0.85, 0.90)
const C_DIM    = Color(0.60, 0.60, 0.68)
const C_LINK   = Color(0.95, 0.75, 0.35)
const MARGIN   = 12

var _entries: Dictionary = {}   # entry id -> {"title", "text"}
var _listed_ids: Array = []     # entry ids in the order the list shows them
var _current_id: String = ""

var _list: ItemList
var _text: RichTextLabel
var _heading: Label
var _title: Label
var _close_button: Button
var _link_pattern := RegEx.create_from_string("\\[url=([^\\]]+)\\](.*?)\\[/url\\]")

func _ready():
	layer = 11   # above the dialogue box and the inventory
	Global.encyclopedia = self
	_build_layout()
	load_entries(DATA_PATH)
	hide()
	Global.ui_text_settings_changed.connect(_apply_fonts)

# Tests point this at exported fixture data instead of the real game data.
func load_entries(path: String):
	_entries = {}
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_entries = parsed
	else:
		push_error("Encyclopedia: %s is not valid JSON" % path)

# Known means discovered in this run, or tagged #known_at_start in the vault.
func is_known(entry_id: String) -> bool:
	if not _entries.has(entry_id):
		return false
	if Global.known_entries.has(entry_id):
		return true
	return _entries[entry_id].get("known_at_start", false) == true

func title_of(entry_id: String) -> String:
	if _entries.has(entry_id):
		return str(_entries[entry_id]["title"])
	return entry_id

# ── Open / close ──────────────────────────────────────────────────

func open(entry_id: String = ""):
	if entry_id != "" and _entries.has(entry_id):
		if not is_known(entry_id):
			Global.learn_entry(entry_id)
		_current_id = entry_id
	_refresh_list()
	if _current_id == "" and not _listed_ids.is_empty():
		_current_id = _listed_ids[0]
	_show_entry(_current_id)
	show()
	Global.block_player_movement("encyclopedia")

func close():
	hide()
	Global.unblock_player_movement("encyclopedia")

func _input(event: InputEvent):
	var is_toggle_key = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J
	if is_toggle_key:
		if visible:
			close()
			get_viewport().set_input_as_handled()
		elif Global.game_state == Global.GameState.PLAYING:
			open()
			get_viewport().set_input_as_handled()
		return
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# ── Content ───────────────────────────────────────────────────────

# Lists the known entries alphabetically.
func _refresh_list():
	_listed_ids = []
	for entry_id in _entries:
		if is_known(entry_id):
			_listed_ids.append(entry_id)
	_listed_ids.sort_custom(func(a, b): return title_of(a).naturalnocasecmp_to(title_of(b)) < 0)
	_list.clear()
	for entry_id in _listed_ids:
		_list.add_item(title_of(entry_id))

func _show_entry(entry_id: String):
	if entry_id == "" or not _entries.has(entry_id):
		_heading.text = ""
		_text.text = "Nothing here yet. Talk to people to learn about the world."
		return
	_current_id = entry_id
	_heading.text = title_of(entry_id)
	_text.text = _links_for_reader(str(_entries[entry_id]["text"]))
	_text.scroll_to_line(0)
	var index = _listed_ids.find(entry_id)
	if index != -1:
		_list.select(index)
		_list.ensure_current_is_visible()

# Links to entries the player knows become coloured and clickable. Links to ones
# not yet discovered stay plain text until the player finds them elsewhere.
func _links_for_reader(bbcode: String) -> String:
	var result = ""
	var position = 0
	for found in _link_pattern.search_all(bbcode):
		result += bbcode.substr(position, found.get_start() - position)
		var entry_id = found.get_string(1)
		var link_text = found.get_string(2)
		if is_known(entry_id):
			result += "[url=%s][color=#%s]%s[/color][/url]" % [entry_id, C_LINK.to_html(false), link_text]
		else:
			result += link_text
		position = found.get_end()
	return result + bbcode.substr(position)

func _on_entry_selected(index: int):
	_show_entry(_listed_ids[index])

# Only links to known entries are clickable, so this just moves to that entry.
func _on_link_clicked(meta):
	var entry_id = str(meta)
	if is_known(entry_id):
		_show_entry(entry_id)

# ── Layout ────────────────────────────────────────────────────────

func _build_layout():
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = MARGIN
	panel.offset_top = MARGIN
	panel.offset_right = -MARGIN
	panel.offset_bottom = -MARGIN
	panel.add_theme_stylebox_override("panel", _box_style(C_BG))
	add_child(panel)

	var padding = MarginContainer.new()
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		padding.add_theme_constant_override(side, 6)
	panel.add_child(padding)

	var rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	padding.add_child(rows)

	var header = HBoxContainer.new()
	rows.add_child(header)
	_title = Label.new()
	_title.text = "ENCYCLOPEDIA"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", C_DIM)
	header.add_child(_title)
	_close_button = Button.new()
	_close_button.text = "x"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	var columns = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 6)
	rows.add_child(columns)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(90, 0)
	_list.focus_mode = Control.FOCUS_NONE
	_list.add_theme_stylebox_override("panel", _box_style(C_BG.darkened(0.3)))
	_list.add_theme_color_override("font_color", C_DIM)
	_list.add_theme_color_override("font_selected_color", C_TEXT)
	_list.item_selected.connect(_on_entry_selected)
	columns.add_child(_list)

	var reading = VBoxContainer.new()
	reading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(reading)
	_heading = Label.new()
	_heading.add_theme_color_override("font_color", C_TEXT)
	reading.add_child(_heading)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.focus_mode = Control.FOCUS_NONE
	_text.add_theme_color_override("default_color", C_TEXT)
	_text.meta_clicked.connect(_on_link_clicked)
	reading.add_child(_text)

	_apply_fonts()

func _box_style(colour: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	return style

func _apply_fonts():
	var font = Global.get_current_font()
	var list_size = maxi(1, int(7 * Global.ui_font_size_scale))
	if font:
		_list.add_theme_font_override("font", font)
		_close_button.add_theme_font_override("font", font)
	_list.add_theme_font_size_override("font_size", list_size)
	_close_button.add_theme_font_size_override("font_size", list_size)
	Global.apply_to_label(_title, 7)
	Global.apply_to_label(_heading, 8)
	Global.apply_to_rich_text(_text, 7)
