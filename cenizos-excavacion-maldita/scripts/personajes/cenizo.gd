extends CharacterBody2D
class_name Cenizo

@export_category("Movimiento")
@export var velocidad_movimiento: float = 120.0
@export var aceleracion: float = 900.0
@export var frenado: float = 1200.0
@export var fuerza_salto: float = 270.0
@export var velocidad_caida_maxima: float = 500.0

@export_category("Escalera")
@export var velocidad_escalera: float = 85.0
@export var velocidad_centrado_escalera: float = 80.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var gravedad: float = ProjectSettings.get_setting(
	"physics/2d/default_gravity"
)

var contactos_escalera: int = 0
var escalando: bool = false
var centro_escalera_x: float = 0.0


func _physics_process(delta: float) -> void:
	var direccion_x := Input.get_axis(
		"mover_izquierda",
		"mover_derecha"
	)

	var direccion_y := Input.get_axis(
		"mover_arriba",
		"mover_abajo"
	)

	_comprobar_inicio_escalada(direccion_y)
	_procesar_movimiento_horizontal(direccion_x, delta)
	_procesar_movimiento_vertical(direccion_y, delta)

	move_and_slide()

	_actualizar_animacion(direccion_x, direccion_y)


func _comprobar_inicio_escalada(direccion_y: float) -> void:
	if esta_en_escalera() and abs(direccion_y) > 0.01:
		escalando = true

	if escalando and Input.is_action_just_pressed("saltar"):
		escalando = false
		velocity.y = -fuerza_salto


func _procesar_movimiento_horizontal(
	direccion_x: float,
	delta: float
) -> void:
	if escalando:
		var diferencia_x := centro_escalera_x - global_position.x

		velocity.x = clamp(
			diferencia_x * 8.0,
			-velocidad_centrado_escalera,
			velocidad_centrado_escalera
		)

		return

	var velocidad_objetivo := direccion_x * velocidad_movimiento

	var velocidad_cambio := aceleracion

	if abs(direccion_x) < 0.01:
		velocidad_cambio = frenado

	velocity.x = move_toward(
		velocity.x,
		velocidad_objetivo,
		velocidad_cambio * delta
	)


func _procesar_movimiento_vertical(
	direccion_y: float,
	delta: float
) -> void:
	if escalando:
		if not esta_en_escalera():
			escalando = false
		else:
			velocity.y = direccion_y * velocidad_escalera
			return

	if not is_on_floor():
		velocity.y += gravedad * delta

		velocity.y = min(
			velocity.y,
			velocidad_caida_maxima
		)
	else:
		if Input.is_action_just_pressed("saltar"):
			velocity.y = -fuerza_salto


func esta_en_escalera() -> bool:
	return contactos_escalera > 0


func entrar_en_escalera(posicion_x: float) -> void:
	contactos_escalera += 1
	centro_escalera_x = posicion_x


func salir_de_escalera() -> void:
	contactos_escalera = maxi(
		contactos_escalera - 1,
		0
	)

	if contactos_escalera == 0:
		escalando = false


func _actualizar_animacion(
	direccion_x: float,
	direccion_y: float
) -> void:
	sprite.speed_scale = 1.0

	if abs(direccion_x) > 0.01:
		sprite.flip_h = direccion_x < 0.0

	if escalando:
		_reproducir_animacion("climb")

		if abs(direccion_y) < 0.01:
			sprite.speed_scale = 0.0

		return

	if not is_on_floor():
		_reproducir_animacion("jump")
		return

	if abs(velocity.x) > 5.0:
		_reproducir_animacion("walk")
	else:
		_reproducir_animacion("idle")


func _reproducir_animacion(nombre: StringName) -> void:
	if sprite.animation != nombre:
		sprite.play(nombre)
