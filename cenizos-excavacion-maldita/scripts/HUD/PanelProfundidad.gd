extends Control
class_name PanelProfundidad

## Altura (posición Y global) que se considera "superficie" (0 metros).
## Si se asigna 'punto_referencia_path', este valor se recalcula en
## _ready() a partir de la posición real de ese nodo (ej. el Marker2D
## de spawn de los Cenizos), en vez de quedar fijo.
@export var altura_superficie_y: float = 480.0
@export var pixeles_por_metro: float = 32.0

## Nodo (ej. CenizoSpawn) cuya posición Y global marca los 0 metros.
@export var punto_referencia_path: NodePath

@onready var profundidad_label: Label = %ProfundidadLabel

## Asignado externamente (por GestorCenizos) con el Cenizo activo.
var cenizo: Cenizo = null

var _profundidad_anterior: int = -1


func _ready() -> void:
	var punto_referencia := get_node_or_null(punto_referencia_path) as Node2D

	if punto_referencia != null:
		altura_superficie_y = punto_referencia.global_position.y


func _process(_delta: float) -> void:
	if not is_instance_valid(cenizo):
		return

	var distancia_vertical := cenizo.global_position.y - altura_superficie_y
	var profundidad := floori(
		maxf(distancia_vertical, 0.0) / pixeles_por_metro
	)

	if profundidad == _profundidad_anterior:
		return

	_profundidad_anterior = profundidad
	actualizar_profundidad(profundidad)


func actualizar_profundidad(metros: int) -> void:
	metros = max(metros, 0)
	profundidad_label.text = "- %d m -" % metros
