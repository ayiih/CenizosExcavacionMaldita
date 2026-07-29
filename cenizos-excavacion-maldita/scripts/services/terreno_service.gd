class_name TerrenoService
extends RefCounted

## Lógica pura de daño de terreno, extraída de TerrenoDestructible
## para que sea reutilizable y testeable sin depender de un nodo.


## Aplica un golpe sobre el registro de daño de una celda.
## No modifica el TileMapLayer; solo calcula el resultado.
static func golpear_celda(
	golpes_recibidos: Dictionary,
	celda: Vector2i,
	fuerza: int,
	golpes_para_romper: int
) -> Dictionary:
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

	return {
		"golpes_actuales": golpes_actuales,
		"golpes_restantes": golpes_restantes,
		"destruida": golpes_actuales >= golpes_para_romper,
	}


## Destruye una celda del TileMapLayer y limpia su registro de daño.
static func destruir_celda(
	tilemap: TileMapLayer,
	golpes_recibidos: Dictionary,
	celda: Vector2i
) -> void:
	golpes_recibidos.erase(celda)
	tilemap.erase_cell(celda)
