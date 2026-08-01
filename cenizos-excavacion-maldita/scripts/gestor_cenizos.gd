extends Node
class_name GestorCenizos

signal cenizo_seleccionado_cambiado(cenizo: Cenizo)
signal direccion_armada_cambiada(direccion: Vector2i)

## Nodo que contiene las instancias de Cenizo.tscn a controlar (ej. "Cenizos").
@export var contenedor_cenizos: NodePath

## TerrenoDestructible sobre el que se asignan las órdenes de excavación.
@export var terreno_destructible_path: NodePath

## Nodo CursorTrabajo (opcional) usado para mostrar la celda apuntada.
@export var cursor_trabajo_path: NodePath

## SistemaPathfindingCenizos usado para las órdenes de "caminar hasta
## un punto" (clic sin dirección armada).
@export var sistema_pathfinding_path: NodePath

## Panel de HUD (PanelCenizo.tscn) que muestra nombre, icono, vida y
## energía del Cenizo activo. Se actualiza al cambiar con TAB.
@export var panel_cenizo_path: NodePath

## Radio (px) para seleccionar un Cenizo haciendo clic sobre él.
@export var radio_seleccion_click: float = 18.0

var lista_cenizos: Array[Cenizo] = []
var indice_activo: int = 0
var direccion_armada: Vector2i = Vector2i.ZERO

var _terreno: TerrenoDestructible
var _cursor: CursorTrabajo
var _sistema_pathfinding: SistemaPathfindingCenizos
var _panel_cenizo: PanelCenizo


func _ready() -> void:
	var contenedor := get_node_or_null(contenedor_cenizos)

	if contenedor == null:
		push_warning(
			"GestorCenizos: no se asignó 'contenedor_cenizos'."
		)
		return

	lista_cenizos.clear()

	for hijo in contenedor.get_children():
		if hijo is Cenizo:
			lista_cenizos.append(hijo)
			hijo.orden_completada.connect(_on_orden_completada)
			hijo.orden_bloqueada.connect(_on_orden_bloqueada)
			hijo.orden_cancelada.connect(_on_orden_cancelada)

	if lista_cenizos.is_empty():
		push_warning(
			"GestorCenizos: no se encontraron nodos Cenizo."
		)
		return

	_terreno = get_node_or_null(terreno_destructible_path) as TerrenoDestructible
	_cursor = get_node_or_null(cursor_trabajo_path) as CursorTrabajo
	_sistema_pathfinding = get_node_or_null(sistema_pathfinding_path) as SistemaPathfindingCenizos
	_panel_cenizo = get_node_or_null(panel_cenizo_path) as PanelCenizo

	for cenizo in lista_cenizos:
		cenizo.sistema_pathfinding = _sistema_pathfinding
		cenizo.ruta_no_disponible.connect(_on_ruta_no_disponible)
		cenizo.destino_alcanzado.connect(_on_destino_alcanzado)

	_activar_indice(0)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("cambiar_cenizo"):
		_cambiar_al_siguiente()

	if Input.is_action_just_pressed("seleccionar_excavar_abajo"):
		_alternar_direccion(Vector2i.DOWN)
	elif Input.is_action_just_pressed("seleccionar_excavar_izquierda"):
		_alternar_direccion(Vector2i.LEFT)
	elif Input.is_action_just_pressed("seleccionar_excavar_derecha"):
		_alternar_direccion(Vector2i.RIGHT)

	if Input.is_action_just_pressed("cancelar_orden"):
		_cancelar_orden_del_activo()

	_actualizar_cursor_trabajo()
	_procesar_click_principal()
	_actualizar_panel_cenizo()


func _cambiar_al_siguiente() -> void:
	if lista_cenizos.size() <= 1:
		return

	var siguiente := (indice_activo + 1) % lista_cenizos.size()
	_activar_indice(siguiente)


