extends CharacterBody2D
class_name Cenizo

@export_category("Movimiento")
@export var velocidad: float = 120.0
@export var aceleracion: float = 900.0
@export var frenado: float = 1200.0
@export var fuerza_salto: float = 280.0
@export var velocidad_maxima_caida: float = 500.0

@export_category("Escalera")
@export var velocidad_escalera: float = 85.0
@export var velocidad_centrado: float = 250.0

@onready var sprite: AnimatedSprite2D = get_node_or_null(
	"AnimatedSprite2D"
) as AnimatedSprite2D

var gravedad: float = 980.0

var contactos_escalera: int = 0
var centro_escalera_x: float = 0.0
var escalando: bool = false


func _ready() -> void:
	gravedad = ProjectSettings.get_setting(
		"physics/2d/default_gravity",
		980.0
	)


func _physics_process(delta: float) -> void:
	var direccion_x := Input.get_axis(
		"mover_izquierda",
		"mover_derecha"
	)

	var direccion_y := Input.get_axis(
		"mover_arriba",
		"mover_abajo"
	)

	_comprobar_escalera(direccion_y)

	if escalando:
		_mover_en_escalera(direccion_y, delta)
	else:
		_mover_normal(direccion_x, delta)

	move_and_slide()

	_actualizar_animacion(direccion_x, direccion_y)


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


func _mover_normal(direccion_x: float, delta: float) -> void:
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

		if Input.is_action_just_pressed("saltar"):
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
