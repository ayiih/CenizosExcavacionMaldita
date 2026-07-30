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

enum TipoMaterial {
	TIERRA,
	PIEDRA,
	MADERA,
	CEMENTO,
	ROCA_GEMAS,
	ROCA_ACERO,
	HUESOS,
	ADOQUIN,
	MARMOL,
}

@export_category("Resistencia")

## Cantidad de golpes necesarios para destruir un bloque.
@export_range(1, 20, 1)
var golpes_para_romper: int = 3

## Guarda los golpes que ha recibido cada celda.
var golpes_recibidos: Dictionary = {}

@export_category("Material")

## Material y especialidad requerida por defecto para todas las celdas
## de este TerrenoDestructible.
@export var tipo_material_default: TipoMaterial = TipoMaterial.TIERRA
@export var especialidad_requerida_default: StringName = &"excavador"
@export var excavable_default: bool = true

## Excepciones puntuales por celda. Cada valor es un Dictionary opcional
## con las claves "tipo_material", "especialidad_requerida", "excavable"
## y/o "resistencia", que sobrescriben el valor por defecto solo para
## esa celda.
@export var excepciones_material: Dictionary[Vector2i, Dictionary] = {}


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
		obtener_resistencia_celda(celda)
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


func obtener_tipo_material(celda: Vector2i) -> TipoMaterial:
	var excepcion: Dictionary = excepciones_material.get(celda, {})
	return excepcion.get("tipo_material", tipo_material_default)


func obtener_especialidad_requerida(celda: Vector2i) -> StringName:
	var excepcion: Dictionary = excepciones_material.get(celda, {})
	return excepcion.get("especialidad_requerida", especialidad_requerida_default)


func es_excavable(celda: Vector2i) -> bool:
	var excepcion: Dictionary = excepciones_material.get(celda, {})
	return excepcion.get("excavable", excavable_default)


func obtener_resistencia_celda(celda: Vector2i) -> int:
	var excepcion: Dictionary = excepciones_material.get(celda, {})
	return excepcion.get("resistencia", golpes_para_romper)


## Determina si una celda existe, es excavable y corresponde a la
## especialidad indicada (ej. &"excavador").
func es_celda_excavable(
	celda: Vector2i,
	especialidad_id: StringName
) -> bool:
	if get_cell_source_id(celda) == -1:
		return false

	return (
		es_excavable(celda)
		and obtener_especialidad_requerida(celda) == especialidad_id
	)


## Destruye una celda directamente, sin pasar por el flujo de golpes.
## Usado por GuardadoManager al restaurar progreso, para no re-disparar
## la señal bloque_destruido (y por lo tanto no re-disparar el autosave).
func aplicar_celda_destruida(celda: Vector2i) -> void:
	TerrenoService.destruir_celda(
		self,
		golpes_recibidos,
		celda
	)
