extends Node2D
class_name SistemaPathfindingCenizos

## Sistema de navegación basado en AStar2D, construido a mano celda por
## celda (no AStarGrid2D) porque necesitamos conexiones direccionales
## específicas: caminar libremente en horizontal, subir/bajar solo por
## escalera, y "caer/excavar" solo hacia abajo (nunca excavar hacia
## arriba). AStarGrid2D no permite ese control fino por arista.
##
## El grafo se reconstruye completo cada vez que cambia el terreno
## (señal bloque_destruido de TerrenoDestructible), nunca por frame.

signal grafo_actualizado()

@export var terreno_indestructible_path: NodePath
@export var terreno_destructible_path: NodePath
@export var grupo_escaleras: StringName = &"escaleras"

## Margen (en celdas) que se agrega alrededor del área usada por los
## TileMapLayers al construir el grafo.
@export var margen_grafo: int = 4

@export var mostrar_debug_pathfinding: bool = false

const COSTO_CAMINAR := 1.0
const COSTO_ESCALERA := 2.0

var terreno_indestructible: TileMapLayer
var terreno_destructible: TerrenoDestructible

var _astar := AStar2D.new()
var _region: Rect2i = Rect2i()
var _ids_por_celda: Dictionary = {}
var _celda_por_id: Dictionary = {}
var _datos_por_celda: Dictionary = {}
var _escaleras: Array = []


func _ready() -> void:
	terreno_indestructible = (
		get_node_or_null(terreno_indestructible_path) as TileMapLayer
	)
	terreno_destructible = (
		get_node_or_null(terreno_destructible_path) as TerrenoDestructible
	)

	if terreno_destructible != null:
		terreno_destructible.bloque_destruido.connect(_on_bloque_destruido)

	reconstruir_grafo()


func _on_bloque_destruido(_celda: Vector2i, _posicion_global: Vector2) -> void:
	reconstruir_grafo()


func _draw() -> void:
	if not mostrar_debug_pathfinding:
		return

	for celda in _ids_por_celda.keys():
		var datos: DatosCelda = _datos_por_celda[celda]
		var color := Color(0.3, 0.9, 1.0, 0.35)

		match datos.tipo:
			DatosCelda.TipoCelda.ESCALERA:
				color = Color(1.0, 0.6, 0.1, 0.4)
			DatosCelda.TipoCelda.TERRENO_EXCAVABLE:
				color = Color(1.0, 0.9, 0.2, 0.4)

		var posicion_local := to_local(posicion_global_de_celda(celda))
		draw_circle(posicion_local, 4.0, color)


## --- Construcción del grafo --------------------------------------------


func reconstruir_grafo() -> void:
	_actualizar_lista_escaleras()
	_calcular_region()

	_astar.clear()
	_ids_por_celda.clear()
	_celda_por_id.clear()
	_datos_por_celda.clear()

	for y in range(_region.position.y, _region.position.y + _region.size.y):
		for x in range(_region.position.x, _region.position.x + _region.size.x):
			var celda := Vector2i(x, y)
			var datos := clasificar_celda(celda)
			_datos_por_celda[celda] = datos

			if not datos.es_transitable():
				continue

			var id := _astar.get_available_point_id()
			_astar.add_point(id, to_local(posicion_global_de_celda(celda)), datos.costo_navegacion)
			_ids_por_celda[celda] = id
			_celda_por_id[id] = celda

	for celda in _ids_por_celda.keys():
		_conectar_celda(celda)

	queue_redraw()
	grafo_actualizado.emit()


func _calcular_region() -> void:
	var rect := Rect2i()
	var alguno := false

	if terreno_indestructible != null:
		rect = terreno_indestructible.get_used_rect()
		alguno = true

	if terreno_destructible != null:
		var rect_destructible := terreno_destructible.get_used_rect()
		rect = rect.merge(rect_destructible) if alguno else rect_destructible
		alguno = true

	if not alguno:
		_region = Rect2i(Vector2i.ZERO, Vector2i(64, 64))
		return

	_region = rect.grow(margen_grafo)


