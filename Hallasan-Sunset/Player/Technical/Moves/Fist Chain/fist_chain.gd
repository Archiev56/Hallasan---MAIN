extends Area2D
 
var direction : Vector2 = Vector2.RIGHT
var speed : float = 150
var damage : float = 1
 
var collision = null
var bodies = []
 
func _physics_process(delta):
	position += direction * speed * delta
	rotation = direction.angle()
 
func set_direction(direction_pointing, frame = 0):
	$Sprite2D.frame = frame
	direction = direction_pointing
 
 
func _on_screen_exited():
	queue_free()
 
 
func _on_body_entered(body):
	if collision == null:
		speed = 0
 
		collision = body
		%Check.set_deferred("disabled",false)
 
		await get_tree().create_timer(0.1).timeout
		switch_direction()
 
	if body.has_method("take_damage"):
		body.take_damage(damage)
 
 
func _on_check_body_entered(body):
	speed = 150
	if collision != body:
		bodies.append(body)
 
func switch_direction():
	while bodies != []:
		var tween = get_tree().create_tween()
		direction = (bodies[0].position - self.position).normalized()
		tween.tween_property(self, "position", bodies.pop_front().position, 0.25)
		await tween.finished
 
	queue_free()
