extends CharacterBody2D
class_name Cenizo

signal orden_asignada(cenizo: Cenizo, orden: OrdenTrabajo)
signal orden_iniciada(cenizo: Cenizo, orden: OrdenTrabajo)
signal orden_completada(cenizo: Cenizo, orden: OrdenTrabajo)
signal orden_cancelada(cenizo: Cenizo, orden: OrdenTrabajo)
signal orden_bloqueada(cenizo: Cenizo, motivo: String)
signal bloque_destruido_por_cenizo(cenizo: Cenizo, celda: Vector2i)
signal estado_cambiado(cenizo: Cenizo, anterior: int, nuevo: int)

signal destino_asignado(cenizo: Cenizo, posicion: Vector2)
signal ruta_calculada(cenizo: Cenizo, ruta: Array)
signal ruta_no_disponible(cenizo: Cenizo, motivo: String)
signal destino_alcanzado(cenizo: Cenizo)
signal orden_movimiento_cancelada(cenizo: Cenizo)

@export_category("Identidad")

## Nombre mostrado en el panel de HUD (ej. "Cenizo Excavador").
@export var nombre_visible: String = "Cenizo"

## Retrato mostrado en el panel de HUD.
@export var icono_retrato: Texture2D

@export_category("Estadísticas")
@export var vida_maxima: int = 100
@export var energia_maxima: int = 100

var vida_actual: int
var energia_actual: int

@export_category("Movimiento")
@export var velocidad: float = 120.0
@export var aceleracion: float = 900.0
@export var frenado: float = 1200.0
@export var fuerza_salto: float = 280.0
@export var velocidad_maxima_caida: float = 500.0

## Velocidad con la que el Cenizo sigue empujando hacia el bloque
## mientras excava en horizontal (no se queda parado picando: la
## colisión con el bloque aún sólido lo detiene físicamente hasta
## que se rompe, y entonces avanza solo, sin teletransportarse).
@export var velocidad_empuje_excavacion: float = 45.0

@export_category("Escalera")
@export var velocidad_escalera: float = 85.0
@export var velocidad_centrado: float = 250.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camara: Camera2D = $Camera2D
@onready var minero: Minero = $Minero
@onready var indicador_activo: Node2D = $IndicadorActivo

var ultima_direccion: float = 1.0

var gravedad: float = 980.0

var contactos_escalera: int = 0
var centro_escalera_x: float = 0.0
var escalando: bool = false

## Solo el Cenizo con control_activo = true lee entradas del jugador.
var control_activo: bool = true

## Falso mientras el Cenizo ejecuta una orden autónoma o el jugador
## armó una dirección de trabajo (ver GestorCenizos).
var control_manual_habilitado: bool = true

## True mientras hay una dirección de excavación armada para este
## Cenizo (usado por Minero para no picar manualmente a la vez).
var modo_orden_armado: bool = false

var estado: EstadoCenizo.Valor = EstadoCenizo.Valor.INACTIVO

var orden_actual: OrdenTrabajo = null
var especialidad_actual: EspecialidadCenizo = EspecialidadExcavador.new()

## Asignado externamente (por GestorCenizos) al iniciar el nivel.
var sistema_pathfinding: SistemaPathfindingCenizos = null
var orden_movimiento_actual: OrdenMovimientoCenizo = null

@export_category("Pathfinding")
@export var tolerancia_celda_ruta: float = 3.0
@export var intervalo_golpe_ruta: float = 0.4
@export var danio_excavacion_ruta: int = 1

var _direccion_excavacion_ruta: Vector2i = Vector2i.ZERO


func _ready() -> void:
	gravedad = ProjectSettings.get_setting(
		"physics/2d/default_gravity",
		980.0
	)

	vida_actual = vida_maxima
	energia_actual = energia_maxima


