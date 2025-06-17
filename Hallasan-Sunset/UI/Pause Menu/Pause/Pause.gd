extends CanvasLayer

signal shown
signal hidden

signal preview_stats_changed( item : ItemData )

@export var button_press_audio : AudioStream
@export var button_focus_audio : AudioStream

@onready var tab_container = $TabContainer
@onready var button_save: Button = $TabContainer/System/Panel2/VBoxContainer/Button_save
@onready var button_load: Button = $TabContainer/System/Panel2/VBoxContainer/Button_load
@onready var item_description: Label = $TabContainer/Inventory/DescriptionContainer/ItemDescription

@onready var audio_stream_player: AudioStreamPlayer2D = $Control/AudioStreamPlayer2D
@onready var audio_stream_player2: AudioStreamPlayer2D = $Control/AudioStreamPlayer2D2
@onready var audio_stream_player3: AudioStreamPlayer2D = $Control/AudioStreamPlayer2D3

@onready var button_settings : Button = $TabContainer/System/Panel2/VBoxContainer/Button_settings
@onready var button_menu : Button = $TabContainer/System/Panel2/VBoxContainer/Button_menu
@onready var button_quit : Button = $TabContainer/System/Panel2/VBoxContainer/Button_quit
@onready var animation_player = $Bag/AnimationPlayer

var is_paused : bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	hide_pause_menu()
	button_save.pressed.connect( _on_save_pressed )
	button_load.pressed.connect( _on_load_pressed )
	
	button_save.focus_entered.connect( play_audio.bind( button_focus_audio ) )
	button_load.focus_entered.connect( play_audio.bind( button_focus_audio ) )
	button_settings.focus_entered.connect( play_audio.bind( button_focus_audio ) )
	button_menu.focus_entered.connect( play_audio.bind( button_focus_audio ) )
	button_quit.focus_entered.connect( play_audio.bind( button_focus_audio ) )

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		if is_paused == false:
			if DialogSystem.is_active:
				return
			show_pause_menu()
			audio_stream_player.play()
		else:
			hide_pause_menu()
			audio_stream_player2.play()
		get_viewport().set_input_as_handled()
		
	if is_paused:
		if event.is_action_pressed("right_bumper"):
			change_tab( 1 )
			
		elif event.is_action_pressed("left_bumper"):
			
			
			change_tab( -1 )


func show_pause_menu() -> void:
	animation_player.play("open")
	get_tree().paused = true
	visible = true
	is_paused = true
	tab_container.current_tab = 0
	shown.emit()
	%ArrowCountLabel.text = str(PlayerManager.player.arrow_count)
	%BombCountLabel.text = str(PlayerManager.player.bomb_count)


func hide_pause_menu() -> void:
	get_tree().paused = false
	visible = false
	is_paused = false
	hidden.emit()


func _on_save_pressed() -> void:
	play_audio( button_press_audio )
	if is_paused == false:
		return
	SaveManager.save_game()
	hide_pause_menu()
	pass
	
func _on_load_pressed() -> void:
	play_audio( button_press_audio )
	if is_paused == false:
		return
	SaveManager.load_game()
	await LevelManager.level_load_started
	hide_pause_menu()
	pass
	
func update_item_description( new_text : String ) -> void:
	item_description.text = new_text


# Function to handle going to the main menu
func _on_main_menu_pressed():
	play_audio( button_press_audio )
	get_tree().paused = false
	hide_pause_menu()
	get_tree().change_scene_to_file("res://Hallasan-Sunset/UI/Main Menu.tscn")



# Function to quit the game
func _on_quit_pressed():
	get_tree().quit()
	play_audio( button_press_audio )
	
func play_audio( audio : AudioStream ) -> void:
	audio_stream_player.stream = audio
	audio_stream_player.play()
	
func change_tab( _i : int = 1 ) -> void:

	tab_container.current_tab = wrapi(
			tab_container.current_tab + _i,
			0,
			tab_container.get_tab_count()
			
			
		)
	tab_container.get_tab_bar().grab_focus()
	audio_stream_player3.play()
	

func focused_item_changed( slot : SlotData ) -> void:
	if slot:
		if slot.item_data:
			update_item_description( slot.item_data.description )
			preview_stats( slot.item_data )
	else:
		update_item_description("")
		preview_stats( null )

func preview_stats( item : ItemData ) -> void:
	preview_stats_changed.emit( item )
	pass