func _activar_indice(indice: int) -> void:
	if lista_cenizos.is_empty():
		return

	indice_activo = indice
	_desarmar_direccion()

	for i in lista_cenizos.size():
		lista_cenizos[i].set_control_activo(i == indice_activo)

	cenizo_seleccionado_cambiado.emit(obtener_cenizo_activo())


## Sincroniza el panel de HUD con el Cenizo activo: nombre, icono,
## vida y energía. Se llama al cambiar de Cenizo y cada frame para
## reflejar cambios de vida/energía en tiempo real.
func _actualizar_panel_cenizo() -> void:
	if _panel_cenizo == null:
		return

	var activo := obtener_cenizo_activo()

	if activo == null:
		return

	_panel_cenizo.configurar_cenizo(
		activo.nombre_visible,
		activo.icono_retrato,
		activo.vida_actual,
		activo.vida_maxima,
		activo.energia_actual,
		activo.energia_maxima
	)


func obtener_cenizo_activo() -> Cenizo:
	if lista_cenizos.is_empty():
		return null

	return lista_cenizos[indice_activo]


## --- Selección por clic y asignación de órdenes ------------------------


func _procesar_click_principal() -> void:
	if not Input.is_action_just_pressed("picar"):
		return

	if lista_cenizos.is_empty():
		return

	var mouse_global := lista_cenizos[0].get_global_mouse_position()

	# 1) ¿El clic seleccionó a OTRO Cenizo? (si cae sobre el que ya está
	# seleccionado, no se consume: puede ser una orden justo bajo sus pies).
	for i in lista_cenizos.size():
		if i == indice_activo:
			continue

		if lista_cenizos[i].global_position.distance_to(mouse_global) <= radio_seleccion_click:
			_activar_indice(i)
			return

	# 2) Si hay una dirección armada, el clic asigna la orden de excavación
	# en esa dirección. Si no, el clic es una orden de "caminar hasta ahí"
	# resuelta por SistemaPathfindingCenizos (excavando lo que bloquee).
	if direccion_armada != Vector2i.ZERO:
		_intentar_asignar_orden(mouse_global)
	else:
		_intentar_asignar_destino(mouse_global)


func _alternar_direccion(direccion: Vector2i) -> void:
	if direccion_armada == direccion:
		_desarmar_direccion()
	else:
		_armar_direccion(direccion)


func _armar_direccion(direccion: Vector2i) -> void:
	direccion_armada = direccion

	var activo := obtener_cenizo_activo()

	if activo != null:
		activo.modo_orden_armado = true

	direccion_armada_cambiada.emit(direccion_armada)


func _desarmar_direccion() -> void:
	direccion_armada = Vector2i.ZERO

	for cenizo in lista_cenizos:
		cenizo.modo_orden_armado = false

	if _cursor != null:
		_cursor.ocultar()

	direccion_armada_cambiada.emit(direccion_armada)


func _cancelar_orden_del_activo() -> void:
	var activo := obtener_cenizo_activo()

	if activo != null:
		activo.cancelar_orden()
		activo.cancelar_orden_movimiento()

	_desarmar_direccion()


func _intentar_asignar_orden(mouse_global: Vector2) -> void:
	var activo := obtener_cenizo_activo()

	if activo == null or _terreno == null:
		return

	var celda := _terreno.local_to_map(_terreno.to_local(mouse_global))

	var orden := OrdenTrabajo.new(
		OrdenTrabajo.TipoOrden.EXCAVAR,
		celda,
		direccion_armada,
		_terreno
	)

	if activo.asignar_orden(activo.especialidad_actual, orden):
		activo.modo_orden_armado = false
		direccion_armada = Vector2i.ZERO

		if _cursor != null:
			_cursor.ocultar()

		direccion_armada_cambiada.emit(direccion_armada)


func _actualizar_cursor_trabajo() -> void:
	if _cursor == null or lista_cenizos.is_empty():
		return

	if direccion_armada != Vector2i.ZERO:
		_actualizar_cursor_excavacion_armada()
	else:
		_actualizar_cursor_destino()