func _physics_process(delta: float) -> void:
	var direccion_x := 0.0
	var direccion_y := 0.0

	var tiene_orden_movimiento := orden_movimiento_actual != null and orden_movimiento_actual.activa
	var tiene_orden_trabajo := orden_actual != null and orden_actual.activa

	if tiene_orden_movimiento and not control_manual_habilitado:
		_procesar_estado_ruta(delta)
	elif tiene_orden_trabajo and not control_manual_habilitado:
		_procesar_estado_orden(delta)
	elif control_activo and control_manual_habilitado:
		direccion_x = Input.get_axis(
			"mover_izquierda",
			"mover_derecha"
		)

		direccion_y = Input.get_axis(
			"mover_arriba",
			"mover_abajo"
		)

		# Guardar la última dirección horizontal.
		if direccion_x < 0.0:
			ultima_direccion = -1.0
		elif direccion_x > 0.0:
			ultima_direccion = 1.0

		_comprobar_escalera(direccion_y)

		if escalando:
			_mover_en_escalera(direccion_y, delta)
		else:
			_mover_normal(direccion_x, delta)
	else:
		_procesar_fisica_inactiva(delta)

	move_and_slide()

	_actualizar_animacion(direccion_x, direccion_y)

	# Aplicarlo después de cambiar la animación.
	sprite.flip_h = ultima_direccion < 0.0


## Activa o desactiva el control del jugador sobre este Cenizo.
## Llamado por GestorCenizos al cambiar de personaje con TAB.
func set_control_activo(valor: bool) -> void:
	control_activo = valor

	if not valor:
		# Detiene el movimiento horizontal y cancela la escalada automática.
		velocity.x = 0.0
		escalando = false
		motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
		floor_snap_length = 1.0

		if minero != null:
			minero.cancelar_picado()

	if camara != null:
		camara.enabled = valor

		if valor:
			camara.make_current()

	if indicador_activo != null:
		indicador_activo.visible = valor


## Física mínima para un Cenizo inactivo: conserva gravedad y contacto
## con el suelo, pero no lee ninguna entrada del jugador.
func _procesar_fisica_inactiva(delta: float) -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 1.0

	velocity.x = move_toward(
		velocity.x,
		0.0,
		frenado * delta
	)

	if not is_on_floor():
		velocity.y += gravedad * delta
		velocity.y = min(
			velocity.y,
			velocidad_maxima_caida
		)
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0


## --- Sistema de órdenes autónomas -------------------------------------


## Asigna una nueva orden de trabajo, validándola con la especialidad
## dada. Cancela cualquier orden previa antes de reemplazarla.
func asignar_orden(
	especialidad: EspecialidadCenizo,
	orden: OrdenTrabajo
) -> bool:
	if especialidad == null or orden == null:
		return false

	if not especialidad.puede_realizar_orden(self, orden):
		orden.finalizar(OrdenTrabajo.MotivoFin.MATERIAL_INCOMPATIBLE)
		orden_bloqueada.emit(self, "No puedo excavar ahí: debo estar pegado al bloque.")
		return false

	if orden_actual != null:
		cancelar_orden()

	especialidad_actual = especialidad
	orden_actual = orden
	orden.posicion_objetivo = especialidad.calcular_posicion_trabajo(self, orden)
	control_manual_habilitado = false

	cambiar_estado(EstadoCenizo.Valor.MOVIENDOSE_A_TAREA)
	orden_asignada.emit(self, orden)

	return true


## Cancela la orden actual a pedido del jugador (no cuenta como
## finalización natural: emite orden_cancelada, no orden_completada).
func cancelar_orden() -> void:
	if orden_actual == null:
		return

	if especialidad_actual != null:
		especialidad_actual.cancelar_trabajo(self, orden_actual)

	orden_actual.finalizar(OrdenTrabajo.MotivoFin.CANCELADA)

	var orden_previa := orden_actual
	orden_actual = null
	control_manual_habilitado = true
	velocity.x = 0.0

	cambiar_estado(EstadoCenizo.Valor.INACTIVO)
	orden_cancelada.emit(self, orden_previa)


## Finaliza la orden actual por un motivo natural (completada, sin
## terreno, bloqueada, material incompatible, etc). Llamado por la
## especialidad durante actualizar_trabajo().
func finalizar_orden(motivo: OrdenTrabajo.MotivoFin) -> void:
	if orden_actual == null:
		return

	if especialidad_actual != null:
		especialidad_actual.cancelar_trabajo(self, orden_actual)

	orden_actual.finalizar(motivo)

	var orden_previa := orden_actual
	orden_actual = null
	control_manual_habilitado = true
	velocity.x = 0.0

	if motivo == OrdenTrabajo.MotivoFin.COMPLETADA:
		cambiar_estado(EstadoCenizo.Valor.TAREA_COMPLETADA)
		orden_completada.emit(self, orden_previa)
	else:
		cambiar_estado(EstadoCenizo.Valor.BLOQUEADO)
		orden_bloqueada.emit(self, _describir_motivo(motivo))


