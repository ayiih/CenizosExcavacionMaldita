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

	var resultado := TerrenoService.golpear_celda(
		golpes_recibidos,
		celda,
		fuerza,
		golpes_para_romper
	)

	bloque_golpeado.emit(
		celda,
		resultado["golpes_restantes"]
	)

	print(
		"Golpes restantes: ",
		resultado["golpes_restantes"]
	)

	if resultado["destruida"]:
		_destruir_celda(celda)

	return true


func _destruir_celda(celda: Vector2i) -> void:
	var posicion_global := to_global(
		map_to_local(celda)
	)

	TerrenoService.destruir_celda(
		self,
		golpes_recibidos,
		celda
	)

	bloque_destruido.emit(
		celda,
		posicion_global
	)

	print(
		"Bloque destruido: ",
		celda
	)


func reiniciar_dano() -> void:
	golpes_recibidos.clear()


## Destruye una celda directamente, sin pasar por el flujo de golpes.
## Usado por GuardadoManager al restaurar progreso, para no re-disparar
## la señal bloque_destruido (y por lo tanto no re-disparar el autosave).
func aplicar_celda_destruida(celda: Vector2i) -> void:
	TerrenoService.destruir_celda(
		self,
		golpes_recibidos,
		celda
	)
