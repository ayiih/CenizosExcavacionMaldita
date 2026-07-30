extends Area2D
class_name EscaleraArea

@onready var centro_escalera: Marker2D = $CentroEscalera
@onready var _forma_colision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group(&"escaleras")

	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


## Rectángulo global cubierto por la escalera, usado por
## SistemaPathfindingCenizos para clasificar celdas como ESCALERA.
func obtener_rect_global() -> Rect2:
	if _forma_colision == null or _forma_colision.shape == null:
		return Rect2()

	var forma_rectangular := _forma_colision.shape as RectangleShape2D

	if forma_rectangular == null:
		return Rect2()

	var centro := _forma_colision.global_position
	var extension := forma_rectangular.size * 0.5

	return Rect2(centro - extension, forma_rectangular.size)


func _on_body_entered(cuerpo: Node2D) -> void:
	if cuerpo.has_method("entrar_escalera"):
		cuerpo.entrar_escalera(
			centro_escalera.global_position.x
		)


func _on_body_exited(cuerpo: Node2D) -> void:
	if cuerpo.has_method("salir_escalera"):
		cuerpo.salir_escalera()
