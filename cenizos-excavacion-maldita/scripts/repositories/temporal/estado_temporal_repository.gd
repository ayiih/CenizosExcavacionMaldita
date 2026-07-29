extends Node

## Repositorio en memoria del progreso de la sesión actual.
## No accede a disco: es un buffer intermedio entre el gameplay
## y la persistencia real que maneja PartidaRepository.

var _celdas_destruidas: Array[Vector2i] = []


func registrar_celda_destruida(celda: Vector2i) -> void:
	if not _celdas_destruidas.has(celda):
		_celdas_destruidas.append(celda)


func obtener_celdas_destruidas() -> Array[Vector2i]:
	return _celdas_destruidas.duplicate()


func establecer_celdas_destruidas(celdas: Array[Vector2i]) -> void:
	_celdas_destruidas = celdas.duplicate()


func limpiar() -> void:
	_celdas_destruidas.clear()
