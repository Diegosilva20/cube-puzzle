extends Node3D

@onready var cubo_pai = $cube
@onready var pivo = $PivoRotacao
@onready var camera = $PivoCamera/Camera3D

const TAMANHO_GRID = 2.05
var girando = false

# Variáveis para o Swipe
var peca_focada: Node3D = null
var normal_face_focada: Vector3 = Vector3.ZERO
var posicao_mouse_inicio = Vector2.ZERO
const LIMITE_ARRASTE = 30.0

func _input(event):
	if girando: return

	# 1. CLIQUE
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			tentar_iniciar_interacao(event.position)
			if peca_focada != null:
				get_viewport().set_input_as_handled()
		else:
			peca_focada = null

	# 2. ARRASTE
	if event is InputEventMouseMotion and peca_focada != null:
		get_viewport().set_input_as_handled()
		processar_arraste(event.position)

func tentar_iniciar_interacao(pos_mouse):
	var origem = camera.project_ray_origin(pos_mouse)
	var direcao = camera.project_ray_normal(pos_mouse)
	var fim = origem + direcao * 2000.0 
	
	var espaco = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origem, fim)
	var resultado = espaco.intersect_ray(query)
	
	if resultado:
		peca_focada = resultado["collider"].get_parent()
		var n = resultado["normal"]
		
		# --- CORREÇÃO 1: Normalização Robusta ---
		# Garante que pegamos apenas o eixo dominante, ignorando inclinações de bevel/bordas
		var max_axis = max(abs(n.x), abs(n.y), abs(n.z))
		if max_axis == abs(n.x):
			normal_face_focada = Vector3(sign(n.x), 0, 0)
		elif max_axis == abs(n.y):
			normal_face_focada = Vector3(0, sign(n.y), 0)
		else:
			normal_face_focada = Vector3(0, 0, sign(n.z))
			
		posicao_mouse_inicio = pos_mouse
	else:
		peca_focada = null

func processar_arraste(pos_mouse_atual):
	var vetor_mouse = pos_mouse_atual - posicao_mouse_inicio
	
	if vetor_mouse.length() < LIMITE_ARRASTE:
		return

	var normal = normal_face_focada
	# Usamos o centro visual (AABB) para projeção na câmera, é mais seguro que global_position
	var centro_visual = peca_focada.to_global(peca_focada.get_aabb().get_center())
	
	# --- PASSO 1: Identificar qual eixo 3D o mouse está seguindo ---
	var eixos_candidatos = []
	if abs(normal.x) < 0.5: eixos_candidatos.append(Vector3(1, 0, 0))
	if abs(normal.y) < 0.5: eixos_candidatos.append(Vector3(0, 1, 0))
	if abs(normal.z) < 0.5: eixos_candidatos.append(Vector3(0, 0, 1))
	
	var melhor_eixo_movimento = Vector3.ZERO
	var melhor_alinhamento = -1.0
	var sentido_na_tela = 0
	
	var tela_centro = camera.unproject_position(centro_visual)
	
	for eixo_mundo in eixos_candidatos:
		var tela_offset = camera.unproject_position(centro_visual + eixo_mundo)
		var direcao_visual = tela_offset - tela_centro
		
		var alinhamento = abs(vetor_mouse.normalized().dot(direcao_visual.normalized()))
		
		if alinhamento > melhor_alinhamento:
			melhor_alinhamento = alinhamento
			melhor_eixo_movimento = eixo_mundo
			
			var dot = vetor_mouse.dot(direcao_visual)
			sentido_na_tela = 1 if dot >= 0 else -1
	
	if melhor_alinhamento < 0.5: return

	# --- PASSO 2: Determinar o Eixo de Rotação ---
	var eixo_rotacao_bruto = normal.cross(melhor_eixo_movimento)
	
	var eixo_final_abs = Vector3(abs(eixo_rotacao_bruto.x), abs(eixo_rotacao_bruto.y), abs(eixo_rotacao_bruto.z))
	
	var sinal_do_eixo = 1
	if (eixo_rotacao_bruto.x + eixo_rotacao_bruto.y + eixo_rotacao_bruto.z) < 0:
		sinal_do_eixo = -1
		
	# --- PASSO 3: Calcular Sentido Final ---
	var sentido_final = sentido_na_tela * sinal_do_eixo
	
	# --- CORREÇÃO 2: Passar o Objeto, não a Posição ---
	aplicar_rotacao(eixo_final_abs, sentido_final, peca_focada)
	peca_focada = null 

