extends Control

@onready var barra_carga: ProgressBar = $BarraCarga
@onready var timer: Timer = $Timer

var progreso: float = 0.0


func _ready() -> void:
	barra_carga.value = 0
	timer.start()


func _on_timer_timeout() -> void:
	progreso += 20
	barra_carga.value = progreso

	if progreso >= 100:
		get_tree().change_scene_to_file("res://escenas/ui/main_menu.tscn")