## Cursor para el modo "dirección armada" (1/2/3 + clic): excavación
## en línea recta, tal como antes.
func _actualizar_cursor_excavacion_armada() -> void:
	if _terreno == null:
		_cursor.ocultar()
		return

	var activo := obtener_cenizo_activo()
	var mouse_global := activo.get_global_mouse_position()
	var celda := _terreno.local_to_map(_terreno.to_local(mouse_global))
	var centro_global := _terreno.to_global(_terreno.map_to_local(celda))

	var estado := CursorTrabajo.Estado.IMPOSIBLE
	var excavador := activo.especialidad_actual as EspecialidadExcavador

	if _terreno.get_cell_source_id(celda) == -1:
		estado = CursorTrabajo.Estado.IMPOSIBLE
	elif not _terreno.es_celda_excavable(celda, activo.especialidad_actual.id):
		estado = CursorTrabajo.Estado.MATERIAL_INCORRECTO
	elif activo.orden_actual != null:
		estado = CursorTrabajo.Estado.DEBE_DESPLAZARSE
	elif (
		excavador != null
		and celda != excavador.celda_adyacente_esperada(activo, _terreno, direccion_armada)
	):
		# El bloque no está pegado al Cenizo: hay que acercarse primero.
		estado = CursorTrabajo.Estado.DEBE_DESPLAZARSE
	else:
		estado = CursorTrabajo.Estado.VALIDO

	_cursor.actualizar(centro_global, estado, direccion_armada, true)


## Cursor para el modo por defecto (sin dirección armada): destino de
## pathfinding. Verde = alcanzable directamente, amarillo = requiere
## excavar esa celda, gris/rojo = fuera de mapa o material incompatible.
func _actualizar_cursor_destino() -> void:
	if _sistema_pathfinding == null:
		_cursor.ocultar()
		return

	var activo := obtener_cenizo_activo()
	var mouse_global := activo.get_global_mouse_position()
	var celda := _sistema_pathfinding.celda_desde_posicion_global(mouse_global)
	var centro_global := _sistema_pathfinding.posicion_global_de_celda(celda)
	var datos := _sistema_pathfinding.clasificar_celda(celda)

	var estado := CursorTrabajo.Estado.IMPOSIBLE

	match datos.tipo:
		DatosCelda.TipoCelda.VACIA_TRANSITABLE, DatosCelda.TipoCelda.ESCALERA:
			estado = CursorTrabajo.Estado.VALIDO
		DatosCelda.TipoCelda.TERRENO_EXCAVABLE:
			if datos.especialidad_requerida == activo.especialidad_actual.id:
				estado = CursorTrabajo.Estado.DEBE_DESPLAZARSE
			else:
				estado = CursorTrabajo.Estado.MATERIAL_INCORRECTO
		_:
			estado = CursorTrabajo.Estado.IMPOSIBLE

	_cursor.actualizar(centro_global, estado, Vector2i.ZERO, true)


func _intentar_asignar_destino(mouse_global: Vector2) -> void:
	var activo := obtener_cenizo_activo()

	if activo == null or _sistema_pathfinding == null:
		return

	activo.asignar_destino(mouse_global)


func _on_orden_completada(cenizo: Cenizo, _orden: OrdenTrabajo) -> void:
	print("%s: Tarea completada." % cenizo.name)


func _on_orden_bloqueada(cenizo: Cenizo, motivo: String) -> void:
	print("%s: %s" % [cenizo.name, motivo])


func _on_orden_cancelada(cenizo: Cenizo, _orden: OrdenTrabajo) -> void:
	print("%s: Orden cancelada." % cenizo.name)


func _on_ruta_no_disponible(cenizo: Cenizo, motivo: String) -> void:
	print("%s: %s" % [cenizo.name, motivo])


func _on_destino_alcanzado(cenizo: Cenizo) -> void:
	print("%s: Destino alcanzado." % cenizo.name)
