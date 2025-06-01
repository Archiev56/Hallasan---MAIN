extends CharacterBody2D


@onready var animated_sprite_2d = $AnimatedSprite2D

@export var hp : int = 10
@export var max_hp : int = 10

@onready var hit_box = $HitBox
@onready var hurt_box = $HurtBox


func _ready() -> void:

		
	hp = max_hp
	PlayerHud.show_boss_health( "Dokkaebi General" )
	hit_box.damaged.connect( damage_taken )
	
func damage_taken(body):
	animated_sprite_2d.play("Hurt")
	hp = clampi( hp - hurt_box.damage, 0, max_hp )
	PlayerHud.update_boss_health( hp, max_hp )
	if hp < 1:
		defeat()
	pass
 
func _on_animation_finished(anim_name):
	animated_sprite_2d.play("Idle")
	
func defeat() -> void:
	animated_sprite_2d.play("Death")
	PlayerHud.show_boss_slain()
	enable_hit_boxes( false )
	PlayerHud.hide_boss_health()


func enable_hit_boxes( _v : bool = true ) -> void:
	hit_box.set_deferred( "monitorable", _v )
	hurt_box.set_deferred( "monitoring", _v )
