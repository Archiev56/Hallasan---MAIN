class_name PlayerHUD
extends CanvasLayer

const RECIPE_ITEM_SCENE = preload("res://Hallasan-Sunset/Technical/Workbench/Recipe_item.tscn")

var hearts: Array[HeartGUI] = []

@onready var game_over: Control = $Control/GameOver
@onready var continue_button: Button = $Control/GameOver/VBoxContainer/ContinueButton
@onready var title_button: Button = $Control/GameOver/VBoxContainer/TitleButton
@onready var animation_player: AnimationPlayer = $Control/GameOver/AnimationPlayer
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var abilities: Control = $Control/Abilities
@onready var ability_items: HBoxContainer = $Control/Abilities/HBoxContainer
@onready var boss_ui: Control = $Control/BossUI
@onready var boss_hp_bar: TextureProgressBar = $Control/BossUI/TextureProgressBar
@onready var boss_label: Label = $Control/BossUI/Label
@onready var notification: NotificationUI = $Control/Notification
@onready var area_notification = $"Control/Area Notification"
@onready var area_name: Label = $"Control/Area Notification/Label"
@onready var animation_player2 = $"Control/Area Notification/AnimationPlayer"
@onready var enemy_slain = $"Control/Enemy Slain"
@onready var animation_player3 = $"Control/Enemy Slain/AnimationPlayer"
@onready var energy_timer: Timer = $Timer
@onready var item_notification = $"Control/Item Notification"

# Item notification components
@onready var gained_item_label: Label = $"Control/Item Notification/ItemLabel"
@onready var item_gained: TextureRect = $"Control/Item Notification/ItemGained"
@onready var gained_item_animation_player = $"Control/Item Notification/GainedItemAnimationPlayer"

# Item notification system
var notification_queue: Array[ItemData] = []
var is_showing_item_notification: bool = false

func _ready():
	add_to_group("player_hud")
	add_to_group("ui")
	
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
	hide_item_notification()

	# --- ENERGY TIMER WIRING ---
	if not energy_timer.timeout.is_connected(_on_timer_timeout):
		energy_timer.timeout.connect(_on_timer_timeout)
	energy_timer.wait_time = 2.0      # regen interval (seconds) - tweak as needed
	energy_timer.one_shot = false
	energy_timer.start()
	# To regen while paused, uncomment:
	# energy_timer.process_mode = Node.PROCESS_MODE_ALWAYS

	# --- ABILITY UI INITIAL STATE (show only one icon) ---
	update_ability_ui(0) # pick your true initial index

func show_item_notification(item_data: ItemData) -> void:
	if not item_data:
		return
	
	notification_queue.append(item_data)
	
	if not is_showing_item_notification:
		_process_item_notification_queue()

func _process_item_notification_queue() -> void:
	if notification_queue.is_empty():
		is_showing_item_notification = false
		return
	
	is_showing_item_notification = true
	var item_data = notification_queue.pop_front()
	
	_setup_item_notification_content(item_data)
	_animate_item_notification(item_data)

func _setup_item_notification_content(item_data: ItemData) -> void:
	if item_gained and item_data.texture:
		item_gained.texture = item_data.texture
		item_gained.modulate = item_data.get_rarity_color()
	
	if gained_item_label:
		gained_item_label.text = "You gained the " + item_data.get_display_name()
		gained_item_label.modulate = item_data.get_rarity_color()

func _animate_item_notification(item_data: ItemData) -> void:
	item_notification.visible = true
	
	if gained_item_animation_player and gained_item_animation_player.has_animation("show"):
		gained_item_animation_player.play("show")
		await gained_item_animation_player.animation_finished
	else:
		await get_tree().create_timer(2.0).timeout
	
	hide_item_notification()
	await get_tree().create_timer(0.2).timeout
	_process_item_notification_queue()

func hide_item_notification() -> void:
	item_notification.visible = false

# ============================================================
#  EXISTING FUNCTIONS (unchanged)
# ============================================================

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

func queue_notification(_title: String, _message: String) -> void:
	notification.add_notification_to_queue(_title, _message)

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

# --- ENERGY (fixed clamp + timer use) ---
func _regenerate_energy() -> void:
	var p = PlayerManager.player
	p.current_energy = clampi(p.current_energy + 1, 0, p.max_energy)
	PlayerManager.energy_changed.emit()

func _on_timer_timeout() -> void:
	var p = PlayerManager.player
	if p.current_energy >= p.max_energy:
		return
	_regenerate_energy()

# --- ABILITY SELECTION (show only the selected icon) ---
func _process(delta):
	if Input.is_action_just_pressed("tool_select"):
		$Control/SelectionWheel.show()
	elif Input.is_action_just_released("tool_select"):
		var tool = $Control/SelectionWheel.Close()
		$Control/Label.text = "Player Equipped Tool: " + str(tool)
		update_ability_ui(_ability_index_from_tool(tool))

func _ability_index_from_tool(tool) -> int:
	# If tool is an index already
	if typeof(tool) == TYPE_INT:
		var items := ability_items.get_children()
		return clampi(tool, 0, max(0, items.size() - 1))
	# If tool is a name, find a child with matching name (case-insensitive)
	if typeof(tool) == TYPE_STRING:
		var items: Array = ability_items.get_children()
		var lower: String = String(tool).to_lower()
		for i in items.size():
			if str(items[i].name).to_lower() == lower:
				return i
	# Fallback to 0
	return 0

func update_ability_ui(ability_index: int) -> void:
	var items: Array = ability_items.get_children()
	for i in items.size():
		items[i].visible = (i == ability_index)  # show only the selected one

func _on_show_pause() -> void:
	abilities.visible = false

func _on_hide_pause() -> void:
	abilities.visible = true
