class_name OrdenMovimientoCenizo
extends RefCounted

## Orden autónoma de "caminar hasta un punto", calculada por
## SistemaPathfindingCenizos. Vive por instancia de Cenizo (no
## compartida), tal como OrdenTrabajo.

var posicion_destino_global: Vector2 = Vector2.ZERO
var celda_destino: Vector2i = Vector2i.ZERO

## Ruta de celdas (incluye la celda inicial) devuelta por AStar2D.
var ruta: Array[Vector2i] = []
var indice_actual: int = 0

var activa: bool = true
var permite_excavar: bool = true

## Tiempo acumulado desde el último golpe, mientras esta orden
## excava un bloque en medio de la ruta.
var tiempo_desde_ultimo_golpe: float = 0.0


func celda_actual_objetivo() -> Vector2i:
	if indice_actual < 0 or indice_actual >= ruta.size():
		return celda_destino

	return ruta[indice_actual]


func llego_al_final() -> bool:
	return indice_actual >= ruta.size()


func finalizar() -> void:
	activa = false
