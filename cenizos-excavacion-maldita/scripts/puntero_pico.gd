extends Node2D
class_name PunteroPico

@export var tamano_celda: Vector2 = Vector2(32.0, 32.0)

var objetivo_valido: bool = false


func _ready() -> void:
	z_index = 100
	visible = false


func establecer_objetivo(
	posicion_global_objetivo: Vector2,
	es_valido: bool
) -> void:
	global_position = posicion_global_objetivo
	objetivo_valido = es_valido
	visible = true
	queue_redraw()


func ocultar() -> void:
	visible = false


func _draw() -> void:
	var color_borde: Color

	if objetivo_valido:
		color_borde = Color(0.2, 1.0, 0.3, 0.95)
	else:
		color_borde = Color(1.0, 0.2, 0.2, 0.95)

	var color_relleno := Color(
		color_borde.r,
		color_borde.g,
		color_borde.b,
		0.15
	)

	var rectangulo := Rect2(
		-tamano_celda * 0.5,
		tamano_celda
	)

	draw_rect(
		rectangulo,
		color_relleno,
		true
	)

	draw_rect(
		rectangulo,
		color_borde,
		false,
		2.0
	)
