class_name PartidaRepository
extends RefCounted

## Única capa que sabe CÓMO y DÓNDE se persiste la partida en disco.
## No conoce reglas de juego; solo lee/escribe snapshots.

const RUTA_GUARDADO := "user://saves/progreso.save"
const CARPETA_GUARDADO := "user://saves"


static func existe_guardado() -> bool:
	return FileAccess.file_exists(RUTA_GUARDADO)


static func guardar(snapshot: Dictionary) -> bool:
	_asegurar_carpeta()

	var archivo := FileAccess.open(
		RUTA_GUARDADO,
		FileAccess.WRITE
	)

	if archivo == null:
		push_warning(
			"No se pudo abrir el archivo de guardado para escritura."
		)
		return false

	archivo.store_string(
		SerializacionService.snapshot_a_json(snapshot)
	)
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
		push_warning(
			"No se pudo abrir el archivo de guardado para lectura."
		)
		return {}

	var contenido := archivo.get_as_text()
	archivo.close()

	return SerializacionService.json_a_snapshot(contenido)


static func _asegurar_carpeta() -> void:
	var directorio := DirAccess.open("user://")

	if directorio != null and not directorio.dir_exists("saves"):
		directorio.make_dir("saves")
