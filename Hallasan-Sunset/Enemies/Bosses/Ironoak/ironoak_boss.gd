extends CharacterBody2D

const PICKUP = preload("res://Hallasan-Sunset/Items/Technical/item_pickup/item_pickup.tscn")

 
@onready var animation_player = $AnimationPlayer

@onready var animation_player2 = $"../../Environment/Borders/SideBorder/AnimationPlayer"

@export_category("Item Drops")
@export var drops : Array[ DropData ]
@export var hp : int = 10
@export var max_hp : int = 10
@onready var hurt_box : HurtBox = $HurtBox
@onready var hit_box : HitBox = $HitBox
@onready var timer = $BranchSpawner/Timer

var boss_defeat = false 

var time_scale = 1

func _ready() -> void:

		
	hp = max_hp
	PlayerHud.show_boss_health( "Iron Oak" )
	hit_box.damaged.connect( damage_taken )

func _on_animation_finished(anim_name):
	if anim_name != "Death":
		animation_player.play("idle")
 
 
func _on_player_entered(body):
	animation_player.play("attack")
 
 
func damage_taken(body):
	animation_player.play("Hurt")
	hp = clampi( hp - hurt_box.damage, 0, max_hp )
	PlayerHud.update_boss_health( hp, max_hp )
	PlayerManager.shake_camera()
	if hp < 1:
		defeat()
	pass
 
func defeat() -> void:
	boss_defeat = true
	frameFreeze(0.1, 0.05)
	animation_player.play("Death")
	PlayerHud.show_boss_slain()
	enable_hit_boxes( false )
	PlayerHud.hide_boss_health()
	await animation_player.animation_finished
	timer.stop()
	animation_player2.play("restore")
	$ItemDropper.drop_item()

	
func enable_hit_boxes( _v : bool = true ) -> void:
	hit_box.set_deferred( "monitorable", _v )
	hurt_box.set_deferred( "monitoring", _v )




func frameFreeze(timeScale, duration):
	Engine.time_scale = timeScale  # Set the game's time scale (e.g., freeze with 0.0 or slow down with < 1.0)
	await(get_tree().create_timer(duration * time_scale).timeout)  # Wait for the duration scaled by timeScale
	Engine.time_scale = 1.0  # Reset the time scale back to normal
