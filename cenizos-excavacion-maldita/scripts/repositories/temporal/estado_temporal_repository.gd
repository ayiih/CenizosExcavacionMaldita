extends Node

## Repositorio en memoria del progreso de la sesión actual.
## No escribe en disco. PartidaRepository se encarga de la persistencia.

signal celdas_actualizadas

var _celdas_destruidas: Array[Vector2i] = []


func registrar_celda_destruida(celda: Vector2i) -> void:
	if _celdas_destruidas.has(celda):
		return

	_celdas_destruidas.append(celda)
	celdas_actualizadas.emit()


func registrar_celdas_destruidas(celdas: Array[Vector2i]) -> void:
	var hubo_cambios := false

	for celda in celdas:
		if _celdas_destruidas.has(celda):
			continue

		_celdas_destruidas.append(celda)
		hubo_cambios = true

	if hubo_cambios:
		celdas_actualizadas.emit()


func contiene_celda(celda: Vector2i) -> bool:
	return _celdas_destruidas.has(celda)


func obtener_celdas_destruidas() -> Array[Vector2i]:
	return _celdas_destruidas.duplicate()


func establecer_celdas_destruidas(celdas: Array[Vector2i]) -> void:
	_celdas_destruidas = celdas.duplicate()
	celdas_actualizadas.emit()


func limpiar() -> void:
	if _celdas_destruidas.is_empty():
		return

	_celdas_destruidas.clear()
	celdas_actualizadas.emit()
