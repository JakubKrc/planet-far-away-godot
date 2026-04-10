extends CanvasLayer

@onready var panel = $Panel
@onready var speaker_label = $Panel/Margin/VBox/Speaker
@onready var text_label = $Panel/Margin/VBox/Text
@onready var choices_container = $Panel/Margin/VBox/Choices

var _data: Dictionary = {}
var _current_id: String = ""
var _choices: Array = []
var _selection: int = 0

func _ready():
	Global.dialogue = self
	hide()

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
	Global.can_player_move = false
	show()
	_show_node("start")

func _show_node(id: String):
	_current_id = id
	var node: Dictionary = _data.get(id, {})
	if node.is_empty():
		_end()
		return
	var speaker = node.get("speaker", "")
	var text = node.get("text", "")
	speaker_label.hide()
	text_label.text = (speaker + ": " + text) if speaker != "" else text
	# Filter choices by inventory conditions
	_choices = []
	for choice in node.get("choices", []):
		if _check_conditions(choice):
			_choices.append(choice)
	# Rebuild choice labels
	for child in choices_container.get_children():
		child.free()
	if _choices.is_empty():
		var lbl = Label.new()
		lbl.text = "[ continue ]"
		lbl.add_theme_font_size_override("font_size", 7)
		choices_container.add_child(lbl)
	else:
		for choice in _choices:
			var lbl = Label.new()
			lbl.text = choice["text"]
			lbl.add_theme_font_size_override("font_size", 7)
			choices_container.add_child(lbl)
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

func _unhandled_input(event: InputEvent):
	if not visible:
		return
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
	if not visible:
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
	var inv = _player_inv()
	for key in choice.get("gives", {}):
		if key.begins_with("res://"):
			var item = load(key) as ItemData
			if item and inv:
				var pos = inv.find_free_slot(item)
				if pos != Vector2i(-1, -1):
					inv.place(item, pos)
		else:
			Global.inv_add(key, int(choice["gives"][key]))
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
	hide()
	Global.can_player_move = true
