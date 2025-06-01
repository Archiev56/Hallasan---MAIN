extends Node2D

func _on_animation_player_animation_finished(anim_name: String) -> void:
	completed()

func _ready() -> void:
	self.y_sort_enabled = true
	PlayerManager.set_as_parent( self )
	LevelManager.level_load_started.connect( _free_level )
	
func completed() -> void:
	PlayerManager.player_spawned=false
	PlayerManager.player.camera_2d.position = Vector2.ZERO
	LevelManager.load_new_level("res://Hallasan-Sunset/Levels/Act1/Forest/Act_1_Scene_1.tscn","",Vector2.ZERO)

func _free_level() -> void:
	PlayerManager.unparent_player( self )
	queue_free()
