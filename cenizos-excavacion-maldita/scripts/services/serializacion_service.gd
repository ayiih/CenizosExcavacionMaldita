class_name SerializacionService
extends RefCounted

## Convierte el progreso del juego hacia/desde un formato serializable
## (Dictionary / JSON), sin conocer cómo ni dónde se persiste.

const VERSION_SNAPSHOT: int = 1


## Construye un snapshot serializable a partir del estado actual del juego.
static func construir_snapshot(
	posicion_cenizo: Vector2,
	celdas_destruidas: Array[Vector2i]
) -> Dictionary:
	var celdas_serializadas: Array = []

	for celda in celdas_destruidas:
		celdas_serializadas.append([celda.x, celda.y])

	return {
		"version": VERSION_SNAPSHOT,
		"posicion_cenizo": [posicion_cenizo.x, posicion_cenizo.y],
		"celdas_destruidas": celdas_serializadas,
	}


static func snapshot_a_json(snapshot: Dictionary) -> String:
	return JSON.stringify(snapshot)


static func json_a_snapshot(texto_json: String) -> Dictionary:
	var resultado: Variant = JSON.parse_string(texto_json)

	if typeof(resultado) != TYPE_DICTIONARY:
		return {}

	return resultado


## Extrae la posición del Cenizo desde un snapshot.
static func obtener_posicion_cenizo(snapshot: Dictionary) -> Vector2:
	var datos: Array = snapshot.get(
		"posicion_cenizo",
		[0.0, 0.0]
	)

	return Vector2(datos[0], datos[1])


## Extrae las celdas destruidas desde un snapshot.
static func obtener_celdas_destruidas(
	snapshot: Dictionary
) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	var datos: Array = snapshot.get(
		"celdas_destruidas",
		[]
	)

	for par in datos:
		celdas.append(Vector2i(par[0], par[1]))

	return celdas
