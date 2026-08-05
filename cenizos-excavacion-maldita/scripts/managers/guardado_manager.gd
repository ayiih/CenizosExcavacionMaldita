extends Node

## Orquesta cuándo guardar y cargar el progreso.
## Debe registrarse como Autoload con el nombre GuardadoManager.

signal partida_guardada
signal partida_cargada
signal partida_nueva_creada
signal guardado_no_encontrado
signal error_guardado(mensaje: String)
signal error_carga(mensaje: String)
signal cenizo_activo_restaurado(indice: int)

const RETARDO_AUTOGUARDADO_SEGUNDOS: float = 2.0

var _cargando_progreso: bool = false
var _hay_cambios_pendientes: bool = false
var _cargar_al_iniciar_nivel: bool = false

var _terreno_actual: TerrenoDestructible
var _cenizos_actuales: Array[CharacterBody2D] = []
var _indice_cenizo_activo: int = 0
var _temporizador_autoguardado: Timer


func _ready() -> void:
	_temporizador_autoguardado = Timer.new()
	_temporizador_autoguardado.name = "TemporizadorAutoguardado"
	_temporizador_autoguardado.one_shot = true
	_temporizador_autoguardado.wait_time = (
		RETARDO_AUTOGUARDADO_SEGUNDOS
	)
	_temporizador_autoguardado.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)
	_temporizador_autoguardado.timeout.connect(
		_on_temporizador_autoguardado_timeout
	)
	add_child(_temporizador_autoguardado)


## Compatibilidad con el sistema anterior, que registraba un solo Cenizo.
func iniciar_para_nivel(
	cenizo: CharacterBody2D,
	terreno: TerrenoDestructible
) -> void:
	var lista: Array = [cenizo]
	iniciar_para_nivel_con_cenizos(
		lista,
		0,
		terreno
	)


## Utiliza esta función si el nivel contiene varios Cenizos.
func iniciar_para_nivel_con_cenizos(
	cenizos: Array,
	indice_cenizo_activo: int,
	terreno: TerrenoDestructible
) -> void:
	_desconectar_terreno_anterior()

	_cenizos_actuales.clear()

	for nodo in cenizos:
		if nodo is CharacterBody2D and is_instance_valid(nodo):
			_cenizos_actuales.append(nodo)

	_terreno_actual = terreno
	_indice_cenizo_activo = _normalizar_indice_cenizo(
		indice_cenizo_activo
	)

	if is_instance_valid(_terreno_actual):
		if not _terreno_actual.bloque_destruido.is_connected(
			_on_bloque_destruido
		):
			_terreno_actual.bloque_destruido.connect(
				_on_bloque_destruido
			)

	if _cargar_al_iniciar_nivel:
		call_deferred("_ejecutar_carga_pendiente")


## Se usa desde la portada o el menú de pausa antes de cambiar/reiniciar escena.
func cargar_partida_recargando_escena() -> bool:
	if not PartidaRepository.existe_guardado():
		guardado_no_encontrado.emit()
		return false

	var snapshot := PartidaRepository.cargar()

	if snapshot.is_empty():
		error_carga.emit(
			"El archivo de guardado está vacío o dañado."
		)
		return false

	var ruta_escena := SerializacionService.obtener_escena_actual(
		snapshot
	)

	if ruta_escena.is_empty():
		if get_tree().current_scene != null:
			ruta_escena = get_tree().current_scene.scene_file_path

	if ruta_escena.is_empty() or not ResourceLoader.exists(ruta_escena):
		error_carga.emit(
			"No se encontró la escena registrada en la partida."
		)
		return false

	_cargar_al_iniciar_nivel = true
	get_tree().paused = false

	var resultado := get_tree().change_scene_to_file(ruta_escena)

	if resultado != OK:
		_cargar_al_iniciar_nivel = false
		error_carga.emit(
			"No se pudo abrir la escena guardada. Código: %d"
			% resultado
		)
		return false

	return true