## Cambia el estado de la máquina de estados y emite la señal
## correspondiente. Público para que las especialidades puedan usarlo.
func cambiar_estado(nuevo: EstadoCenizo.Valor) -> void:
	var anterior := estado
	estado = nuevo
	estado_cambiado.emit(self, anterior, nuevo)


## Llamado por la especialidad cuando destruye un bloque, para que
## el resto del juego (UI, sonidos, GestorCenizos) pueda reaccionar.
func notificar_bloque_destruido(celda: Vector2i) -> void:
	bloque_destruido_por_cenizo.emit(self, celda)


func _describir_motivo(motivo: OrdenTrabajo.MotivoFin) -> String:
	match motivo:
		OrdenTrabajo.MotivoFin.COMPLETADA:
			return "Tarea completada."
		OrdenTrabajo.MotivoFin.MATERIAL_INCOMPATIBLE:
			return "No puedo excavar este material."
		OrdenTrabajo.MotivoFin.SIN_RUTA:
			return "No existe una ruta segura."
		OrdenTrabajo.MotivoFin.BLOQUEADO:
			return "El camino está bloqueado."
		OrdenTrabajo.MotivoFin.SIN_TERRENO:
			return "No hay más terreno excavable."
		OrdenTrabajo.MotivoFin.PELIGRO:
			return "Hay una zona peligrosa en el camino."
		OrdenTrabajo.MotivoFin.LIMITE_MAPA:
			return "Se alcanzó el límite del mapa."
		_:
			return "La orden no pudo continuar."


func _procesar_estado_orden(delta: float) -> void:
	match estado:
		EstadoCenizo.Valor.MOVIENDOSE_A_TAREA:
			_mover_hacia_posicion_trabajo(delta)
		EstadoCenizo.Valor.PREPARANDO_TRABAJO:
			_preparar_trabajo()
		EstadoCenizo.Valor.EXCAVANDO:
			_actualizar_excavacion(delta)
		_:
			_procesar_fisica_inactiva(delta)


func _mover_hacia_posicion_trabajo(delta: float) -> void:
	var diferencia_x := orden_actual.posicion_objetivo.x - global_position.x

	if absf(diferencia_x) < 3.0:
		velocity.x = 0.0
		cambiar_estado(EstadoCenizo.Valor.PREPARANDO_TRABAJO)
		return

	var direccion_movimiento := signf(diferencia_x)

	if is_on_floor() and not _hay_suelo_seguro_adelante(direccion_movimiento):
		finalizar_orden(OrdenTrabajo.MotivoFin.SIN_RUTA)
		return

	if is_on_floor() and _hay_pared_adelante(direccion_movimiento):
		finalizar_orden(OrdenTrabajo.MotivoFin.BLOQUEADO)
		return

	ultima_direccion = direccion_movimiento
	_mover_normal(direccion_movimiento, delta, false)


func _preparar_trabajo() -> void:
	if orden_actual.direccion.x != 0:
		ultima_direccion = signf(float(orden_actual.direccion.x))
		velocity.x = ultima_direccion * velocidad_empuje_excavacion
	else:
		velocity.x = 0.0

	if especialidad_actual != null:
		especialidad_actual.comenzar_trabajo(self, orden_actual)

	cambiar_estado(EstadoCenizo.Valor.EXCAVANDO)
	orden_iniciada.emit(self, orden_actual)


func _actualizar_excavacion(delta: float) -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 1.0

	if orden_actual.direccion == Vector2i.LEFT or orden_actual.direccion == Vector2i.RIGHT:
		velocity.x = signf(float(orden_actual.direccion.x)) * velocidad_empuje_excavacion
	else:
		velocity.x = 0.0

	if not is_on_floor():
		velocity.y += gravedad * delta
		velocity.y = min(velocity.y, velocidad_maxima_caida)
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	if especialidad_actual != null:
		especialidad_actual.actualizar_trabajo(self, orden_actual, delta)


## Comprueba, usando el terreno de la orden actual, si existe suelo
## firme un poco por delante y por debajo del Cenizo (evita pozos).
func _hay_suelo_seguro_adelante(direccion_x: float) -> bool:
	var terreno := orden_actual.terreno_objetivo as TerrenoDestructible

	if terreno == null:
		return true

	var punto_adelante := global_position + Vector2(16.0 * direccion_x, 20.0)
	var celda := terreno.local_to_map(terreno.to_local(punto_adelante))

	return terreno.get_cell_source_id(celda) != -1


