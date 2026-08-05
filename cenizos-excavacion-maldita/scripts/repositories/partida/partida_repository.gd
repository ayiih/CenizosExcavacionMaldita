class_name PartidaRepository
extends RefCounted

## Única capa que conoce cómo y dónde se persiste la partida.
## No contiene reglas de gameplay.

const CARPETA_GUARDADO := "user://saves"
const NOMBRE_ARCHIVO := "progreso.save"
const RUTA_GUARDADO := CARPETA_GUARDADO + "/" + NOMBRE_ARCHIVO


static func existe_guardado() -> bool:
	return FileAccess.file_exists(RUTA_GUARDADO)


static func guardar(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		push_warning("No se guardó la partida porque el snapshot está vacío.")
		return false

	if not _asegurar_carpeta():
		return false

	var archivo := FileAccess.open(
		RUTA_GUARDADO,
		FileAccess.WRITE
	)

	if archivo == null:
		push_error(
			"No se pudo abrir el archivo de guardado para escritura: %s"
			% RUTA_GUARDADO
		)
		return false

	archivo.store_string(
		SerializacionService.snapshot_a_json(snapshot)
	)
	archivo.flush()
	archivo.close()

	return true


static func cargar() -> Dictionary:
	if not existe_guardado():
		return {}

	var archivo := FileAccess.open(
		RUTA_GUARDADO,
		FileAccess.READ
	)

	if archivo == null:
		push_error(
			"No se pudo abrir el archivo de guardado para lectura: %s"
			% RUTA_GUARDADO
		)
		return {}

	var contenido := archivo.get_as_text()
	archivo.close()

	if contenido.strip_edges().is_empty():
		push_warning("El archivo de guardado está vacío.")
		return {}

	return SerializacionService.json_a_snapshot(contenido)


static func eliminar_guardado() -> bool:
	if not existe_guardado():
		return true

	var directorio := DirAccess.open(CARPETA_GUARDADO)

	if directorio == null:
		push_error("No se pudo abrir la carpeta de guardado.")
		return false

	var resultado := directorio.remove(NOMBRE_ARCHIVO)

	if resultado != OK:
		push_error(
			"No se pudo eliminar la partida guardada. Código: %d"
			% resultado
		)
		return false

	return true


static func _asegurar_carpeta() -> bool:
	var directorio_usuario := DirAccess.open("user://")

	if directorio_usuario == null:
		push_error("No se pudo acceder a user://")
		return false

	if directorio_usuario.dir_exists("saves"):
		return true

	var resultado := directorio_usuario.make_dir("saves")

	if resultado != OK:
		push_error(
			"No se pudo crear la carpeta de guardado. Código: %d"
			% resultado
		)
		return false

	return true
