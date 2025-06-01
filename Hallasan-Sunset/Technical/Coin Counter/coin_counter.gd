class_name CoinCounter extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coin_label: Label = $PanelContainer/Label

var coin_count: int = 0  # Store collected coins

func _ready():
	print("📌 CoinCounter initialized. Label found: ", coin_label)  
	_update_coin_label()  # Initialize label with 0 coins

func increase_coin_count():
	coin_count += 1  # Increase total coin count
	print("✅ Gem collected! New count: ", coin_count)
	_update_coin_label()

func _update_coin_label():
	if coin_label:
		coin_label.text = str(coin_count)
		coin_label.queue_redraw()  # Force UI refresh
		print("✅ Coin label updated to:", coin_label.text)
	else:
		print("❌ ERROR: Coin label not found or not updating!")