## Comprueba si hay un bloque sólido bloqueando el paso horizontal
## hacia la posición de trabajo (distinto del bloque a excavar).
func _hay_pared_adelante(direccion_x: float) -> bool:
	var terreno := orden_actual.terreno_objetivo as TerrenoDestructible

	if terreno == null:
		return false

	var punto_adelante := global_position + Vector2(16.0 * direccion_x, 0.0)
	var celda := terreno.local_to_map(terreno.to_local(punto_adelante))

	return terreno.get_cell_source_id(celda) != -1


## --- Sistema de órdenes de movimiento (pathfinding) ---------------------


## Calcula una ruta con sistema_pathfinding hasta destino_global y, si
## existe, la asigna como orden activa. Cancela cualquier orden previa
## (de trabajo o de movimiento) antes de reemplazarla.
func asignar_destino(destino_global: Vector2) -> bool:
	if sistema_pathfinding == null:
		return false

	var ruta := sistema_pathfinding.calcular_ruta(self, global_position, destino_global)

	if ruta.is_empty():
		ruta_no_disponible.emit(self, "No existe una ruta hasta ese destino.")
		return false

	if orden_movimiento_actual != null:
		cancelar_orden_movimiento()

	if orden_actual != null:
		cancelar_orden()

	var orden := OrdenMovimientoCenizo.new()
	orden.celda_destino = sistema_pathfinding.celda_desde_posicion_global(destino_global)
	orden.posicion_destino_global = sistema_pathfinding.posicion_global_de_celda(orden.celda_destino)
	orden.ruta = ruta
	orden.indice_actual = 0

	orden_movimiento_actual = orden
	control_manual_habilitado = false

	destino_asignado.emit(self, destino_global)
	ruta_calculada.emit(self, ruta)

	cambiar_estado(EstadoCenizo.Valor.MOVIENDOSE_A_TAREA)

	return true


## Cancela la orden de movimiento actual a pedido del jugador. No
## destruye el bloque que estuviera excavando en ese instante.
func cancelar_orden_movimiento() -> void:
	if orden_movimiento_actual == null:
		return

	orden_movimiento_actual.finalizar()
	orden_movimiento_actual = null
	control_manual_habilitado = true
	velocity.x = 0.0
	escalando = false
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 1.0

	cambiar_estado(EstadoCenizo.Valor.INACTIVO)
	orden_movimiento_cancelada.emit(self)


func _finalizar_orden_movimiento(alcanzo_destino: bool, motivo: String = "") -> void:
	if orden_movimiento_actual == null:
		return

	orden_movimiento_actual.finalizar()
	orden_movimiento_actual = null
	control_manual_habilitado = true
	velocity.x = 0.0
	escalando = false
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 1.0

	if alcanzo_destino:
		cambiar_estado(EstadoCenizo.Valor.DESTINO_ALCANZADO)
		destino_alcanzado.emit(self)
	else:
		cambiar_estado(EstadoCenizo.Valor.BLOQUEADO)
		orden_bloqueada.emit(self, motivo)


func _procesar_estado_ruta(delta: float) -> void:
	var orden := orden_movimiento_actual

	if orden.llego_al_final():
		_finalizar_orden_movimiento(true)
		return

	if estado == EstadoCenizo.Valor.EXCAVANDO:
		_actualizar_excavacion_ruta(delta, orden.celda_actual_objetivo())
		return

	if estado == EstadoCenizo.Valor.ESCALANDO:
		_mover_hacia_waypoint_escalera(orden.celda_actual_objetivo(), delta)
		return

	if sistema_pathfinding == null:
		_finalizar_orden_movimiento(false, "El sistema de pathfinding no está disponible.")
		return

	var datos := sistema_pathfinding.clasificar_celda(orden.celda_actual_objetivo())

	match datos.tipo:
		DatosCelda.TipoCelda.TERRENO_EXCAVABLE:
			_iniciar_excavacion_ruta(orden.celda_actual_objetivo())
		DatosCelda.TipoCelda.ESCALERA:
			_mover_hacia_waypoint_escalera(orden.celda_actual_objetivo(), delta)
		_:
			_mover_hacia_waypoint_suelo(orden.celda_actual_objetivo(), delta)


func _avanzar_waypoint_ruta() -> void:
	if orden_movimiento_actual == null:
		return

	orden_movimiento_actual.indice_actual += 1
	orden_movimiento_actual.tiempo_desde_ultimo_golpe = 0.0
	cambiar_estado(EstadoCenizo.Valor.MOVIENDOSE_A_TAREA)


