extends Node2D

@onready var cenizos: Node2D = $Cenizos
@onready var punto_inicio: Marker2D = $CenizoSpawn
@onready var terreno_destructible: TerrenoDestructible = (
	$TerrenoDestructible as TerrenoDestructible
)

## Separación horizontal entre cada Cenizo al aparecer, en píxeles.
@export var separacion_spawn: float = 32.0


func _ready() -> void:
	var lista_cenizos := cenizos.get_children()

	for i in lista_cenizos.size():
		var nodo_cenizo := lista_cenizos[i] as Cenizo

		if nodo_cenizo == null:
			continue

		nodo_cenizo.global_position = (
			punto_inicio.global_position
			+ Vector2(separacion_spawn * i, 0.0)
		)

		var minero := nodo_cenizo.get_node("Minero") as Minero

		if minero != null:
			minero.configurar_terreno(terreno_destructible)

	if lista_cenizos.is_empty():
		return

	var cenizo_principal := lista_cenizos[0] as Cenizo

	GameManager.registrar_nivel(cenizo_principal, terreno_destructible)
	GuardadoManager.iniciar_para_nivel(cenizo_principal, terreno_destructible)
