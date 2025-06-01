extends Skill
class_name SingleShot
 
@export_enum("Fist") var frame : int
@export var damage : float
@export var projectile_node : PackedScene
 
func shoot(source, mouse, scene_tree):
	var projectile = projectile_node.instantiate()
 
	projectile.position = source.position
	projectile.damage = damage
	projectile.set_direction((mouse - source.position).normalized(), frame)
 
	scene_tree.current_scene.add_child(projectile)
 
func activate(source, mouse, scene_tree):
	shoot(source, mouse, scene_tree)