func _mover_hacia_waypoint_suelo(celda: Vector2i, delta: float) -> void:
	var destino_global := sistema_pathfinding.posicion_global_de_celda(celda)
	var diferencia_x := destino_global.x - global_position.x

	if absf(diferencia_x) < tolerancia_celda_ruta:
		# Alineado en x: si el waypoint está más abajo (una caída),
		# hay que esperar a que la gravedad lo baje de verdad antes de
		# darlo por alcanzado. Antes se avanzaba con solo alinear x,
		# lo que dejaba la ruta "adelantada" varias celdas sin que el
		# Cenizo se hubiera movido, y terminaba excavando bloques
		# lejanos desde su posición real (más arriba).
		velocity.x = move_toward(velocity.x, 0.0, frenado * delta)

		if not is_on_floor():
			velocity.y += gravedad * delta
			velocity.y = min(velocity.y, velocidad_maxima_caida)
			return

		if velocity.y > 0.0:
			velocity.y = 0.0

		_avanzar_waypoint_ruta()
		return

	var direccion_movimiento := signf(diferencia_x)
	ultima_direccion = direccion_movimiento
	_mover_normal(direccion_movimiento, delta, false)


func _mover_hacia_waypoint_escalera(celda: Vector2i, delta: float) -> void:
	var destino_global := sistema_pathfinding.posicion_global_de_celda(celda)
	var diferencia_x := destino_global.x - global_position.x

	# Primero alinearse en x caminando por el suelo, antes de subir.
	if not escalando and absf(diferencia_x) > tolerancia_celda_ruta:
		var direccion_movimiento := signf(diferencia_x)
		ultima_direccion = direccion_movimiento
		_mover_normal(direccion_movimiento, delta, false)
		return

	escalando = true
	centro_escalera_x = destino_global.x
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	floor_snap_length = 0.0
	cambiar_estado(EstadoCenizo.Valor.ESCALANDO)

	var diferencia_y := destino_global.y - global_position.y

	global_position.x = move_toward(
		global_position.x,
		centro_escalera_x,
		velocidad_centrado * delta
	)

	velocity.x = 0.0

	if absf(diferencia_y) < tolerancia_celda_ruta:
		velocity.y = 0.0
		_avanzar_waypoint_ruta()

		var siguiente_es_escalera := (
			not orden_movimiento_actual.llego_al_final()
			and sistema_pathfinding.clasificar_celda(orden_movimiento_actual.celda_actual_objetivo()).tipo == DatosCelda.TipoCelda.ESCALERA
		)

		if not siguiente_es_escalera:
			escalando = false
			motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
			floor_snap_length = 1.0

		return

	velocity.y = signf(diferencia_y) * velocidad_escalera


func _iniciar_excavacion_ruta(celda: Vector2i) -> void:
	orden_movimiento_actual.tiempo_desde_ultimo_golpe = 0.0

	var celda_previa := sistema_pathfinding.celda_desde_posicion_global(global_position)

	if orden_movimiento_actual.indice_actual > 0:
		celda_previa = orden_movimiento_actual.ruta[orden_movimiento_actual.indice_actual - 1]

	_direccion_excavacion_ruta = celda - celda_previa

	if _direccion_excavacion_ruta.x != 0 and _direccion_excavacion_ruta.y == 0:
		ultima_direccion = signf(float(_direccion_excavacion_ruta.x))
		velocity.x = ultima_direccion * velocidad_empuje_excavacion
	else:
		velocity.x = 0.0

	cambiar_estado(EstadoCenizo.Valor.EXCAVANDO)


## Celdas a excavar en paralelo para el waypoint actual. En horizontal
## se excava la celda lineal y la de arriba a la vez (el Cenizo mide
## más de 32px y no entra en un solo bloque de alto).
func _celdas_excavacion_ruta(celda: Vector2i) -> Array[Vector2i]:
	if _direccion_excavacion_ruta.x != 0 and _direccion_excavacion_ruta.y == 0:
		return [celda, celda + Vector2i.UP]

	return [celda]


