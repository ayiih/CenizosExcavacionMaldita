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

@export_category("Daño visual")

## TileMapLayer que muestra las grietas encima del terreno.
@export var capa_grietas: TileMapLayer

## Source ID del atlas que contiene las grietas.
@export var source_id_grietas: int = 0

## Orden actual: desde la grieta más grande hasta la más pequeña.
@export var atlas_grietas: Array[Vector2i] = [
	Vector2i(0, 0), # 0: grieta más grande
	Vector2i(1, 0), # 1
	Vector2i(2, 0), # 2
	Vector2i(3, 0), # 3
	Vector2i(4, 0), # 4
	Vector2i(5, 0), # 5
	Vector2i(6, 0), # 6
	Vector2i(7, 0), # 7: grieta más pequeña
]

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

	if not es_excavable(celda):
		return false

	var resistencia := obtener_resistencia_celda(celda)

	var resultado := TerrenoService.golpear_celda(
		golpes_recibidos,
		celda,
		fuerza,
		resistencia
	)

	var golpes_restantes: int = resultado["golpes_restantes"]
	var destruida: bool = resultado["destruida"]

	bloque_golpeado.emit(
		celda,
		golpes_restantes
	)

	print("Golpes restantes: ", golpes_restantes)

	if destruida:
		_destruir_celda(celda)
	else:
		_actualizar_grieta(
			celda,
			golpes_restantes,
			resistencia
		)

	return true


func _destruir_celda(celda: Vector2i) -> void:
	var posicion_global := to_global(
		map_to_local(celda)
	)

	if capa_grietas != null:
		capa_grietas.erase_cell(celda)

	TerrenoService.destruir_celda(
		self,
		golpes_recibidos,
		celda
	)

	bloque_destruido.emit(
		celda,
		posicion_global
	)

	print("Bloque destruido: ", celda)

func reiniciar_dano() -> void:
	golpes_recibidos.clear()

	if capa_grietas != null:
		capa_grietas.clear()


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
	if capa_grietas != null:
		capa_grietas.erase_cell(celda)

	TerrenoService.destruir_celda(
		self,
		golpes_recibidos,
		celda
	)

func _actualizar_grieta(
	celda: Vector2i,
	golpes_restantes: int,
	resistencia: int
) -> void:
	if capa_grietas == null:
		push_warning(
			"No se asignó la capa de grietas en TerrenoDestructible."
		)
		return

	if atlas_grietas.is_empty():
		return

	var golpes_realizados := resistencia - golpes_restantes

	if golpes_realizados <= 0:
		capa_grietas.erase_cell(celda)
		return

	# Cantidad de golpes donde el bloque todavía sigue existiendo.
	var etapas_disponibles := maxi(
		resistencia - 1,
		1
	)

	# Convierte el daño en un valor entre 0.0 y 1.0.
	var progreso := 0.0

	if etapas_disponibles > 1:
		progreso = float(
			golpes_realizados - 1
		) / float(
			etapas_disponibles - 1
		)

	progreso = clampf(progreso, 0.0, 1.0)

	# Calcula la etapa desde pequeña hacia grande.
	var etapa_pequena_a_grande := roundi(
		progreso * float(atlas_grietas.size() - 1)
	)

	# Invierte el índice porque el atlas está ordenado:
	# grande → pequeña.
	var indice_atlas := (
		atlas_grietas.size()
		- 1
		- etapa_pequena_a_grande
	)

	indice_atlas = clampi(
		indice_atlas,
		0,
		atlas_grietas.size() - 1
	)

	capa_grietas.set_cell(
		celda,
		source_id_grietas,
		atlas_grietas[indice_atlas]
	)