## Aplica el guardado sobre el nivel actualmente registrado.
## Para cargar desde el menú de pausa es preferible usar
## cargar_partida_recargando_escena().
func cargar_partida() -> bool:
	if not _nivel_valido_para_cargar():
		return false

	if not PartidaRepository.existe_guardado():
		guardado_no_encontrado.emit()
		return false

	var snapshot := PartidaRepository.cargar()

	if snapshot.is_empty():
		error_carga.emit(
			"El archivo de guardado está vacío o dañado."
		)
		return false

	_cargando_progreso = true

	var celdas_destruidas := (
		SerializacionService.obtener_celdas_destruidas(
			snapshot
		)
	)

	EstadoTemporalRepository.establecer_celdas_destruidas(
		celdas_destruidas
	)

	for celda in celdas_destruidas:
		_terreno_actual.aplicar_celda_destruida(celda)

	_aplicar_datos_cenizos(
		SerializacionService.obtener_datos_cenizos(snapshot)
	)

	_indice_cenizo_activo = _normalizar_indice_cenizo(
		SerializacionService.obtener_indice_cenizo_activo(
			snapshot
		)
	)

	_aplicar_recursos(
		SerializacionService.obtener_recursos(snapshot)
	)

	_cargando_progreso = false
	_hay_cambios_pendientes = false
	partida_cargada.emit()
	cenizo_activo_restaurado.emit(_indice_cenizo_activo)

	return true


## Botón Guardar Partida.
func guardar_partida() -> bool:
	if _cargando_progreso:
		return false

	if _cenizos_actuales.is_empty():
		error_guardado.emit(
			"No hay Cenizos registrados para guardar."
		)
		return false

	var escena_actual := ""

	if get_tree().current_scene != null:
		escena_actual = get_tree().current_scene.scene_file_path

	var snapshot := SerializacionService.construir_snapshot(
		_serializar_cenizos(),
		_indice_cenizo_activo,
		EstadoTemporalRepository.obtener_celdas_destruidas(),
		escena_actual,
		_obtener_recursos()
	)

	if not PartidaRepository.guardar(snapshot):
		error_guardado.emit(
			"No se pudo escribir el archivo de guardado."
		)
		return false

	_hay_cambios_pendientes = false
	partida_guardada.emit()
	return true


## Llama a esta función desde el botón Nueva Partida.
## Normalmente debe ejecutarse antes de abrir la escena del juego.
func nueva_partida(eliminar_guardado_anterior: bool = true) -> bool:
	_cargar_al_iniciar_nivel = false
	_cargando_progreso = false
	_hay_cambios_pendientes = false
	EstadoTemporalRepository.limpiar()

	if eliminar_guardado_anterior:
		if not PartidaRepository.eliminar_guardado():
			error_guardado.emit(
				"No se pudo eliminar la partida anterior."
			)
			return false

	partida_nueva_creada.emit()
	return true


func existe_partida_guardada() -> bool:
	return PartidaRepository.existe_guardado()


func establecer_cenizo_activo(indice: int) -> void:
	_indice_cenizo_activo = _normalizar_indice_cenizo(indice)
	notificar_cambio()


func obtener_indice_cenizo_activo() -> int:
	return _indice_cenizo_activo


## Úsalo cuando cambien recursos, mejoras, vida, energía u otros datos
## que deban activar un autoguardado diferido.
func notificar_cambio() -> void:
	if _cargando_progreso:
		return

	_hay_cambios_pendientes = true
	_programar_autoguardado()


func _ejecutar_carga_pendiente() -> void:
	_cargar_al_iniciar_nivel = false
	cargar_partida()


func _on_bloque_destruido(
	celda: Vector2i,
	_posicion_global: Vector2
) -> void:
	if _cargando_progreso:
		return

	EstadoTemporalRepository.registrar_celda_destruida(celda)
	notificar_cambio()


