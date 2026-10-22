class_name InventoryItem
extends Resource
## An authored item definition. Ownership lives in GameState, never in the UI.
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
