class_name SerializacionService
extends RefCounted

## Convierte el progreso del juego hacia y desde Dictionary/JSON.
## No conoce el sistema de archivos ni modifica nodos de la escena.

const VERSION_SNAPSHOT: int = 2


static func construir_snapshot(
	datos_cenizos: Array[Dictionary],
	indice_cenizo_activo: int,
	celdas_destruidas: Array[Vector2i],
	escena_actual: String,
	recursos: Dictionary = {}
) -> Dictionary:
	var celdas_serializadas: Array = []

	for celda in celdas_destruidas:
		celdas_serializadas.append([celda.x, celda.y])

	var cenizos_serializados: Array = []

	for datos in datos_cenizos:
		cenizos_serializados.append(datos.duplicate(true))

	return {
		"version": VERSION_SNAPSHOT,
		"fecha_guardado_unix": int(Time.get_unix_time_from_system()),
		"escena_actual": escena_actual,
		"indice_cenizo_activo": max(indice_cenizo_activo, 0),
		"cenizos": cenizos_serializados,
		"celdas_destruidas": celdas_serializadas,
		"recursos": recursos.duplicate(true),
	}


static func snapshot_a_json(snapshot: Dictionary) -> String:
	return JSON.stringify(snapshot)


static func json_a_snapshot(texto_json: String) -> Dictionary:
	var resultado: Variant = JSON.parse_string(texto_json)

	if typeof(resultado) != TYPE_DICTIONARY:
		push_warning("El archivo de guardado no contiene un Dictionary válido.")
		return {}

	var snapshot: Dictionary = resultado
	return _migrar_snapshot(snapshot)


static func obtener_version(snapshot: Dictionary) -> int:
	return int(snapshot.get("version", 1))


static func obtener_escena_actual(snapshot: Dictionary) -> String:
	return str(snapshot.get("escena_actual", ""))


static func obtener_indice_cenizo_activo(snapshot: Dictionary) -> int:
	var cantidad_cenizos := obtener_datos_cenizos(snapshot).size()

	if cantidad_cenizos <= 0:
		return 0

	return clampi(
		int(snapshot.get("indice_cenizo_activo", 0)),
		0,
		cantidad_cenizos - 1
	)


static func obtener_datos_cenizos(
	snapshot: Dictionary
) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var datos: Variant = snapshot.get("cenizos", [])

	if typeof(datos) != TYPE_ARRAY:
		return resultado

	for elemento in datos:
		if typeof(elemento) != TYPE_DICTIONARY:
			continue

		var diccionario: Dictionary = elemento
		resultado.append(diccionario.duplicate(true))

	return resultado


static func obtener_posicion_desde_datos_cenizo(
	datos_cenizo: Dictionary
) -> Vector2:
	var posicion: Variant = datos_cenizo.get("posicion", [0.0, 0.0])

	if typeof(posicion) != TYPE_ARRAY or posicion.size() < 2:
		return Vector2.ZERO

	return Vector2(
		float(posicion[0]),
		float(posicion[1])
	)


## Compatibilidad con código anterior que esperaba una sola posición.
static func obtener_posicion_cenizo(snapshot: Dictionary) -> Vector2:
	var cenizos := obtener_datos_cenizos(snapshot)

	if cenizos.is_empty():
		return Vector2.ZERO

	var indice := obtener_indice_cenizo_activo(snapshot)
	return obtener_posicion_desde_datos_cenizo(cenizos[indice])


static func obtener_celdas_destruidas(
	snapshot: Dictionary
) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	var datos: Variant = snapshot.get("celdas_destruidas", [])

	if typeof(datos) != TYPE_ARRAY:
		return celdas

	for par in datos:
		if typeof(par) != TYPE_ARRAY or par.size() < 2:
			continue

		celdas.append(
			Vector2i(
				int(par[0]),
				int(par[1])
			)
		)

	return celdas


static func obtener_recursos(snapshot: Dictionary) -> Dictionary:
	var datos_recursos: Variant = snapshot.get("recursos", {})

	if typeof(datos_recursos) != TYPE_DICTIONARY:
		return {}

	var recursos: Dictionary = datos_recursos
	return recursos.duplicate(true)


static func _migrar_snapshot(snapshot_original: Dictionary) -> Dictionary:
	var version := int(snapshot_original.get("version", 1))

	if version >= VERSION_SNAPSHOT:
		return snapshot_original.duplicate(true)

	if version == 1:
		return _migrar_version_1_a_2(snapshot_original)

	push_warning(
		"Versión de guardado desconocida: %d" % version
	)
	return {}


static func _migrar_version_1_a_2(
	snapshot_anterior: Dictionary
) -> Dictionary:
	var posicion: Variant = snapshot_anterior.get(
		"posicion_cenizo",
		[0.0, 0.0]
	)

	if typeof(posicion) != TYPE_ARRAY or posicion.size() < 2:
		posicion = [0.0, 0.0]

	return {
		"version": VERSION_SNAPSHOT,
		"fecha_guardado_unix": 0,
		"escena_actual": "",
		"indice_cenizo_activo": 0,
		"cenizos": [
			{
				"nombre": "Cenizo",
				"posicion": [
					float(posicion[0]),
					float(posicion[1]),
				],
			}
		],
		"celdas_destruidas": snapshot_anterior.get(
			"celdas_destruidas",
			[]
		),
		"recursos": {},
	}
