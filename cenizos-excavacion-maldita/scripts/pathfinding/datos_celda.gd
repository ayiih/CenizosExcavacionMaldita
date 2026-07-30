class_name DatosCelda
extends RefCounted

## Resultado de clasificar una celda de la cuadrícula para el
## SistemaPathfindingCenizos. Es un dato de solo lectura, recalculado
## cada vez que se reconstruye el grafo (no se cachea aparte del
## diccionario interno del sistema).

enum TipoCelda {
	VACIA_TRANSITABLE,
	PISO,
	ESCALERA,
	TERRENO_EXCAVABLE,
	TERRENO_INDESTRUCTIBLE,
	PELIGRO,
	FUERA_DEL_MAPA,
}

var celda: Vector2i = Vector2i.ZERO
var tipo: TipoCelda = TipoCelda.FUERA_DEL_MAPA

## Costo adicional de atravesar esta celda (multiplica la distancia
## en el AStar2D mediante weight_scale). 1.0 = caminar normal.
var costo_navegacion: float = 1.0

## Solo relevante si tipo == TERRENO_EXCAVABLE.
var especialidad_requerida: StringName = &""
var tipo_material: int = -1


func es_transitable() -> bool:
	return (
		tipo == TipoCelda.VACIA_TRANSITABLE
		or tipo == TipoCelda.ESCALERA
		or tipo == TipoCelda.TERRENO_EXCAVABLE
	)
