extends TileMapLayer
class_name TerrenoDestructible

signal bloque_golpeado(
	celda: Vector2i,
	golpes_restantes: int
)

signal bloque_destruido(
	celda: Vector2i,
	posicion_global: Vector2
)

@export_category("Resistencia")

## Cantidad de golpes necesarios para destruir un bloque.
@export_range(1, 20, 1)
var golpes_para_romper: int = 3

## Guarda los golpes que ha recibido cada celda.
var golpes_recibidos: Dictionary = {}


func golpear_posicion_global(
	posicion_global_golpe: Vector2,
	fuerza: int = 1
) -> bool:
	var posicion_local := to_local(
		posicion_global_golpe
	)

	var celda := local_to_map(
		posicion_local
	)

	return golpear_celda(celda, fuerza)


func golpear_celda(
	celda: Vector2i,
	fuerza: int = 1
) -> bool:
	if get_cell_source_id(celda) == -1:
		return false

	var golpes_actuales: int = golpes_recibidos.get(
		celda,
		0
	)

	golpes_actuales += maxi(fuerza, 1)
	golpes_recibidos[celda] = golpes_actuales

	var golpes_restantes := maxi(
		golpes_para_romper - golpes_actuales,
		0
	)

	print(
		"Golpes restantes: ",
		golpes_restantes
	)

	if golpes_actuales >= golpes_para_romper:
		_destruir_celda(celda)

	return true


func _destruir_celda(celda: Vector2i) -> void:
	golpes_recibidos.erase(celda)
	erase_cell(celda)

	print(
		"Bloque destruido: ",
		celda
	)


func reiniciar_dano() -> void:
	golpes_recibidos.clear()