func _actualizar_excavacion_ruta(delta: float, celda: Vector2i) -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 1.0

	if _direccion_excavacion_ruta.x != 0 and _direccion_excavacion_ruta.y == 0:
		velocity.x = signf(float(_direccion_excavacion_ruta.x)) * velocidad_empuje_excavacion
	else:
		velocity.x = 0.0

	if not is_on_floor():
		velocity.y += gravedad * delta
		velocity.y = min(velocity.y, velocidad_maxima_caida)
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	var terreno := sistema_pathfinding.terreno_destructible

	if terreno == null:
		_finalizar_orden_movimiento(false, "El terreno destructible no está disponible.")
		return

	var celdas := _celdas_excavacion_ruta(celda)

	var alguna_existe := false

	for c in celdas:
		if terreno.get_cell_source_id(c) != -1:
			alguna_existe = true
			break

	if not alguna_existe:
		# Ya fue destruido (por ejemplo por otro Cenizo): continuar.
		_avanzar_waypoint_ruta()
		return

	orden_movimiento_actual.tiempo_desde_ultimo_golpe += delta

	if orden_movimiento_actual.tiempo_desde_ultimo_golpe < intervalo_golpe_ruta:
		return

	orden_movimiento_actual.tiempo_desde_ultimo_golpe = 0.0

	var quedan_bloques := false

	for c in celdas:
		if terreno.get_cell_source_id(c) == -1:
			continue

		if not terreno.golpear_celda(c, danio_excavacion_ruta):
			_finalizar_orden_movimiento(false, "No se pudo excavar el bloque.")
			return

		if terreno.get_cell_source_id(c) != -1:
			quedan_bloques = true
		else:
			bloque_destruido_por_cenizo.emit(self, c)

	if quedan_bloques:
		return

	_avanzar_waypoint_ruta()


func _comprobar_escalera(direccion_y: float) -> void:
	# Comienza a escalar solamente al presionar arriba o abajo.
	if esta_en_escalera() and abs(direccion_y) > 0.1:
		escalando = true

	# Si salió completamente del Area2D, deja de escalar.
	if not esta_en_escalera():
		escalando = false

	# Permite saltar para abandonar la escalera.
	if escalando and Input.is_action_just_pressed("saltar"):
		escalando = false
		motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
		floor_snap_length = 1.0
		velocity.y = -fuerza_salto


func _mover_normal(
	direccion_x: float,
	delta: float,
	permitir_salto: bool = true
) -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 1.0

	var velocidad_objetivo := direccion_x * velocidad
	var cambio := aceleracion

	if abs(direccion_x) < 0.01:
		cambio = frenado

	velocity.x = move_toward(
		velocity.x,
		velocidad_objetivo,
		cambio * delta
	)

	if not is_on_floor():
		velocity.y += gravedad * delta
		velocity.y = min(
			velocity.y,
			velocidad_maxima_caida
		)
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

		if permitir_salto and Input.is_action_just_pressed("saltar"):
			velocity.y = -fuerza_salto


func _mover_en_escalera(
	direccion_y: float,
	delta: float
) -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	floor_snap_length = 0.0

	global_position.x = move_toward(
		global_position.x,
		centro_escalera_x,
		velocidad_centrado * delta
	)

	velocity.x = 0.0

	if abs(direccion_y) > 0.1:
		velocity.y = direccion_y * velocidad_escalera
	else:
		velocity.y = 0.0


func entrar_escalera(posicion_x: float) -> void:
	contactos_escalera += 1
	centro_escalera_x = posicion_x

	print("Cenizo dentro de la escalera")


func salir_escalera() -> void:
	contactos_escalera = maxi(
		contactos_escalera - 1,
		0
	)

	if contactos_escalera == 0:
		escalando = false
		motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
		floor_snap_length = 1.0

	print("Cenizo salió de la escalera")


func esta_en_escalera() -> bool:
	return contactos_escalera > 0


func _actualizar_animacion(
	direccion_x: float,
	direccion_y: float
) -> void:
	if sprite == null:
		return

	sprite.speed_scale = 1.0

	if escalando:
		_reproducir_animacion("climb")

		if abs(direccion_y) < 0.1:
			sprite.speed_scale = 0.0

		return

	if not is_on_floor():
		_reproducir_animacion("jump")
		return

	if abs(velocity.x) > 5.0:
		_reproducir_animacion("walk")
		sprite.flip_h = direccion_x < 0.0
	else:
		_reproducir_animacion("idle")


func _reproducir_animacion(nombre: StringName) -> void:
	if sprite == null:
		return

	if not sprite.sprite_frames.has_animation(nombre):
		return

	if sprite.animation != nombre:
		sprite.play(nombre)