func _actualizar_lista_escaleras() -> void:
	_escaleras.clear()

	if not is_inside_tree():
		return

	for nodo in get_tree().get_nodes_in_group(grupo_escaleras):
		if nodo is EscaleraArea:
			_escaleras.append(nodo)


func _conectar_celda(celda: Vector2i) -> void:
	var id: int = _ids_por_celda[celda]
	var datos: DatosCelda = _datos_por_celda[celda]

	# Horizontal: se procesa una sola vez por par (mirando a la derecha).
	var vecino_derecha := celda + Vector2i.RIGHT

	if _ids_por_celda.has(vecino_derecha):
		_astar.connect_points(id, _ids_por_celda[vecino_derecha], true)

	# Vertical: se procesa una sola vez por par (mirando hacia abajo).
	var vecino_abajo := celda + Vector2i.DOWN

	if not _ids_por_celda.has(vecino_abajo):
		return

	var datos_abajo: DatosCelda = _datos_por_celda[vecino_abajo]
	var id_abajo: int = _ids_por_celda[vecino_abajo]

	var ambas_escalera := (
		datos.tipo == DatosCelda.TipoCelda.ESCALERA
		and datos_abajo.tipo == DatosCelda.TipoCelda.ESCALERA
	)

	if ambas_escalera:
		_astar.connect_points(id, id_abajo, true)
		return

	# Entrar/salir de una escalera por arriba o por abajo.
	var una_escalera := (
		datos.tipo == DatosCelda.TipoCelda.ESCALERA
		or datos_abajo.tipo == DatosCelda.TipoCelda.ESCALERA
	)

	if una_escalera:
		_astar.connect_points(id, id_abajo, true)
		return

	# Excavar hacia abajo: solo en ese sentido, nunca "excavar hacia
	# arriba" (si el destino de abajo es excavable, o si ya estamos
	# dentro de un bloque excavable encadenando la excavación).
	var involucra_excavacion := (
		datos_abajo.tipo == DatosCelda.TipoCelda.TERRENO_EXCAVABLE
		or datos.tipo == DatosCelda.TipoCelda.TERRENO_EXCAVABLE
	)

	if involucra_excavacion:
		_astar.connect_points(id, id_abajo, false)


## --- Clasificación de celdas --------------------------------------------


func clasificar_celda(celda: Vector2i) -> DatosCelda:
	var datos := DatosCelda.new()
	datos.celda = celda

	if not _region.has_point(celda):
		datos.tipo = DatosCelda.TipoCelda.FUERA_DEL_MAPA
		return datos

	if _tiene_tile(terreno_indestructible, celda):
		datos.tipo = DatosCelda.TipoCelda.TERRENO_INDESTRUCTIBLE
		return datos

	if terreno_destructible != null and terreno_destructible.get_cell_source_id(celda) != -1:
		if terreno_destructible.es_excavable(celda):
			datos.tipo = DatosCelda.TipoCelda.TERRENO_EXCAVABLE
			datos.tipo_material = terreno_destructible.obtener_tipo_material(celda)
			datos.especialidad_requerida = terreno_destructible.obtener_especialidad_requerida(celda)
			datos.costo_navegacion = _costo_material(datos.tipo_material)
		else:
			datos.tipo = DatosCelda.TipoCelda.TERRENO_INDESTRUCTIBLE

		return datos

	if _celda_en_escalera(celda) != null:
		datos.tipo = DatosCelda.TipoCelda.ESCALERA
		datos.costo_navegacion = COSTO_ESCALERA
		return datos

	var celda_abajo := celda + Vector2i.DOWN
	var hay_soporte := (
		_tiene_tile(terreno_indestructible, celda_abajo)
		or (terreno_destructible != null and terreno_destructible.get_cell_source_id(celda_abajo) != -1)
	)

	if hay_soporte:
		datos.tipo = DatosCelda.TipoCelda.VACIA_TRANSITABLE
		datos.costo_navegacion = COSTO_CAMINAR
		return datos

	# Celda vacía sin piso debajo, sin escalera: aire. No se agrega
	# como punto transitable (evita que el Cenizo "camine por el aire").
	datos.tipo = DatosCelda.TipoCelda.PELIGRO
	return datos


