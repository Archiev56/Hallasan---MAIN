extends Sprite2D

const FRAME_COUNT : int = 128




func _ready() -> void:
	PlayerManager.INVENTORY_DATA.equipment_changed.connect( _on_equipment_changed )
	SaveManager.game_loaded.connect( _on_equipment_changed )
	pass



func _process( _delta: float ) -> void:

	pass



func _on_equipment_changed() -> void:
	var equipment : Array[ SlotData ] = PlayerManager.INVENTORY_DATA.equipment_slots()
	texture = equipment[1].item_data.sprite_texture
	pass
