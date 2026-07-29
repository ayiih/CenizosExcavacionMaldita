extends Node2D

## Ruta hacia el personaje.
@export var jugador_path: NodePath

## Tamaño total del sector cubierto por la niebla, en píxeles.
@export var tamano_sector: Vector2i = Vector2i(1280, 4096)

## Resolución interna de la niebla.
## 8 significa que cada píxel de la máscara representa 8 píxeles del juego.
@export_range(1, 32, 1) var escala_mascara: int = 8

## Radio total que descubre el personaje.
@export var radio_descubrimiento: float = 130.0

## Tamaño del borde difuminado.
@export var borde_suave: float = 45.0

## Distancia que debe caminar antes de actualizar nuevamente la niebla.
@export var distancia_actualizacion: float = 10.0

## Color y transparencia de la niebla.
@export var color_niebla: Color = Color(0.025, 0.02, 0.04, 1.0)


@onready var jugador: Node2D = get_node(jugador_path)
@onready var fog_sprite: Sprite2D = $FogSprite

var imagen_mascara: Image
var textura_mascara: ImageTexture

var ultima_posicion_revelada := Vector2(-1000000.0, -1000000.0)


func _ready() -> void:
	crear_niebla()

	# Revela inmediatamente la posición inicial del personaje.
	revelar_en(jugador.global_position)


func _process(_delta: float) -> void:
	if not is_instance_valid(jugador):
		return

	var distancia := jugador.global_position.distance_to(
		ultima_posicion_revelada
	)

	if distancia >= distancia_actualizacion:
		revelar_en(jugador.global_position)


func crear_niebla() -> void:
	var ancho_mascara := int(ceil(
		float(tamano_sector.x) / float(escala_mascara)
	))

	var alto_mascara := int(ceil(
		float(tamano_sector.y) / float(escala_mascara)
	))

	imagen_mascara = Image.create(
		ancho_mascara,
		alto_mascara,
		false,
		Image.FORMAT_RGBA8
	)

	imagen_mascara.fill(color_niebla)

	textura_mascara = ImageTexture.create_from_image(imagen_mascara)

	fog_sprite.texture = textura_mascara
	fog_sprite.centered = false
	fog_sprite.position = Vector2.ZERO
	fog_sprite.scale = Vector2(
		float(escala_mascara),
		float(escala_mascara)
	)

	# Suaviza el borde del descubrimiento.
	fog_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# Coloca la niebla encima del escenario.
	fog_sprite.z_index = 80


func revelar_en(posicion_global: Vector2) -> void:
	# Posición relativa al nodo NieblaGuerra.
	var posicion_local := to_local(posicion_global)

	# No actualizar si el personaje está fuera del sector.
	if posicion_local.x < 0.0:
		return

	if posicion_local.y < 0.0:
		return

	if posicion_local.x >= tamano_sector.x:
		return

	if posicion_local.y >= tamano_sector.y:
		return

	var centro := posicion_local / float(escala_mascara)

	var radio_exterior := (
		radio_descubrimiento / float(escala_mascara)
	)

	var suavizado := borde_suave / float(escala_mascara)

	var radio_interior := maxf(
		radio_exterior - suavizado,
		0.0
	)

	var minimo_x := clampi(
		int(floor(centro.x - radio_exterior)),
		0,
		imagen_mascara.get_width() - 1
	)

	var maximo_x := clampi(
		int(ceil(centro.x + radio_exterior)),
		0,
		imagen_mascara.get_width() - 1
	)

	var minimo_y := clampi(
		int(floor(centro.y - radio_exterior)),
		0,
		imagen_mascara.get_height() - 1
	)

	var maximo_y := clampi(
		int(ceil(centro.y + radio_exterior)),
		0,
		imagen_mascara.get_height() - 1
	)

	for y in range(minimo_y, maximo_y + 1):
		for x in range(minimo_x, maximo_x + 1):
			var pixel := Vector2(float(x), float(y))
			var distancia := pixel.distance_to(centro)

			if distancia > radio_exterior:
				continue

			var factor_alpha := 0.0

			if distancia > radio_interior and suavizado > 0.0:
				var progreso: float = (
					(distancia - radio_interior) /
					max(radio_exterior - radio_interior, 0.001)
				)

				progreso = clampf(progreso, 0.0, 1.0)

				# Aumenta la densidad hacia el borde exterior del descubrimiento.
				factor_alpha = progreso * (
					3.0 - 3.0 * progreso + progreso * progreso
				)

			var color_actual := imagen_mascara.get_pixel(x, y)
			var nuevo_alpha := color_niebla.a * factor_alpha

			# Solo permite despejar.
			# Nunca vuelve a oscurecer una zona descubierta.
			if nuevo_alpha < color_actual.a:
				imagen_mascara.set_pixel(
					x,
					y,
					Color(
						color_niebla.r,
						color_niebla.g,
						color_niebla.b,
						nuevo_alpha
					)
				)

	textura_mascara.update(imagen_mascara)
	ultima_posicion_revelada = posicion_global
