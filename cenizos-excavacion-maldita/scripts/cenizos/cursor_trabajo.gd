extends Node2D
class_name CursorTrabajo

## Colores según la validez de la celda apuntada.
enum Estado {
	VALIDO,
	IMPOSIBLE,
	DEBE_DESPLAZARSE,
	MATERIAL_INCORRECTO,
}

@export var tamano_celda: Vector2 = Vector2(32.0, 32.0)

var estado_actual: Estado = Estado.IMPOSIBLE
var direccion_actual: Vector2i = Vector2i.ZERO
var armado: bool = false


func _ready() -> void:
	z_index = 100
	visible = false


func actualizar(
	posicion_global_celda: Vector2,
	estado: Estado,
	direccion: Vector2i,
	esta_armado: bool
) -> void:
	global_position = posicion_global_celda
	estado_actual = estado
	direccion_actual = direccion
	armado = esta_armado
	visible = esta_armado
	queue_redraw()


func ocultar() -> void:
	visible = false


func _color_estado() -> Color:
	match estado_actual:
		Estado.VALIDO:
			return Color(0.2, 1.0, 0.3, 0.95)
		Estado.DEBE_DESPLAZARSE:
			return Color(1.0, 0.9, 0.2, 0.95)
		Estado.MATERIAL_INCORRECTO:
			return Color(0.6, 0.6, 0.6, 0.95)
		_:
			return Color(1.0, 0.2, 0.2, 0.95)


func _draw() -> void:
	if not armado:
		return

	var color_borde := _color_estado()
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

	draw_rect(rectangulo, color_relleno, true)
	draw_rect(rectangulo, color_borde, false, 2.0)

	if direccion_actual != Vector2i.ZERO:
		var centro := Vector2.ZERO
		var punta := Vector2(direccion_actual) * (tamano_celda.x * 0.4)

		draw_line(centro, punta, color_borde, 3.0)
