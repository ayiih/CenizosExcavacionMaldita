extends CharacterBody2D
class_name Cenizo

signal orden_asignada(cenizo: Cenizo, orden: OrdenTrabajo)
signal orden_iniciada(cenizo: Cenizo, orden: OrdenTrabajo)
signal orden_completada(cenizo: Cenizo, orden: OrdenTrabajo)
signal orden_cancelada(cenizo: Cenizo, orden: OrdenTrabajo)
signal orden_bloqueada(cenizo: Cenizo, motivo: String)
signal bloque_destruido_por_cenizo(cenizo: Cenizo, celda: Vector2i)
signal estado_cambiado(cenizo: Cenizo, anterior: int, nuevo: int)

@export_category("Movimiento")
@export var velocidad: float = 120.0
@export var aceleracion: float = 900.0
@export var frenado: float = 1200.0
@export var fuerza_salto: float = 280.0
@export var velocidad_maxima_caida: float = 500.0

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


func _ready() -> void:
	gravedad = ProjectSettings.get_setting(
		"physics/2d/default_gravity",
		980.0
	)


func _physics_process(delta: float) -> void:
	var direccion_x := 0.0
	var direccion_y := 0.0

	if orden_actual != null and orden_actual.activa and not control_manual_habilitado:
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
		orden_bloqueada.emit(self, "No puedo excavar este material.")
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
	velocity.x = 0.0

	if orden_actual.direccion.x != 0:
		ultima_direccion = signf(float(orden_actual.direccion.x))

	if especialidad_actual != null:
		especialidad_actual.comenzar_trabajo(self, orden_actual)

	cambiar_estado(EstadoCenizo.Valor.EXCAVANDO)
	orden_iniciada.emit(self, orden_actual)


func _actualizar_excavacion(delta: float) -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 1.0
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
