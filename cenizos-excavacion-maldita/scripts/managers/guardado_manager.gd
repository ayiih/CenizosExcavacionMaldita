extends Node

## Orquesta CUÁNDO se guarda y se carga el progreso del jugador,
## delegando el cómo a SerializacionService y PartidaRepository.

var _cargando_progreso: bool = false


## Conecta el autosave al nivel activo y aplica el progreso guardado, si existe.
func iniciar_para_nivel(
	cenizo: CharacterBody2D,
	terreno: TerrenoDestructible
) -> void:
	if not terreno.bloque_destruido.is_connected(_on_bloque_destruido):
		terreno.bloque_destruido.connect(_on_bloque_destruido)

	cargar_progreso(cenizo, terreno)


func cargar_progreso(
	cenizo: CharacterBody2D,
	terreno: TerrenoDestructible
) -> void:
	if not PartidaRepository.existe_guardado():
		return

	var snapshot := PartidaRepository.cargar()

	if snapshot.is_empty():
		return

	_cargando_progreso = true

	var celdas_destruidas := SerializacionService.obtener_celdas_destruidas(
		snapshot
	)

	EstadoTemporalRepository.establecer_celdas_destruidas(
		celdas_destruidas
	)

	for celda in celdas_destruidas:
		terreno.aplicar_celda_destruida(celda)

	cenizo.global_position = SerializacionService.obtener_posicion_cenizo(
		snapshot
	)

	_cargando_progreso = false


func _on_bloque_destruido(
	celda: Vector2i,
	_posicion_global: Vector2
) -> void:
	if _cargando_progreso:
		return

	EstadoTemporalRepository.registrar_celda_destruida(celda)
	_guardar_progreso_actual()


func _guardar_progreso_actual() -> void:
	if not is_instance_valid(GameManager.cenizo):
		return

	var snapshot := SerializacionService.construir_snapshot(
		GameManager.cenizo.global_position,
		EstadoTemporalRepository.obtener_celdas_destruidas()
	)

	PartidaRepository.guardar(snapshot)
