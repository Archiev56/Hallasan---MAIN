class_name FootstepAudio2D extends AudioStreamPlayer2D

@export var footstep_varient : Array [AudioStream]

var stream_randomiser : AudioStreamRandomizer

func ready_() -> void:
	
	pass

func play_footstep() -> void:
	get_footstep_type()
	play()
	
func get_footstep_type() -> void:
	for t in get_tree().get_nodes_in_group("tilemaps"):
		if t is TileMapLayer:
			if t.tile_set.get_custom_data_layer_by_name("footstep_type") == -1:
				continue
			var cell : Vector2i = t.local_to_map(t.to_local(global_position))
		
			var data : TileData = t.get_cell_tile_data(cell)
			if data:
				var type = data.get_custom_data("footstep_type")
				if type == null: 
					continue
				stream = footstep_varient[ type ]
	pass