func _programar_autoguardado() -> void:
	if not is_instance_valid(_temporizador_autoguardado):
		return

	_temporizador_autoguardado.start()


func _on_temporizador_autoguardado_timeout() -> void:
	if not _hay_cambios_pendientes:
		return

	guardar_partida()


func _serializar_cenizos() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	for cenizo in _cenizos_actuales:
		if not is_instance_valid(cenizo):
			continue

		var datos: Dictionary = {}

		if cenizo.has_method("obtener_datos_guardado"):
			var datos_personalizados: Variant = cenizo.call(
				"obtener_datos_guardado"
			)

			if typeof(datos_personalizados) == TYPE_DICTIONARY:
				var diccionario_personalizado: Dictionary = (
					datos_personalizados
				)
				datos.merge(diccionario_personalizado, true)

		# Estos campos siempre se escriben con un formato conocido.
		datos["nombre"] = String(cenizo.name)
		datos["posicion"] = [
			cenizo.global_position.x,
			cenizo.global_position.y,
		]

		resultado.append(datos)

	return resultado


func _aplicar_datos_cenizos(
	datos_guardados: Array[Dictionary]
) -> void:
	for indice in range(datos_guardados.size()):
		var datos := datos_guardados[indice]
		var nombre := str(datos.get("nombre", ""))
		var cenizo := _buscar_cenizo(nombre, indice)

		if not is_instance_valid(cenizo):
			continue

		cenizo.global_position = (
			SerializacionService.obtener_posicion_desde_datos_cenizo(
				datos
			)
		)

		if cenizo.has_method("cargar_datos_guardado"):
			cenizo.call("cargar_datos_guardado", datos)


func _buscar_cenizo(
	nombre: String,
	indice_respaldo: int
) -> CharacterBody2D:
	if not nombre.is_empty():
		for cenizo in _cenizos_actuales:
			if is_instance_valid(cenizo) and cenizo.name == nombre:
				return cenizo

	if indice_respaldo >= 0 and indice_respaldo < _cenizos_actuales.size():
		return _cenizos_actuales[indice_respaldo]

	return null


func _obtener_recursos() -> Dictionary:
	var resource_manager := get_node_or_null(
		"/root/ResourceManager"
	)

	if resource_manager == null:
		return {}

	if resource_manager.has_method("obtener_datos_guardado"):
		var datos: Variant = resource_manager.call(
			"obtener_datos_guardado"
		)

		if typeof(datos) == TYPE_DICTIONARY:
			var diccionario: Dictionary = datos
			return diccionario.duplicate(true)

	return {}


func _aplicar_recursos(recursos: Dictionary) -> void:
	var resource_manager := get_node_or_null(
		"/root/ResourceManager"
	)

	if resource_manager == null:
		return

	if resource_manager.has_method("cargar_datos"):
		resource_manager.call("cargar_datos", recursos)
	elif resource_manager.has_method("cargar_datos_guardado"):
		resource_manager.call(
			"cargar_datos_guardado",
			recursos
		)


func _nivel_valido_para_cargar() -> bool:
	if not is_instance_valid(_terreno_actual):
		error_carga.emit(
			"No hay un terreno registrado para cargar."
		)
		return false

	if _cenizos_actuales.is_empty():
		error_carga.emit(
			"No hay Cenizos registrados para cargar."
		)
		return false

	return true


func _normalizar_indice_cenizo(indice: int) -> int:
	if _cenizos_actuales.is_empty():
		return 0

	return clampi(
		indice,
		0,
		_cenizos_actuales.size() - 1
	)


func _desconectar_terreno_anterior() -> void:
	if not is_instance_valid(_terreno_actual):
		return

	if _terreno_actual.bloque_destruido.is_connected(
		_on_bloque_destruido
	):
		_terreno_actual.bloque_destruido.disconnect(
			_on_bloque_destruido
		)
