extends Node


var label = '$Label' 
func display_number(value: int, position: Vector2, is_critical: bool = false):
	# Create a new Label node and set its properties
	var number = Label.new()
	number.global_position = position
	number.text = str(value)
	number.z_index = 5
	number.label_settings = LabelSettings.new()

	# Define color based on conditions
	var color = "#FFF"
	if is_critical:
		color = "#B99"
		number.text += "!" 
	if value == 0:
		color = "#FFF8"

	# Apply font settings to the label
	number.label_settings.font_color = color
	number.label_settings.font_size = 16
	number.label_settings.outline_color = "#000"
	number.label_settings.outline_size = 8

	# Add the label to the scene using deferred call to avoid tree modification errors
	call_deferred("add_child", number)

	# Wait for the label to resize and adjust its pivot to be centered
	await number.resized
	number.pivot_offset = Vector2(number.size / 4)

	# Create a tween animation for the label
	var tween = get_tree().create_tween()
	tween.set_parallel(true)

	# Animate the label moving up, then returning to its original position
	tween.tween_property(
		number, "position:y", number.position.y - 24, 0.25
	).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(
		number, "position:y", number.position.y, 0.5
	).set_ease(Tween.EASE_IN).set_delay(0.25)

	# Animate the label shrinking (scaling down to zero)
	tween.tween_property(
		number, "scale", Vector2.ZERO, 0.25
	).set_ease(Tween.EASE_IN).set_delay(0.5)
	await tween.finished
	number.queue_free()
