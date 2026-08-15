extends CanvasLayer

# Layout
const CELL        = 16
const EQUIP_SLOT  = 32
const PAD         = 8
const EQUIP_GAP   = 4
const EQUIP_GRID_COLS = 2  # equip slots are laid out two per row
const SEP         = 6    # gap between equip and grid; between dual grids
const TITLE_H     = 13   # title bar, including the rule under it
const LANE_H      = 10   # header above each grid, dual mode only
const DROP_H      = 12   # height of the drop-to-ground strip
const HINT_TEXT   = "RMB drop  I close"
const HINT_GAP    = 5    # gap between the drop strip and the key hints
const TEXT_SIZE   = 7

# Colors
const C_BG        = Color(0.08, 0.08, 0.12, 0.96)
const C_BORDER    = Color(0.45, 0.45, 0.55)
const C_BORDER_DIM = Color(0.24, 0.24, 0.30)
const C_CELL      = Color(0.18, 0.18, 0.25)
const C_CELL_EMPTY = Color(0.13, 0.13, 0.19)
const C_CELL_OK   = Color(0.25, 0.40, 0.30)
const C_CELL_BAD  = Color(0.40, 0.20, 0.20)
const C_DROP      = Color(0.28, 0.18, 0.18)
const C_DROP_HOT  = Color(0.55, 0.25, 0.25)
const C_EQUIP     = Color(0.22, 0.22, 0.32)
const C_EQUIP_HOV = Color(0.32, 0.42, 0.52)
const C_ITEM      = Color(0.45, 0.65, 0.45)
const C_ITEM_DRAG = Color(0.45, 0.65, 0.45, 0.65)
const C_TXT       = Color(1.0, 1.0, 1.0)
const C_TXT_DIM   = Color(0.7, 0.7, 0.7)
const C_TIP_BG    = Color(0.06, 0.06, 0.10, 0.98)

# State
var _primary:   InventoryComponent = null
var _secondary: InventoryComponent = null   # chest / NPC (optional)
var _equipment: EquipmentComponent = null

var _drag_item:   ItemData = null
var _drag_src:    String   = ""   # "primary" | "secondary" | "equip"
var _drag_src_slot: int = -1
var _drag_offset: Vector2 = Vector2.ZERO      # pixel offset for smooth ghost drawing
var _drag_cell_offset: Vector2i = Vector2i.ZERO  # which cell of the item was grabbed

var _mouse: Vector2
var _hover_tip: ItemData = null

# Layout rects (computed in open())
var _panel:       Rect2
var _pri_origin:  Vector2
var _sec_origin:  Vector2   # valid only in dual mode
var _equip_rects: Array     # [Rect2], one per equip slot (0 to EquipmentComponent.MAX_SLOTS)
var _drop_rect:   Rect2     # drop-to-ground zone below equip slots
var _close_rect:  Rect2     # close button (X) in top-right corner
var _dual:        bool = false

signal item_thrown(item: ItemData, world_pos: Vector2)

var _control: Control

func _ready():
	Global.inventory_ui = self
	_control = Control.new()
	_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_control.mouse_filter = Control.MOUSE_FILTER_STOP
	_control.draw.connect(_on_draw)
	add_child(_control)
	hide()
	Global.ui_text_settings_changed.connect(func(): if visible: _control.queue_redraw())

func _font() -> Font:
	var f = Global.get_current_font()
	return f if f else ThemeDB.fallback_font

# ── Open / close ──────────────────────────────────────────────────

func open(primary: InventoryComponent, secondary: InventoryComponent = null):
	_primary   = primary
	_secondary = secondary
	var eq = primary.get_parent().get_node_or_null("EquipmentComponent") as EquipmentComponent
	_equipment = eq if (eq != null and eq.active) else null
	_dual      = secondary != null
	_compute_layout()
	show()
	Global.block_player_movement("inventory")
	_control.queue_redraw()

func close():
	if _drag_item:
		_cancel_drag()
	hide()
	Global.unblock_player_movement("inventory")
	_primary = null
	_secondary = null
	_equipment = null

# ── Layout ────────────────────────────────────────────────────────

# How many equip slots to draw. Zero is valid — a character may have no
# EquipmentComponent, or one configured with no slots.
func _equip_slot_count() -> int:
	return _equipment.slots if _equipment else 0

