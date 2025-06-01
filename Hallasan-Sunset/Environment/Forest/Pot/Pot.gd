@icon( "res://Hallasan-Sunset/Technical/Icons/icon_destroyable_2.png" )

extends Node2D

func _ready():
	pass
#
@onready var throwable: Throwable = $Throwable
@onready var static_body_2d: StaticBody2D = $StaticBody2D
