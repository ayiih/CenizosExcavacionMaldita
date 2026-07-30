extends Node
class_name Minero

@export_category("Pico")

## Distancia máxima entre el Cenizo y el centro del bloque.
@export var alcance_maximo: float = 70.0

## Daño realizado en cada clic.
@export_range(1, 10, 1)
var fuerza_pico: int = 1

## Tiempo mínimo entre golpes.
@export_range(0.05, 2.0, 0.05)
var tiempo_entre_golpes: float = 0.25

@onready var jugador: Cenizo = (
	get_parent() as Cenizo
)

@onready var puntero: PunteroPico = (
	jugador.get_node("PunteroPico") as PunteroPico
)

var terreno_destructible: TerrenoDestructible

var celda_objetivo: Vector2i = Vector2i.ZERO
var objetivo_valido: bool = false
var enfriamiento_restante: float = 0.0


func configurar_terreno(
	nuevo_terreno: TerrenoDestructible
) -> void:
	terreno_destructible = nuevo_terreno


## Cancela cualquier objetivo pendiente y oculta el puntero.
## Llamado por Cenizo.set_control_activo(false).
func cancelar_picado() -> void:
	objetivo_valido = false
	enfriamiento_restante = 0.0

	if puntero != null:
		puntero.ocultar()


func _process(delta: float) -> void:
	enfriamiento_restante = maxf(
		enfriamiento_restante - delta,
		0.0
	)

	if (
		jugador == null
		or not jugador.control_activo
		or jugador.modo_orden_armado
		or jugador.orden_actual != null
	):
		objetivo_valido = false

		if puntero != null:
			puntero.ocultar()

		return

	_actualizar_objetivo()

	if Input.is_action_just_pressed("picar"):
		_picar_objetivo()


func _actualizar_objetivo() -> void:
	if terreno_destructible == null:
		objetivo_valido = false

		if puntero != null:
			puntero.ocultar()

		return

	# Posición global actual del mouse.
	var posicion_mouse_global := (
		jugador.get_global_mouse_position()
	)

	# Convierte el mouse al espacio local del TileMapLayer.
	var posicion_mouse_local := (
		terreno_destructible.to_local(
			posicion_mouse_global
		)
	)

	# Obtiene la celda que está debajo del mouse.
	celda_objetivo = terreno_destructible.local_to_map(
		posicion_mouse_local
	)

	# Obtiene el centro exacto de esa celda.
	var centro_celda_local := (
		terreno_destructible.map_to_local(
			celda_objetivo
		)
	)

	var centro_celda_global := (
		terreno_destructible.to_global(
			centro_celda_local
		)
	)

	var existe_bloque := (
		terreno_destructible.get_cell_source_id(
			celda_objetivo
		) != -1
	)

	var distancia := jugador.global_position.distance_to(
		centro_celda_global
	)

	var esta_dentro_del_alcance := (
		distancia <= alcance_maximo
	)

	objetivo_valido = (
		existe_bloque
		and esta_dentro_del_alcance
	)

	if puntero != null:
		puntero.establecer_objetivo(
			centro_celda_global,
			objetivo_valido
		)


func _picar_objetivo() -> void:
	if enfriamiento_restante > 0.0:
		return

	if terreno_destructible == null:
		push_warning(
			"El Minero no tiene TerrenoDestructible."
		)
		return

	if not objetivo_valido:
		print(
			"No se puede picar este bloque."
		)
		return

	var bloque_golpeado := (
		terreno_destructible.golpear_celda(
			celda_objetivo,
			fuerza_pico
		)
	)

	if bloque_golpeado:
		enfriamiento_restante = tiempo_entre_golpes

		print(
			"Picando celda: ",
			celda_objetivo
		)