func aplicar_rotacao(eixo: Vector3, sentido: int, peca_ref: Node3D):
	girando = true
	var pecas_para_girar = []
	
	# --- CORREÇÃO 3: Cálculo consistente do Grid ---
	# Calcula o centro da peça de referência usando AABB, assim como faremos no loop.
	# Isso garante que Referência e Vizinhos usem a mesma métrica matemática.
	var centro_ref = peca_ref.to_global(peca_ref.get_aabb().get_center())
	
	var ref_x = round(centro_ref.x / TAMANHO_GRID)
	var ref_y = round(centro_ref.y / TAMANHO_GRID)
	var ref_z = round(centro_ref.z / TAMANHO_GRID)
	
	for filho in cubo_pai.get_children():
		if not filho is MeshInstance3D: continue
		
		# Pega o centro geométrico real da malha
		var pos = filho.to_global(filho.get_aabb().get_center())
		var x = round(pos.x / TAMANHO_GRID)
		var y = round(pos.y / TAMANHO_GRID)
		var z = round(pos.z / TAMANHO_GRID)
		
		var deve_girar = false
		if eixo.x > 0.5 and abs(x - ref_x) < 0.1: deve_girar = true
		elif eixo.y > 0.5 and abs(y - ref_y) < 0.1: deve_girar = true
		elif eixo.z > 0.5 and abs(z - ref_z) < 0.1: deve_girar = true
			
		if deve_girar:
			pecas_para_girar.append(filho)

	if pecas_para_girar.is_empty():
		girando = false
		return

	for peca in pecas_para_girar:
		peca.reparent(pivo, true)
		
	var tween = create_tween()
	var rotacao_final = eixo * deg_to_rad(90 * sentido)
	
	tween.tween_property(pivo, "rotation", rotacao_final, 0.3).set_trans(Tween.TRANS_CUBIC)
	tween.finished.connect(_fim_da_rotacao)

func _fim_da_rotacao():
	for peca in pivo.get_children():
		peca.reparent(cubo_pai, true)
	
	pivo.rotation = Vector3.ZERO
	
	# Snap positions para corrigir micro-desvios float
	# NOTA: Se os pivôs originais do Blender estiverem muito tortos, isso pode causar um leve 'pulo'.
	# Se isso acontecer, podemos mudar a lógica para snapar baseado no AABB também.
	for peca in cubo_pai.get_children():
		if peca is MeshInstance3D:
			peca.position.x = round(peca.position.x / TAMANHO_GRID) * TAMANHO_GRID
			peca.position.y = round(peca.position.y / TAMANHO_GRID) * TAMANHO_GRID
			peca.position.z = round(peca.position.z / TAMANHO_GRID) * TAMANHO_GRID

	atualizar_nomes_apos_rotacao()
	girando = false

func atualizar_nomes_apos_rotacao():
	# Renomeia para evitar conflitos de nome
	var index = 0
	for peca in cubo_pai.get_children():
		if peca is MeshInstance3D:
			peca.name = "Temp_" + str(index)
			index += 1
	
	# Dá os nomes definitivos baseados na nova posição do Grid
	for peca in cubo_pai.get_children():
		if not peca is MeshInstance3D: continue
		var centro = peca.to_global(peca.get_aabb().get_center())
		var x = int(round(centro.x / TAMANHO_GRID))
		var y = int(round(centro.y / TAMANHO_GRID))
		var z = int(round(centro.z / TAMANHO_GRID))
		peca.name = "Peca_%d_%d_%d" % [x, y, z]
