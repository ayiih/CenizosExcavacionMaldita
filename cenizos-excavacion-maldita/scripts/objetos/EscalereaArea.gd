extends Area2D
class_name EscaleraArea

@onready var centro_escalera: Marker2D = $CentroEscalera


func _ready() -> void:
	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _on_body_entered(cuerpo: Node2D) -> void:
	if cuerpo.has_method("entrar_escalera"):
		cuerpo.entrar_escalera(
			centro_escalera.global_position.x
		)


func _on_body_exited(cuerpo: Node2D) -> void:
	if cuerpo.has_method("salir_escalera"):
		cuerpo.salir_escalera()
