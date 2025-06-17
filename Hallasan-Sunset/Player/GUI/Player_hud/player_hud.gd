class_name PlayerHUD extends CanvasLayer

var hearts: Array[HeartGUI] = []

@onready var game_over: Control = $Control/GameOver
@onready var continue_button: Button = $Control/GameOver/VBoxContainer/ContinueButton
@onready var title_button: Button = $Control/GameOver/VBoxContainer/TitleButton
@onready var animation_player: AnimationPlayer = $Control/GameOver/AnimationPlayer
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var abilities : Control = $Control/Abilities
@onready var ability_items : HBoxContainer = $Control/Abilities/HBoxContainer
@onready var arrow_count_label = $Control/Abilities/HBoxContainer/TextureRect3/ArrowCountLabel
@onready var bomb_count_label = $Control/Abilities/HBoxContainer/TextureRect4/BombCountLabel
@onready var boss_ui: Control = $Control/BossUI
@onready var boss_hp_bar: TextureProgressBar = $Control/BossUI/TextureProgressBar
@onready var boss_label: Label = $Control/BossUI/Label
@onready var notification : NotificationUI = $Control/Notification
@onready var area_notification = $"Control/Area Notification"
@onready var area_name: Label = $"Control/Area Notification/Label"
@onready var animation_player2 = $"Control/Area Notification/AnimationPlayer"
@onready var enemy_slain = $"Control/Enemy Slain"
@onready var animation_player3 = $"Control/Enemy Slain/AnimationPlayer"
@onready var energy_timer = $Timer

@export var tool_textures : Dictionary = {
	"Fists": preload("res://Hallasan-Sunset/UI/Pause Menu/Inventory/Equipables/Sprites/Fists.png"),
	"Earth Gloves": preload("res://Hallasan-Sunset/UI/Pause Menu/Inventory/Equipables/Sprites/Earth_gloves.png"),
	"Smash Gloves": preload("res://Hallasan-Sunset/UI/Pause Menu/Inventory/Equipables/Sprites/Untitled_Artwork 125.png")
}
func _ready():
	

	# Setup hearts
	for child in $Control/HFlowContainer.get_children():
		if child is HeartGUI:
			hearts.append(child)
			child.visible = false

	hide_game_over_screen()
	continue_button.pressed.connect(load_game)
	LevelManager.level_load_started.connect(hide_game_over_screen)
	hide_boss_health()
	hide_area_notification()
	hide_boss_slain()
	
	energy_timer.start()
	update_ability_ui(0)
	PauseMenu.shown.connect(_on_show_pause)
	PauseMenu.hidden.connect(_on_hide_pause)



func update_hp(_hp: int, _max_hp: int) -> void:
	update_max_hp(_max_hp)
	for i in _max_hp:
		update_heart(i, _hp)

func update_heart(_index: int, _hp: int) -> void:
	var _value: int = clampi(_hp - _index * 2, 0, 2)
	hearts[_index].value = _value

func update_max_hp(_max_hp: int) -> void:
	var _heart_count: int = roundi(_max_hp * 0.5)
	for i in hearts.size():
		if i < _heart_count:
			hearts[i].visible = true
		else:
			hearts[i].visible = false

func show_game_over_screen() -> void:
	game_over.visible = true
	game_over.mouse_filter = Control.MOUSE_FILTER_STOP

	var can_continue: bool = SaveManager.get_save_file() != null
	continue_button.visible = can_continue

	animation_player.play("show_game_over")
	await animation_player.animation_finished

	if can_continue == true:
		continue_button.grab_focus()
	else:
		title_button.grab_focus()

func hide_game_over_screen() -> void:
	game_over.visible = false
	game_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over.modulate = Color(1, 1, 1, 0)

func load_game() -> void:
	await fade_to_black()
	SaveManager.load_game()

func fade_to_black() -> bool:
	animation_player.play("fade_to_black")
	await animation_player.animation_finished
	PlayerManager.player.revive_player()
	return true

func play_audio(_a: AudioStream) -> void:
	audio.stream = _a
	audio.play()

func show_boss_health(boss_name: String) -> void:
	boss_ui.visible = true
	boss_label.text = boss_name
	update_boss_health(1, 1)

func hide_boss_health() -> void:
	boss_ui.visible = false

func update_boss_health(hp: int, max_hp: int) -> void:
	boss_hp_bar.value = clampf(float(hp) / float(max_hp) * 100, 0, 100)

func queue_notification( _title : String, _message : String ) -> void:
	notification.add_notification_to_queue( _title, _message )
	pass

func hide_area_notification() -> void:
	area_notification.visible = false
	
	
func show_area_notification(area_text: String) -> void:
	area_notification.visible = true
	area_name.text = area_text
	animation_player2.play("Fade_in")

func hide_boss_slain() -> void:
	enemy_slain.visible = false
	
	
func show_boss_slain() -> void:
	enemy_slain.visible = true
	animation_player3.play("Fade_in")
	
func _regenerate_energy():
	PlayerManager.player.current_energy +=1
	clampi(PlayerManager.player.current_energy,0,PlayerManager.player.max_energy)
	PlayerManager.energy_changed.emit()

func _on_timer_timeout():
	if PlayerManager.player.current_energy==PlayerManager.player.max_energy:
		return
	_regenerate_energy()
	pass # Replace with function body.

func _process(delta):
	if Input.is_action_just_pressed("tool_select"):
		$Control/SelectionWheel.show()
		
	elif Input.is_action_just_released("tool_select"):
		var tool = $Control/SelectionWheel.Close()
		$Control/Label.text = "Player Equipped Tool: " + tool
		if tool_textures.has(tool):
			$Control/Sprite2D.texture = tool_textures[tool]
		
		
		
func update_ability_ui(ability_index: int) -> void:
	var _items: Array[Node] = ability_items.get_children()
	for a in _items:
		a.self_modulate = Color(1, 1, 1, 0)
		a.modulate = Color(0.6, 0.6, 0.6, 0.8)

	_items[ability_index].self_modulate = Color(1, 1, 1, 1)
	_items[ability_index].modulate = Color(1, 1, 1, 1)
	
	pass




func update_arrow_count(count: int) -> void:
	arrow_count_label.text = str(count)
	pass

func update_bomb_count(count: int) -> void:
	bomb_count_label.text = str(count)
	pass

func _on_show_pause() -> void:
	abilities.visible = false
	pass

func _on_hide_pause() -> void:
	abilities.visible = true
	pass
