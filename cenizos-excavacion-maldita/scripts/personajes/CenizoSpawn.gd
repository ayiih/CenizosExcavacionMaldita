extends Node2D

@onready var cenizo: CharacterBody2D = $Cenizo
@onready var punto_inicio: Marker2D = $CenizoSpawn
@onready var terreno_destructible: TerrenoDestructible = (
	$TerrenoDestructible as TerrenoDestructible
)

@onready var minero: Minero = (
	$Cenizo/Minero as Minero
)

func _ready() -> void:
	minero.configurar_terreno(terreno_destructible)
	cenizo.global_position = punto_inicio.global_position
