extends Node2D

@onready var cenizo: CharacterBody2D = $Cenizo
@onready var punto_inicio: Marker2D = $CenizoSpawn


func _ready() -> void:
	cenizo.global_position = punto_inicio.global_position
