class_name OrdenTrabajo
extends RefCounted

## Representa una orden de trabajo autónoma asignada a un Cenizo
## (por ejemplo, excavar en una dirección hasta que ya no pueda continuar).

enum TipoOrden {
	EXCAVAR,
	CONSTRUIR,
	EXTRAER,
	DEMOLER,
}

enum MotivoFin {
	NINGUNO,
	COMPLETADA,
	CANCELADA,
	SIN_TERRENO,
	MATERIAL_INCOMPATIBLE,
	SIN_RUTA,
	PELIGRO,
	LIMITE_MAPA,
	BLOQUEADO,
}

var tipo: TipoOrden
var celda_objetivo: Vector2i
var direccion: Vector2i
var posicion_objetivo: Vector2 = Vector2.ZERO
var terreno_objetivo: Node

var activa: bool = true
var motivo_fin: MotivoFin = MotivoFin.NINGUNO

## Tiempo acumulado desde el último golpe de trabajo sobre esta orden.
## Vive acá (y no en la especialidad) para que la especialidad pueda
## ser un recurso sin estado, compartible entre varios Cenizos.
var tiempo_desde_ultimo_golpe: float = 0.0


func _init(
	tipo_orden: TipoOrden,
	celda: Vector2i,
	direccion_trabajo: Vector2i,
	terreno: Node
) -> void:
	tipo = tipo_orden
	celda_objetivo = celda
	direccion = direccion_trabajo
	terreno_objetivo = terreno


func finalizar(motivo: MotivoFin) -> void:
	activa = false
	motivo_fin = motivo
