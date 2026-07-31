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
	cenizo: CharacterBody2D,
	orden: OrdenTrabajo
) -> bool:
	if orden.tipo != OrdenTrabajo.TipoOrden.EXCAVAR:
		return false

	var terreno := orden.terreno_objetivo as TerrenoDestructible
	var c := cenizo as Cenizo

	if terreno == null or c == null:
		return false

	# El bloque a excavar debe estar pegado al Cenizo: nunca se puede
	# picar a distancia (ej. 2 bloques más abajo estando sobre terreno
	# fijo). Solo es válida la celda inmediatamente adyacente en la
	# dirección armada.
	if orden.celda_objetivo != celda_adyacente_esperada(c, terreno, orden.direccion):
		return false

	if terreno.get_cell_source_id(orden.celda_objetivo) == -1:
		return false

	if not terreno.es_celda_excavable(orden.celda_objetivo, id):
		return false

	# Excavación lateral: el Cenizo mide más de 1 celda de alto, así que
	# también necesita poder romper el bloque de arriba (si existe).
	if orden.direccion == Vector2i.LEFT or orden.direccion == Vector2i.RIGHT:
		var celda_superior := orden.celda_objetivo + Vector2i.UP

		if (
			terreno.get_cell_source_id(celda_superior) != -1
			and not terreno.es_celda_excavable(celda_superior, id)
		):
			return false

	return true


## Celda válida para excavar en la dirección dada, siempre pegada a la
## posición actual del Cenizo (no permite picar "a lo lejos"). Público
## para que GestorCenizos pueda usarlo al pintar el cursor de trabajo.
func celda_adyacente_esperada(
	cenizo: Cenizo,
	terreno: TerrenoDestructible,
	direccion: Vector2i
) -> Vector2i:
	if direccion == Vector2i.DOWN:
		return _celda_bajo_cenizo(cenizo, terreno)

	return _celda_del_cenizo(cenizo, terreno) + direccion


## Celda (fila/columna) que ocupa actualmente el cuerpo del Cenizo,
## es decir, la celda justo encima de la que pisa.
func _celda_del_cenizo(
	cenizo: Cenizo,
	terreno: TerrenoDestructible
) -> Vector2i:
	return _celda_bajo_cenizo(cenizo, terreno) + Vector2i.UP


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

	var celdas := _celdas_a_excavar(orden)

	var alguna_existe := false

	for celda in celdas:
		if terreno.get_cell_source_id(celda) != -1:
			alguna_existe = true
			break

	if not alguna_existe:
		c.finalizar_orden(OrdenTrabajo.MotivoFin.SIN_TERRENO)
		return

	for celda in celdas:
		if terreno.get_cell_source_id(celda) == -1:
			continue

		if not terreno.es_celda_excavable(celda, id):
			c.finalizar_orden(OrdenTrabajo.MotivoFin.MATERIAL_INCOMPATIBLE)
			return

	orden.tiempo_desde_ultimo_golpe += delta

	var intervalo := 1.0 / maxf(velocidad_trabajo, 0.01)

	if orden.tiempo_desde_ultimo_golpe < intervalo:
		return

	orden.tiempo_desde_ultimo_golpe = 0.0

	var quedan_bloques := false

	for celda in celdas:
		if terreno.get_cell_source_id(celda) == -1:
			continue

		if not terreno.golpear_celda(celda, danio_excavacion):
			c.finalizar_orden(OrdenTrabajo.MotivoFin.SIN_TERRENO)
			return

		if terreno.get_cell_source_id(celda) != -1:
			quedan_bloques = true
		else:
			c.notificar_bloque_destruido(celda)

	# Todavía queda al menos un bloque (lineal o el de arriba) por romper.
	if quedan_bloques:
		return

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


## Celdas que deben excavarse en paralelo para el paso actual. En
## horizontal se excava la celda lineal y la de arriba a la vez, ya que
## el Cenizo mide más de 32px y no entra en un solo bloque de alto.
func _celdas_a_excavar(orden: OrdenTrabajo) -> Array[Vector2i]:
	if orden.direccion == Vector2i.LEFT or orden.direccion == Vector2i.RIGHT:
		return [orden.celda_objetivo, orden.celda_objetivo + Vector2i.UP]

	return [orden.celda_objetivo]


func _celda_bajo_cenizo(
	cenizo: Cenizo,
	terreno: TerrenoDestructible
) -> Vector2i:
	# El origen del Cenizo está aproximadamente en el centro vertical de
	# su propia celda (colisión de ~33px centrada en el origen), así que
	# hay que cruzar más de medio tile hacia abajo para caer realmente
	# en la celda de sus pies, y no quedarse en la suya propia.
	var punto_pies := cenizo.global_position + Vector2(0.0, 18.0)
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