func _tiene_tile(capa: TileMapLayer, celda: Vector2i) -> bool:
	return capa != null and capa.get_cell_source_id(celda) != -1


func _celda_en_escalera(celda: Vector2i):
	var posicion_global := posicion_global_de_celda(celda)

	for escalera in _escaleras:
		if not is_instance_valid(escalera):
			continue

		if escalera.obtener_rect_global().has_point(posicion_global):
			return escalera

	return null


func _costo_material(tipo_material: int) -> float:
	match tipo_material:
		TerrenoDestructible.TipoMaterial.TIERRA:
			return 5.0
		TerrenoDestructible.TipoMaterial.MADERA:
			return 6.0
		TerrenoDestructible.TipoMaterial.HUESOS:
			return 7.0
		TerrenoDestructible.TipoMaterial.PIEDRA:
			return 12.0
		TerrenoDestructible.TipoMaterial.ADOQUIN:
			return 14.0
		TerrenoDestructible.TipoMaterial.ROCA_GEMAS:
			return 16.0
		TerrenoDestructible.TipoMaterial.CEMENTO, TerrenoDestructible.TipoMaterial.ROCA_ACERO, TerrenoDestructible.TipoMaterial.MARMOL:
			return 999.0
		_:
			return 5.0


## --- Conversión de coordenadas -------------------------------------------


func celda_desde_posicion_global(posicion_global: Vector2) -> Vector2i:
	if terreno_destructible != null:
		return terreno_destructible.local_to_map(terreno_destructible.to_local(posicion_global))

	return Vector2i(floori(posicion_global.x / 32.0), floori(posicion_global.y / 32.0))


func posicion_global_de_celda(celda: Vector2i) -> Vector2:
	if terreno_destructible != null:
		return terreno_destructible.to_global(terreno_destructible.map_to_local(celda))

	return Vector2(celda) * 32.0 + Vector2(16.0, 16.0)


## --- Cálculo de rutas -----------------------------------------------------


## Calcula la ruta (array de celdas, sin incluir la celda de origen)
## para el Cenizo dado, respetando su especialidad: las celdas
## excavables que no correspondan a su especialidad quedan bloqueadas
## solo para esta búsqueda.
func calcular_ruta(cenizo: Cenizo, origen_global: Vector2, destino_global: Vector2) -> Array[Vector2i]:
	var ruta: Array[Vector2i] = []

	var especialidad_id: StringName = &""

	if cenizo != null and cenizo.especialidad_actual != null:
		especialidad_id = cenizo.especialidad_actual.id

	var celdas_deshabilitadas: Array[Vector2i] = []

	for celda in _ids_por_celda.keys():
		var datos: DatosCelda = _datos_por_celda[celda]

		if (
			datos.tipo == DatosCelda.TipoCelda.TERRENO_EXCAVABLE
			and datos.especialidad_requerida != especialidad_id
		):
			_astar.set_point_disabled(_ids_por_celda[celda], true)
			celdas_deshabilitadas.append(celda)

	var origen_celda := _celda_valida_cercana(celda_desde_posicion_global(origen_global))
	var destino_celda := _celda_valida_cercana(celda_desde_posicion_global(destino_global))

	if _ids_por_celda.has(origen_celda) and _ids_por_celda.has(destino_celda):
		var ids := _astar.get_id_path(_ids_por_celda[origen_celda], _ids_por_celda[destino_celda])

		for id in ids:
			ruta.append(_celda_por_id[id])

	for celda in celdas_deshabilitadas:
		_astar.set_point_disabled(_ids_por_celda[celda], false)

	return ruta


func _celda_valida_cercana(celda: Vector2i) -> Vector2i:
	if _ids_por_celda.has(celda):
		return celda

	for radio in range(1, 4):
		for dy in range(-radio, radio + 1):
			for dx in range(-radio, radio + 1):
				var candidata := celda + Vector2i(dx, dy)

				if _ids_por_celda.has(candidata):
					return candidata

	return celda


func celda_tiene_punto(celda: Vector2i) -> bool:
	return _ids_por_celda.has(celda)
