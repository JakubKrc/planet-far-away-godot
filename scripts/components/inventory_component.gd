class_name InventoryComponent
extends Node

@export var cols: int = 8
@export var rows: int = 6

var _grid: Array = []        # [row][col] = ItemData or null
var _placements: Dictionary = {}  # ItemData -> Vector2i (top-left)

func _ready():
	_init_grid()

func _init_grid():
	_grid.clear()
	_grid.resize(rows)
	for i in rows:
		_grid[i] = []
		_grid[i].resize(cols)
		_grid[i].fill(null)

func can_place(item: ItemData, pos: Vector2i) -> bool:
	for dy in item.grid_size.y:
		for dx in item.grid_size.x:
			var gx = pos.x + dx
			var gy = pos.y + dy
			if gx < 0 or gx >= cols or gy < 0 or gy >= rows:
				return false
			var cell = _grid[gy][gx]
			if cell != null and cell != item:
				return false
	return true

func place(item: ItemData, pos: Vector2i):
	if _placements.has(item):
		_clear_cells(item)
	for dy in item.grid_size.y:
		for dx in item.grid_size.x:
			_grid[pos.y + dy][pos.x + dx] = item
	_placements[item] = pos

func remove(item: ItemData):
	_clear_cells(item)
	_placements.erase(item)

func _clear_cells(item: ItemData):
	for gy in rows:
		for gx in cols:
			if _grid[gy][gx] == item:
				_grid[gy][gx] = null

func get_at(pos: Vector2i) -> ItemData:
	if pos.x < 0 or pos.x >= cols or pos.y < 0 or pos.y >= rows:
		return null
	return _grid[pos.y][pos.x]

func get_pos(item: ItemData) -> Vector2i:
	return _placements.get(item, Vector2i(-1, -1))

func has_item(item: ItemData) -> bool:
	return _placements.has(item)

func all_items() -> Array:
	return _placements.keys()

func find_free_slot(item: ItemData) -> Vector2i:
	for gy in rows:
		for gx in cols:
			var pos = Vector2i(gx, gy)
			if can_place(item, pos):
				return pos
	return Vector2i(-1, -1)

func try_combine(item_a: ItemData, item_b: ItemData) -> ItemData:
	return item_a.combine_with.get(item_b.id, null)

# --- Simple id-based helpers (for quest/dialogue items) ---

func has_id(id: String, amount: int = 1) -> bool:
	var count = 0
	for item in _placements:
		if item.id == id:
			count += 1
			if count >= amount:
				return true
	return false

func remove_by_id(id: String, amount: int = 1):
	var removed = 0
	for item in _placements.keys():
		if item.id == id and removed < amount:
			remove(item)
			removed += 1

# --- Serialization ---

func serialize() -> Array:
	var out = []
	for item in _placements:
		if item.resource_path != "":
			var pos = _placements[item]
			out.append({"path": item.resource_path, "pos": [pos.x, pos.y]})
	return out

func deserialize(data: Array):
	_init_grid()
	for entry in data:
		var item = load(entry["path"]) as ItemData
		if item:
			place(item, Vector2i(entry["pos"][0], entry["pos"][1]))
