extends CanvasLayer

@onready var panel = $Panel
@onready var scroll: ScrollContainer = $Panel/Margin/VBox/Scroll
@onready var log_box: VBoxContainer = $Panel/Margin/VBox/Scroll/Log
@onready var choices_container: VBoxContainer = $Panel/Margin/VBox/Choices

const C_SPEAKER  = Color(0.42, 0.46, 0.95)
const C_TEXT     = Color(0.24, 0.60, 0.72)
const C_NOTIF    = Color(1.0, 1.0, 0.6)
const C_CHOSEN   = Color(0.85, 0.78, 0.40)

var _data: Dictionary = {}
var _current_id: String = ""
var _choices: Array = []
var _selection: int = 0
var _in_dialogue: bool = false
var _log_entries: Array = []   # plain strings, for clearing/recreating on font change

func _ready():
	Global.dialogue = self
	hide()
	Global.ui_text_settings_changed.connect(_rebuild_log_fonts)

# ── Public API ────────────────────────────────────────────────────

func start(json_path: String):
	if json_path == "":
		return
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Dialogue: file not found: " + json_path)
		return
	_data = JSON.parse_string(file.get_as_text())
	file.close()
	if _data == null:
		push_error("Dialogue: invalid JSON: " + json_path)
		return
	_in_dialogue = true
	Global.can_player_move = false
	show()
	_show_node("start")

func append_log(text: String, color: Color = C_TEXT):
	if text == "":
		return
	_log_entries.append([text, color])
	var lbl = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.modulate = Color(1, 1, 1)
	lbl.add_theme_color_override("font_color", color)
	Global.apply_to_label(lbl, 8)
	log_box.add_child(lbl)
	_scroll_to_bottom.call_deferred()

func append_notification(text: String):
	append_log(text, C_NOTIF)
	# Briefly flash the panel so player sees it
	if not visible:
		show()
		_auto_hide_after(2.5)

func clear_log():
	_log_entries.clear()
	for c in log_box.get_children():
		c.queue_free()

func _rebuild_log_fonts():
	for c in log_box.get_children():
		if c is Label:
			Global.apply_to_label(c, 8)

# ── Dialogue flow ─────────────────────────────────────────────────

func _show_node(id: String):
	_current_id = id
	var node: Dictionary = _data.get(id, {})
	if node.is_empty():
		_end()
		return
	var speaker = str(node.get("speaker", ""))
	var text    = str(node.get("text", ""))
	var line = (speaker + ": " + text) if speaker != "" else text
	append_log(line, C_TEXT)
	# Filter choices by inventory conditions
	_choices = []
	for choice in node.get("choices", []):
		if _check_conditions(choice):
			_choices.append(choice)
	for child in choices_container.get_children():
		child.free()
	if _choices.is_empty():
		var lbl = Label.new()
		lbl.text = "[ continue ]"
		choices_container.add_child(lbl)
		Global.apply_to_label(lbl, 7)
	else:
		for choice in _choices:
			var lbl = Label.new()
			lbl.text = choice["text"]
			choices_container.add_child(lbl)
			Global.apply_to_label(lbl, 7)
	_selection = 0
	_update_selection()

func _player_inv() -> InventoryComponent:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		return player.get_node_or_null("InventoryComponent") as InventoryComponent
	return null

func _check_conditions(choice: Dictionary) -> bool:
	var inv = _player_inv()
	for item_id in choice.get("requires", {}):
		var amount = int(choice["requires"][item_id])
		var has = inv.has_id(item_id, amount) if inv else Global.inv_has(item_id, amount)
		if not has:
			return false
	for item_id in choice.get("requires_not", {}):
		var amount = int(choice["requires_not"][item_id])
		var has = inv.has_id(item_id, amount) if inv else Global.inv_has(item_id, amount)
		if has:
			return false
	return true

func _update_selection():
	var children = choices_container.get_children()
	for i in children.size():
		children[i].modulate = Color(1, 1, 0) if i == _selection else Color(1, 1, 1)

func _scroll_to_bottom():
	if not is_inside_tree():
		return
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

# ── Input ─────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent):
	# Toggle log view when not in active dialogue
	if not _in_dialogue and event.is_action_pressed("toggle_log"):
		if visible:
			hide()
		else:
			show()
			_scroll_to_bottom.call_deferred()
		get_viewport().set_input_as_handled()
		return
	if _in_dialogue and visible:
		var count = choices_container.get_child_count()
		if count == 0:
			return
		if event.is_action_pressed("ui_down"):
			_selection = (_selection + 1) % count
			_update_selection()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up"):
			_selection = (_selection - 1 + count) % count
			_update_selection()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("use"):
			_advance()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent):
	if not _in_dialogue or not visible:
		return
	var children = choices_container.get_children()
	if event is InputEventMouseMotion:
		for i in children.size():
			if children[i].get_global_rect().has_point(event.global_position):
				if _selection != i:
					_selection = i
					_update_selection()
				break
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in children.size():
			if children[i].get_global_rect().has_point(event.global_position):
				_selection = i
				_advance()
				get_viewport().set_input_as_handled()
				return

func _advance():
	if _choices.is_empty():
		_end()
		return
	var choice = _choices[_selection]
	# Log the chosen line so the conversation is readable later
	append_log("> " + str(choice.get("text", "")), C_CHOSEN)
	var inv = _player_inv()
	for key in choice.get("gives", {}):
		if key.begins_with("res://"):
			var item = load(key) as ItemData
			if item and inv:
				var pos = inv.find_free_slot(item)
				if pos != Vector2i(-1, -1):
					inv.place(item, pos)
					var nm = item.item_name if item.item_name != "" else item.id
					append_log("Received: " + nm, Color(0.7, 0.85, 0.7))
		else:
			Global.inv_add(key, int(choice["gives"][key]))
			append_log("Received: %s x%d" % [str(key), int(choice["gives"][key])], Color(0.7, 0.85, 0.7))
	for item_id in choice.get("removes", {}):
		if inv:
			inv.remove_by_id(item_id, int(choice["removes"][item_id]))
		else:
			Global.inv_remove(item_id, int(choice["removes"][item_id]))
	var next = choice.get("next", null)
	if next == null or next == "":
		_end()
	else:
		_show_node(str(next))

func _end():
	_in_dialogue = false
	for child in choices_container.get_children():
		child.queue_free()
	hide()
	Global.can_player_move = true

# Auto-hide helper for notifications
var _hide_timer: Timer = null
func _auto_hide_after(secs: float):
	if _in_dialogue:
		return
	if _hide_timer == null:
		_hide_timer = Timer.new()
		_hide_timer.one_shot = true
		_hide_timer.timeout.connect(func(): if not _in_dialogue: hide())
		add_child(_hide_timer)
	_hide_timer.start(secs)
