extends Camera3D

# --- CONFIGURAÇÕES ---
var sensibilidade_rotacao = 0.005
var velocidade_teclado = 3.0
var pressionado = false

# --- ZOOM ---
var velocidade_zoom = 0.5
var zoom_minimo = 5.0
var zoom_maximo = 15.0

func _ready():
	zoom_minimo = position.z - 3.0
	zoom_maximo = zoom_minimo + 10.0

func _process(delta):
	processar_teclado(delta)

func processar_teclado(delta):
	var input_x = Input.get_axis("cam_esquerda", "cam_direita")
	var input_y = Input.get_axis("cam_cima", "cam_baixo")

	if input_x != 0 or input_y != 0:
		var pivo = get_parent()
		if pivo:
			# CORREÇÃO AQUI:
			# Usamos global_rotate com Vector3.UP para girar em torno do "Chão" do mundo.
			# Isso mantém o horizonte reto, não importa o quanto você olhe para cima/baixo.
			pivo.global_rotate(Vector3.UP, -input_x * velocidade_teclado * delta)
			
			# A vertical continua local (rotate_object_local), pois queremos olhar
			# para cima/baixo relativo a onde a câmera está agora.
			pivo.rotate_object_local(Vector3(1, 0, 0), -input_y * velocidade_teclado * delta)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pressionado = event.pressed

	if event is InputEventMouseMotion and pressionado:
		var pivo = get_parent()
		if pivo:
			# CORREÇÃO AQUI TAMBÉM (PARA O MOUSE):
			pivo.global_rotate(Vector3.UP, -event.relative.x * sensibilidade_rotacao)
			
			pivo.rotate_object_local(Vector3(1, 0, 0), -event.relative.y * sensibilidade_rotacao)

	# Lógica de Zoom
	if event.is_action_pressed("zoom_in"):
		aplicar_zoom(-velocidade_zoom)
	elif event.is_action_pressed("zoom_out"):
		aplicar_zoom(velocidade_zoom)

func aplicar_zoom(valor):
	position.z += valor
	position.z = clamp(position.z, zoom_minimo, zoom_maximo)
