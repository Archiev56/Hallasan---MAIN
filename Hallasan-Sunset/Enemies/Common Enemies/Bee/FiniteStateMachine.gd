extends Node2D
class_name FiniteStateMachine
 
var current_state: StateBee
var previous_state: StateBee
 

func _ready():
	current_state = get_child(0) as StateBee
	previous_state = current_state
	current_state.enter()
 
func change_state(state):
	current_state = find_child(state) as StateBee
	current_state.enter()
 
	previous_state.exit()
	previous_state = current_state
