class_name EnergyBar extends Control

@onready var energy_bar = $"Energy Bar"

func _ready() -> void:
	PlayerManager.energy_changed.connect(update_energy_bar)
	pass
	
func update_energy_bar() -> void:
	energy_bar.max_value = PlayerManager.player.max_energy
	energy_bar.value = PlayerManager.player.current_energy
	print (energy_bar.value)
