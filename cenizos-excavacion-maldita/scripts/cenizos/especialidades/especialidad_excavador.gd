class_name EspecialidadExcavador
extends EspecialidadCenizo

## Excava en línea recta (abajo, izquierda o derecha) hasta toparse
## con un material incompatible, un pozo peligroso o el fin del terreno.

@export var velocidad_trabajo: float = 1.0
@export var danio_excavacion: int = 1

## Alto libre (en celdas) requerido para avanzar en excavación lateral.
@export var alto_excavacion_lateral: int = 2


func _init() -> void:
	id = &"excavador"
	nombre_visible = "Excavador"


func puede_realizar_orden(
	_cenizo: CharacterBody2D,
	orden: OrdenTrabajo
) -> bool:
	if orden.tipo != OrdenTrabajo.TipoOrden.EXCAVAR:
		return false

	var terreno := orden.terreno_objetivo as TerrenoDestructible

	if terreno == null:
		return false

	if terreno.get_cell_source_id(orden.celda_objetivo) == -1:
		return false

	return terreno.es_celda_excavable(orden.celda_objetivo, id)


func calcular_posicion_trabajo(
	cenizo: CharacterBody2D,
	orden: OrdenTrabajo
) -> Vector2:
	var terreno := orden.terreno_objetivo as TerrenoDestructible

	if terreno == null:
		return cenizo.global_position

	var centro_celda_local := terreno.map_to_local(orden.celda_objetivo)
	var centro_celda_global := terreno.to_global(centro_celda_local)

	var tamano_celda := Vector2(32.0, 32.0)

	if terreno.tile_set != null:
		tamano_celda = Vector2(terreno.tile_set.tile_size)

	if orden.direccion == Vector2i.DOWN:
		return Vector2(centro_celda_global.x, cenizo.global_position.y)

	if orden.direccion == Vector2i.RIGHT:
		return Vector2(
			centro_celda_global.x - tamano_celda.x,
			cenizo.global_position.y
		)

	if orden.direccion == Vector2i.LEFT:
		return Vector2(
			centro_celda_global.x + tamano_celda.x,
			cenizo.global_position.y
		)

	return cenizo.global_position


func comenzar_trabajo(
	_cenizo: CharacterBody2D,
	orden: OrdenTrabajo
) -> void:
	orden.tiempo_desde_ultimo_golpe = 0.0


func actualizar_trabajo(
	cenizo: CharacterBody2D,
	orden: OrdenTrabajo,
	delta: float
) -> void:
	var c := cenizo as Cenizo
	var terreno := orden.terreno_objetivo as TerrenoDestructible

	if c == null:
		return

	if terreno == null or not is_instance_valid(terreno):
		c.finalizar_orden(OrdenTrabajo.MotivoFin.SIN_RUTA)
		return

	# Al excavar hacia abajo, esperar a aterrizar tras cada caída
	# y recalcular la celda según la posición real del Cenizo.
	if orden.direccion == Vector2i.DOWN:
		if not c.is_on_floor():
			return

		orden.celda_objetivo = _celda_bajo_cenizo(c, terreno)

	if terreno.get_cell_source_id(orden.celda_objetivo) == -1:
		c.finalizar_orden(OrdenTrabajo.MotivoFin.SIN_TERRENO)
		return

	if not terreno.es_celda_excavable(orden.celda_objetivo, id):
		c.finalizar_orden(OrdenTrabajo.MotivoFin.MATERIAL_INCOMPATIBLE)
		return

	orden.tiempo_desde_ultimo_golpe += delta

	var intervalo := 1.0 / maxf(velocidad_trabajo, 0.01)

	if orden.tiempo_desde_ultimo_golpe < intervalo:
		return

	orden.tiempo_desde_ultimo_golpe = 0.0

	if not terreno.golpear_celda(orden.celda_objetivo, danio_excavacion):
		c.finalizar_orden(OrdenTrabajo.MotivoFin.SIN_TERRENO)
		return

	# Todavía no se rompió del todo: seguir golpeando la misma celda.
	if terreno.get_cell_source_id(orden.celda_objetivo) != -1:
		return

	c.notificar_bloque_destruido(orden.celda_objetivo)

	# Hacia abajo: dejar que la gravedad haga aterrizar al Cenizo;
	# la siguiente celda se recalcula arriba en el próximo golpe.
	if orden.direccion == Vector2i.DOWN:
		return

	var siguiente_celda := orden.celda_objetivo + orden.direccion

	if not _puede_avanzar_horizontal(terreno, siguiente_celda):
		c.finalizar_orden(OrdenTrabajo.MotivoFin.BLOQUEADO)
		return

	orden.celda_objetivo = siguiente_celda
	orden.posicion_objetivo = calcular_posicion_trabajo(c, orden)
	c.cambiar_estado(EstadoCenizo.Valor.MOVIENDOSE_A_TAREA)


func cancelar_trabajo(
	_cenizo: CharacterBody2D,
	orden: OrdenTrabajo
) -> void:
	orden.tiempo_desde_ultimo_golpe = 0.0


func _celda_bajo_cenizo(
	cenizo: Cenizo,
	terreno: TerrenoDestructible
) -> Vector2i:
	var punto_pies := cenizo.global_position + Vector2(0.0, 4.0)
	return terreno.local_to_map(terreno.to_local(punto_pies))


func _puede_avanzar_horizontal(
	terreno: TerrenoDestructible,
	celda: Vector2i
) -> bool:
	var celda_suelo := celda + Vector2i.DOWN

	# Evita avanzar hacia un pozo: debe existir piso firme debajo.
	if terreno.get_cell_source_id(celda_suelo) == -1:
		return false

	for offset in range(alto_excavacion_lateral):
		var celda_altura := celda + Vector2i(0, -offset)
		var origen := terreno.get_cell_source_id(celda_altura)

		if origen != -1 and not terreno.es_celda_excavable(celda_altura, id):
			return false

	return true