func _compute_layout():
	var slot_count = _equip_slot_count()
	var equip_cols = mini(slot_count, EQUIP_GRID_COLS)
	var equip_rows = ceili(float(slot_count) / EQUIP_GRID_COLS)
	var equip_w = 0
	var equip_h = 0
	if slot_count > 0:
		equip_w = equip_cols * EQUIP_SLOT + (equip_cols - 1) * EQUIP_GAP
		equip_h = equip_rows * EQUIP_SLOT + (equip_rows - 1) * EQUIP_GAP
	# A character with no equip slots gets no left column and no separator.
	var equip_gap_right = SEP if equip_w > 0 else 0

	var lane_h = LANE_H if _dual else 0
	var grid_w = _primary.cols * CELL
	var grid_h = _primary.rows * CELL
	var body_h = maxi(equip_h, grid_h + lane_h)

	var panel_w = PAD + equip_w + equip_gap_right + grid_w + PAD
	if _dual:
		panel_w += SEP + _secondary.cols * CELL
	var panel_h = TITLE_H + PAD + body_h + PAD + DROP_H + PAD

	# The hints are measured, not guessed, or they run off the panel edge.
	var hint_w = ceili(_font().get_string_size(
		HINT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x)
	var footer_reserve = HINT_GAP + hint_w
	panel_w = maxi(panel_w, PAD * 2 + EQUIP_SLOT + footer_reserve)

	var vp = get_viewport().get_visible_rect().size
	var panel_origin = ((vp - Vector2(panel_w, panel_h)) / 2.0).floor()
	_panel = Rect2(panel_origin, Vector2(panel_w, panel_h))

	var body_top = panel_origin.y + TITLE_H + PAD
	var equip_origin = Vector2(panel_origin.x + PAD,
							   body_top + (body_h - equip_h) / 2.0).floor()
	_equip_rects = []
	for i in slot_count:
		@warning_ignore("integer_division")
		var row = i / EQUIP_GRID_COLS
		var col = i % EQUIP_GRID_COLS
		_equip_rects.append(Rect2(
			equip_origin + Vector2(col * (EQUIP_SLOT + EQUIP_GAP),
								   row * (EQUIP_SLOT + EQUIP_GAP)),
			Vector2(EQUIP_SLOT, EQUIP_SLOT)))

	_pri_origin = Vector2(panel_origin.x + PAD + equip_w + equip_gap_right,
						  body_top + lane_h + (body_h - lane_h - grid_h) / 2.0).floor()
	if _dual:
		_sec_origin = _pri_origin + Vector2(grid_w + SEP, 0.0)

	# The drop strip runs along the bottom, leaving room for the key hints.
	var drop_w = panel_w - PAD * 2 - footer_reserve
	_drop_rect = Rect2(Vector2(panel_origin.x + PAD, _panel.end.y - PAD - DROP_H),
					   Vector2(drop_w, DROP_H))

	var close_size = 9
	_close_rect = Rect2(Vector2(_panel.end.x - close_size - 3, panel_origin.y + 2),
						Vector2(close_size, close_size))

# ── Pickup (from ground) ──────────────────────────────────────────

func pick_up(item: ItemData) -> bool:
	var target = _player_inventory()
	if target == null:
		return false
	# Scene-placed ground items point at a shared .tres, so take our own copy.
	var picked = item.make_unique_copy()
	var pos = target.find_free_slot(picked)
	if pos == Vector2i(-1, -1):
		return false
	target.place(picked, pos)
	_log("Picked up: " + _item_name(picked))
	if visible:
		_control.queue_redraw()
	return true

# The player's bag, whether or not the inventory screen is currently open.
func _player_inventory() -> InventoryComponent:
	if _primary != null:
		return _primary
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	return player.get_node_or_null("InventoryComponent") as InventoryComponent

# Hands an item to the player, dropping it at their feet when the bag is full.
# Callers that award items (dialogue rewards, scripted grants) use this so a
# full bag never destroys the reward.
func give_or_drop(item: ItemData):
	var target = _player_inventory()
	if target != null:
		var pos = target.find_free_slot(item)
		if pos != Vector2i(-1, -1):
			target.place(item, pos)
			if visible:
				_control.queue_redraw()
			return
	_drop_to_ground(item)

func _item_name(item: ItemData) -> String:
	if item == null: return "?"
	return item.item_name if item.item_name != "" else item.id

func _log(text: String):
	if Global.dialogue:
		Global.dialogue.append_log(text, Color(0.7, 0.85, 0.7))

# ── Input ─────────────────────────────────────────────────────────

func _input(event: InputEvent):
	# Toggle with I / Tab even when closed
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_I or event.physical_keycode == KEY_TAB:
			if visible:
				close()
			else:
				var player = get_tree().get_first_node_in_group("player")
				if player and player.is_on_floor():
					var inv = player.get_node_or_null("InventoryComponent")
					if inv:
						open(inv)
			get_viewport().set_input_as_handled()
			return

	if not visible:
		return

	if event is InputEventMouseMotion:
		_mouse = event.position
		_update_hover()
		_control.queue_redraw()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_lmb_down(event.position)
			else:
				_lmb_up(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_rmb(event.position)

# ── Hover ─────────────────────────────────────────────────────────

func _update_hover():
	_hover_tip = null
	var gp = _grid_pos(_mouse, _primary, _pri_origin)
	if gp != Vector2i(-1, -1):
		_hover_tip = _primary.get_at(gp)
		return
	if _dual:
		var gp2 = _grid_pos(_mouse, _secondary, _sec_origin)
		if gp2 != Vector2i(-1, -1):
			_hover_tip = _secondary.get_at(gp2)
			return
	var es = _equip_slot(_mouse)
	if es >= 0 and _equipment:
		_hover_tip = _equipment.equipped[es]

# ── Drag ──────────────────────────────────────────────────────────

func _pick_from(item: ItemData, src: String, slot: int = -1):
	_drag_item     = item
	_drag_src      = src
	_drag_src_slot = slot

func _cancel_drag():
	if _drag_item == null:
		return
	# Return to source, or to the ground if the source no longer has room.
	# Uses _player_inventory() so a drag is still recoverable if the screen has
	# already been torn down.
	if _drag_src == "primary":
		_place_or_throw(_player_inventory(), _drag_item)
	elif _drag_src == "secondary" and _secondary:
		_place_or_throw(_secondary, _drag_item)
	elif _drag_src == "equip" and _equipment:
		_equipment.equipped[_drag_src_slot] = _drag_item
	else:
		_throw(_drag_item)
	_drag_item = null
	_control.queue_redraw()

# Puts the item back in the given inventory, or on the ground if it will not fit.
func _place_or_throw(inv: InventoryComponent, item: ItemData):
	var pos = inv.find_free_slot(item) if inv else Vector2i(-1, -1)
	if pos != Vector2i(-1, -1):
		inv.place(item, pos)
	else:
		_throw(item)

func _lmb_down(mouse: Vector2):
	# Close button
	if _close_rect.has_point(mouse):
		close()
		return
	# Pick from primary grid
	var gp = _grid_pos(mouse, _primary, _pri_origin)
	if gp != Vector2i(-1, -1):
		var item = _primary.get_at(gp)
		if item:
			var item_pos = _primary.get_pos(item)
			_drag_offset = mouse - (_pri_origin + Vector2(item_pos) * CELL)
			_drag_cell_offset = gp - item_pos
			_primary.remove(item)
			_pick_from(item, "primary")
			_control.queue_redraw()
			return
	# Pick from secondary grid
	if _dual:
		var gp2 = _grid_pos(mouse, _secondary, _sec_origin)
		if gp2 != Vector2i(-1, -1):
			var item = _secondary.get_at(gp2)
			if item:
				var item_pos = _secondary.get_pos(item)
				_drag_offset = mouse - (_sec_origin + Vector2(item_pos) * CELL)
				_drag_cell_offset = gp2 - item_pos
				_secondary.remove(item)
				_pick_from(item, "secondary")
				_control.queue_redraw()
				return
	# Pick from equipment slot
	var es = _equip_slot(mouse)
	if es >= 0 and _equipment:
		var item = _equipment.equipped[es]
		if item:
			_drag_offset = mouse - _equip_rects[es].position
			_drag_cell_offset = Vector2i.ZERO
			_equipment.unequip(es)
			_pick_from(item, "equip", es)
			_control.queue_redraw()

func _lmb_up(mouse: Vector2):
	if _drag_item == null:
		return
	var item = _drag_item
	_drag_item = null

	# Try drop on primary grid — cell under mouse minus which cell was grabbed
	var cell = _grid_pos(mouse, _primary, _pri_origin)
	var gp = cell - _drag_cell_offset if cell != Vector2i(-1, -1) else Vector2i(-1, -1)
	if gp != Vector2i(-1, -1):
		var target = _primary.get_at(gp)
		if target != null and target != item:
			var result = _primary.try_combine(item, target)
			if result:
				_primary.remove(target)
				_place_or_throw(_primary, result)
			else:
				_place_or_throw(_primary, item)
		elif _primary.can_place(item, gp):
			_primary.place(item, gp)
		else:
			_place_or_throw(_primary, item)
		_control.queue_redraw()
		return

	# Try drop on secondary grid
	if _dual:
		var cell2 = _grid_pos(mouse, _secondary, _sec_origin)
		var gp2 = cell2 - _drag_cell_offset if cell2 != Vector2i(-1, -1) else Vector2i(-1, -1)
		if gp2 != Vector2i(-1, -1):
			var target = _secondary.get_at(gp2)
			if target != null and target != item:
				var result = _secondary.try_combine(item, target)
				if result:
					_secondary.remove(target)
					_place_or_throw(_secondary, result)
				else:
					_place_or_throw(_secondary, item)
			elif _secondary.can_place(item, gp2):
				_secondary.place(item, gp2)
			else:
				_place_or_throw(_secondary, item)
			_control.queue_redraw()
			return

	# Try equipment slot
	var es = _equip_slot(mouse)
	if es >= 0 and _equipment:
		if _equipment.can_equip(item):
			var displaced = _equipment.equip(item, es)
			_log("Equipped: " + _item_name(item))
			if displaced:
				_place_or_throw(_primary, displaced)
		else:
			_place_or_throw(_primary, item)
		_control.queue_redraw()
		return

	# Drop zone → throw to ground
	if _drop_rect.has_point(mouse):
		_throw(item)
		_control.queue_redraw()
		return

	# Outside panel → throw
	if not _panel.has_point(mouse):
		_throw(item)
	else:
		_place_or_throw(_primary, item)
	_control.queue_redraw()

# Drops the item on the ground and tells the player it left their bag.
func _throw(item: ItemData):
	_log("Dropped: " + _item_name(item))
	_drop_to_ground(item)

# Spawns the item on the ground without logging, for callers that describe the
# outcome themselves.
func _drop_to_ground(item: ItemData):
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		emit_signal("item_thrown", item, Vector2.ZERO)
		return
	var feet_y = 0.0
	var col = player.get_node_or_null("CollisionShape2D")
	if col and col.shape is RectangleShape2D:
		feet_y = col.position.y + (col.shape as RectangleShape2D).size.y / 2.0
	var item_half_h = 0.0
	var tex = item.get_world_texture()
	if tex:
		item_half_h = tex.get_height() / 2.0
	emit_signal("item_thrown", item, player.global_position + Vector2(0, feet_y - item_half_h + 1))

# Right-click: drop item to ground
func _rmb(mouse: Vector2):
	var gp = _grid_pos(mouse, _primary, _pri_origin)
	if gp != Vector2i(-1, -1):
		var item = _primary.get_at(gp)
		if item:
			_primary.remove(item)
			_throw(item)
			_control.queue_redraw()
		return
	if _dual:
		var gp2 = _grid_pos(mouse, _secondary, _sec_origin)
		if gp2 != Vector2i(-1, -1):
			var item = _secondary.get_at(gp2)
			if item:
				_secondary.remove(item)
				_throw(item)
				_control.queue_redraw()
			return
	var es = _equip_slot(mouse)
	if es >= 0 and _equipment:
		var item = _equipment.unequip(es)
		if item:
			_throw(item)
		_control.queue_redraw()

# ── Coordinate helpers ────────────────────────────────────────────

func _grid_pos(mouse: Vector2, inv: InventoryComponent, origin: Vector2) -> Vector2i:
	var rel = mouse - origin
	if rel.x < 0 or rel.y < 0:
		return Vector2i(-1, -1)
	var gx = int(rel.x / CELL)
	var gy = int(rel.y / CELL)
	if gx >= inv.cols or gy >= inv.rows:
		return Vector2i(-1, -1)
	return Vector2i(gx, gy)

func _equip_slot(mouse: Vector2) -> int:
	for i in _equip_rects.size():
		if _equip_rects[i].has_point(mouse):
			return i
	return -1

# ── Drawing ───────────────────────────────────────────────────────

func _on_draw():
	if _primary == null:
		return
	_draw_panel()
	_draw_title_bar()
	_draw_equip_slots()
	_draw_footer()
	_draw_lane_headers()
	_draw_grid(_primary, _pri_origin)
	if _dual:
		_draw_grid(_secondary, _sec_origin)
	_draw_items_in_inv(_primary, _pri_origin)
	if _dual:
		_draw_items_in_inv(_secondary, _sec_origin)
	_draw_equipped()
	_draw_drag_ghost()
	_draw_close_button()
	_draw_tooltip()

func _draw_panel():
	_control.draw_rect(_panel, C_BG)
	_control.draw_rect(_panel, C_BORDER, false)
	var body_top = _panel.position.y + TITLE_H + PAD
	var body_bottom = _drop_rect.position.y - PAD
	# Separator after the equip column, which is absent for characters with no slots.
	if not _equip_rects.is_empty():
		var sep_x = _pri_origin.x - SEP / 2.0
		_control.draw_line(Vector2(sep_x, body_top), Vector2(sep_x, body_bottom), C_BORDER)
	if _dual:
		var sep_x2 = _sec_origin.x - SEP / 2.0
		_control.draw_line(Vector2(sep_x2, body_top), Vector2(sep_x2, body_bottom), C_BORDER)

# Names whose bag this is. Matters now that you can possess other characters and
# open their inventory instead of your own.
func _draw_title_bar():
	var rule_y = _panel.position.y + TITLE_H
	_control.draw_line(Vector2(_panel.position.x, rule_y), Vector2(_panel.end.x, rule_y), C_BORDER)
	_control.draw_string(_font(),
		_panel.position + Vector2(PAD / 2.0, 9),
		_display_name(_primary), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, C_TXT)
	# In dual mode each grid carries its own count, so the bar would only repeat it.
	if _dual:
		return
	_control.draw_string(_font(),
		Vector2(_panel.position.x, _panel.position.y + 9),
		_capacity_text(_primary), HORIZONTAL_ALIGNMENT_RIGHT,
		int(_panel.size.x - 16), 7, C_TXT_DIM)

func _draw_lane_headers():
	if not _dual:
		return
	_draw_lane_header(_primary, _pri_origin)
	_draw_lane_header(_secondary, _sec_origin)

func _draw_lane_header(inv: InventoryComponent, origin: Vector2):
	var baseline = origin.y - 3
	_control.draw_string(_font(), Vector2(origin.x, baseline),
		_display_name(inv), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, C_TXT)
	_control.draw_string(_font(), Vector2(origin.x, baseline),
		_capacity_text(inv), HORIZONTAL_ALIGNMENT_RIGHT, inv.cols * CELL, 7, C_TXT_DIM)

func _display_name(inv: InventoryComponent) -> String:
	var owner_node = inv.get_parent()
	if owner_node == null:
		return ""
	var label = str(owner_node.name)
	if owner_node is CharacterBase and owner_node.character_id != "":
		label = owner_node.character_id
	return label.to_upper().replace("_", " ")

func _capacity_text(inv: InventoryComponent) -> String:
	var cells_used = 0
	for item in inv.all_items():
		cells_used += item.grid_size.x * item.grid_size.y
	return "%d / %d" % [cells_used, inv.cols * inv.rows]

func _draw_close_button():
	var hov = _close_rect.has_point(_mouse)
	_control.draw_rect(_close_rect, Color(0.55, 0.25, 0.25) if hov else Color(0.35, 0.18, 0.18))
	_control.draw_rect(_close_rect, C_BORDER, false)
	var p = _close_rect.position
	var s = _close_rect.size
	_control.draw_line(p + Vector2(2, 2), p + s - Vector2(2, 2), C_TXT, 1.0)
	_control.draw_line(p + Vector2(s.x - 2, 2), p + Vector2(2, s.y - 2), C_TXT, 1.0)

func _draw_footer():
	var hovered = _drag_item != null and _drop_rect.has_point(_mouse)
	_control.draw_rect(_drop_rect, C_DROP_HOT if hovered else C_DROP)
	_control.draw_rect(_drop_rect, C_BORDER, false)
	_control.draw_string(_font(),
		_drop_rect.position + Vector2(0, 9),
		"DROP TO GROUND", HORIZONTAL_ALIGNMENT_CENTER, int(_drop_rect.size.x), TEXT_SIZE,
		C_TXT * Color(1, 1, 1, 0.75))
	_control.draw_string(_font(),
		Vector2(_drop_rect.end.x + HINT_GAP, _drop_rect.position.y + 9),
		HINT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, C_TXT_DIM)

func _draw_equip_slots():
	for i in _equip_rects.size():
		var eq_item = _equipment.equipped[i] if _equipment else null
		var hov = _equip_slot(_mouse) == i
		_control.draw_rect(_equip_rects[i], C_EQUIP_HOV if hov else C_EQUIP)
		_control.draw_rect(_equip_rects[i], C_BORDER, false)
		if eq_item:
			_draw_item_in_rect(eq_item, _equip_rects[i])
		else:
			_control.draw_string(_font(),
				_equip_rects[i].position + Vector2(2, 10),
				str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
				C_TXT * Color(1, 1, 1, 0.3))

func _draw_grid(inv: InventoryComponent, origin: Vector2):
	# When dragging, top-left = cell under mouse minus which cell was grabbed
	var tl = Vector2i(-1, -1)
	if _drag_item != null:
		var c = _grid_pos(_mouse, inv, origin)
		if c != Vector2i(-1, -1):
			tl = c - _drag_cell_offset
	for gy in inv.rows:
		for gx in inv.cols:
			var rect = Rect2(origin + Vector2(gx * CELL, gy * CELL), Vector2(CELL, CELL))
			# Empty cells sit back so what you are carrying reads at a glance.
			var is_empty = inv.get_at(Vector2i(gx, gy)) == null
			var col = C_CELL_EMPTY if is_empty else C_CELL
			var border = C_BORDER_DIM if is_empty else C_BORDER
			if _drag_item != null and tl != Vector2i(-1, -1):
				if gx >= tl.x and gx < tl.x + _drag_item.grid_size.x and \
				   gy >= tl.y and gy < tl.y + _drag_item.grid_size.y:
					col = C_CELL_OK if inv.can_place(_drag_item, tl) else C_CELL_BAD
					border = C_BORDER
			_control.draw_rect(rect, col)
			_control.draw_rect(rect, border, false)

func _draw_items_in_inv(inv: InventoryComponent, origin: Vector2):
	for item in inv.all_items():
		var pos = inv.get_pos(item)
		var rect = Rect2(
			origin + Vector2(pos.x * CELL, pos.y * CELL),
			Vector2(item.grid_size.x * CELL, item.grid_size.y * CELL))
		_draw_item_in_rect(item, rect)

func _draw_equipped():
	if _equipment == null:
		return
	for i in _equip_rects.size():
		var item = _equipment.equipped[i]
		if item:
			_draw_item_in_rect(item, _equip_rects[i])

func _draw_item_in_rect(item: ItemData, rect: Rect2):
	var tex = item.get_icon()
	# No icon: fall back to a plain block with the item's name truncated onto it.
	if tex == null:
		_control.draw_rect(rect.grow(-1), C_ITEM)
		var max_chars = int(rect.size.x / 5)
		var label = item.item_name.substr(0, max_chars)
		_control.draw_string(_font(),
			rect.position + Vector2(1, 8),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, C_TXT)
		return
	# Centre the icon if it fits the cell, otherwise stretch it to fill.
	var icon_size = tex.get_size()
	if icon_size.x <= rect.size.x and icon_size.y <= rect.size.y:
		var pos = (rect.position + (rect.size - icon_size) / 2.0).floor()
		_control.draw_texture(tex, pos)
	else:
		_control.draw_texture_rect(tex, rect, false)

func _draw_drag_ghost():
	if _drag_item == null:
		return
	var size = Vector2(_drag_item.grid_size) * CELL
	var rect = Rect2(_mouse - _drag_offset, size)
	var tex = _drag_item.get_icon()
	if tex:
		_control.draw_texture_rect(tex, rect, false, C_ITEM_DRAG)
	else:
		_control.draw_rect(rect, C_ITEM_DRAG)

func _draw_tooltip():
	var tip = _hover_tip
	if tip == null or _drag_item != null:
		return
	var lines: Array = [tip.item_name]
	if tip.is_wearable:
		var type_tag = tip.item_type if tip.item_type != "" else "wearable"
		lines.append("[" + type_tag + "]")
	if tip.description != "":
		lines.append(tip.description)
	var font = _font()
	var fs = 7
	var lh = 9
	var max_w = 0.0
	for l in lines:
		max_w = max(max_w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var tip_size = Vector2(max_w + 6, lines.size() * lh + 4)
	var tip_pos  = _mouse + Vector2(10, -tip_size.y - 2)
	var _vp = get_viewport().get_visible_rect().size
	tip_pos.x = clamp(tip_pos.x, 0, _vp.x - tip_size.x)
	tip_pos.y = clamp(tip_pos.y, 0, _vp.y - tip_size.y)
	_control.draw_rect(Rect2(tip_pos, tip_size), C_TIP_BG)
	_control.draw_rect(Rect2(tip_pos, tip_size), C_BORDER, false)
	for i in lines.size():
		_control.draw_string(font,
			tip_pos + Vector2(3, (i + 1) * lh),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_TXT)
