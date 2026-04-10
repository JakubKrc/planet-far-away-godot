class_name EquipmentComponent
extends Node

@export var slots: int = 4

var equipped: Array = []  # [ItemData or null] x slots

func _ready():
	equipped.resize(slots)
	equipped.fill(null)

func can_equip(item: ItemData) -> bool:
	if item.item_type == "":
		return false
	for e in equipped:
		if e != null and e != item and e.item_type == item.item_type:
			return false
	return true

func equip(item: ItemData, slot: int) -> ItemData:
	var old = equipped[slot]
	equipped[slot] = item
	return old

func unequip(slot: int) -> ItemData:
	var item = equipped[slot]
	equipped[slot] = null
	return item

func slot_of(item: ItemData) -> int:
	for i in equipped.size():
		if equipped[i] == item:
			return i
	return -1

func first_free_slot() -> int:
	for i in equipped.size():
		if equipped[i] == null:
			return i
	return -1

func serialize() -> Array:
	var out = []
	for i in equipped.size():
		if equipped[i] != null and equipped[i].resource_path != "":
			out.append({"slot": i, "path": equipped[i].resource_path})
	return out

func deserialize(data: Array):
	equipped.resize(slots)
	equipped.fill(null)
	for entry in data:
		var item = load(entry["path"]) as ItemData
		if item and entry["slot"] < slots:
			equipped[entry["slot"]] = item
