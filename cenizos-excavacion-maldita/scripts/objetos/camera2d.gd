extends Camera2D

@export var objetivo: Node2D
@export var margen_horizontal: float = 45.0
@export var suavidad: float = 8.0


func _ready() -> void:
	make_current()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(objetivo):
		return

	var tamano_viewport := get_viewport_rect().size
	var mitad_visible_x := tamano_viewport.x / (2.0 * zoom.x)

	var borde_izquierdo := global_position.x - mitad_visible_x + margen_horizontal
	var borde_derecho := global_position.x + mitad_visible_x - margen_horizontal

	var nueva_x := global_position.x

	if objetivo.global_position.x > borde_derecho:
		nueva_x = objetivo.global_position.x - mitad_visible_x + margen_horizontal
	elif objetivo.global_position.x < borde_izquierdo:
		nueva_x = objetivo.global_position.x + mitad_visible_x - margen_horizontal

	var nueva_y := objetivo.global_position.y

	global_position = global_position.lerp(
		Vector2(nueva_x, nueva_y),
		1.0 - exp(-suavidad * delta)
	)
